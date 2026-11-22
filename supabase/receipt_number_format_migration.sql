-- QuickBite: configurable receipt numbering
-- Run once in Supabase SQL Editor after the previous billing/GST migration.
-- Existing orders are not updated. Only newly inserted orders receive the configured format.

alter table public.restaurant_settings
  add column if not exists receipt_prefix text not null default 'Hi-5/invoice',
  add column if not exists receipt_year text not null default '2026-2027',
  add column if not exists next_receipt_number integer not null default 1;

-- Keep the sequence value valid even if an older settings row already exists.
update public.restaurant_settings
set receipt_prefix = coalesce(nullif(receipt_prefix, ''), 'Hi-5/invoice'),
    receipt_year = coalesce(nullif(receipt_year, ''), '2026-2027'),
    next_receipt_number = greatest(coalesce(next_receipt_number, 1), 1)
where receipt_prefix is null or receipt_prefix = ''
   or receipt_year is null or receipt_year = ''
   or next_receipt_number is null or next_receipt_number < 1;

create or replace function public.quickbite_assign_receipt_number()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  settings_id uuid;
  receipt_prefix_value text;
  receipt_year_value text;
  issued_number integer;
begin
  -- Find the active settings row, creating a default one only if none exists.
  select id into settings_id
  from public.restaurant_settings
  order by updated_at desc
  limit 1;

  if settings_id is null then
    insert into public.restaurant_settings
      (restaurant_name, location, receipt_prefix, receipt_year, next_receipt_number)
    values
      ('My Restaurant', '', 'Hi-5/invoice', '2026-2027', 1)
    returning id into settings_id;
  end if;

  -- UPDATE ... RETURNING allocates numbers atomically for simultaneous orders.
  update public.restaurant_settings
  set next_receipt_number = greatest(next_receipt_number, 1) + 1,
      updated_at = now()
  where id = settings_id
  returning receipt_prefix, receipt_year, next_receipt_number - 1
    into receipt_prefix_value, receipt_year_value, issued_number;

  new.order_number := coalesce(nullif(trim(receipt_prefix_value), ''), 'Hi-5/invoice')
    || '/' || coalesce(nullif(trim(receipt_year_value), ''), '2026-2027')
    || '/' || lpad(issued_number::text, 4, '0');

  return new;
end;
$$;

drop trigger if exists trg_quickbite_assign_receipt_number on public.food_orders;
create trigger trg_quickbite_assign_receipt_number
before insert on public.food_orders
for each row
execute function public.quickbite_assign_receipt_number();

-- Verify the settings values after migration:
-- select receipt_prefix, receipt_year, next_receipt_number from public.restaurant_settings;
