-- QuickBite fix: prevent duplicate receipt/order numbers.
-- Run this script ONCE in Supabase SQL Editor (it is safe to run again).
-- It preserves existing orders and keeps the configured receipt format.

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
  number_prefix text;
  highest_existing_number integer;
begin
  -- Find the latest restaurant settings row, creating one only if needed.
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

  -- Read the format, then find the highest number already issued in that format.
  select coalesce(nullif(trim(receipt_prefix), ''), 'Hi-5/invoice'),
         coalesce(nullif(trim(receipt_year), ''), '2026-2027')
    into receipt_prefix_value, receipt_year_value
  from public.restaurant_settings
  where id = settings_id;

  number_prefix := receipt_prefix_value || '/' || receipt_year_value || '/';

  select coalesce(max(substring(order_number from '([0-9]+)$')::integer), 0)
    into highest_existing_number
  from public.food_orders
  where left(order_number, length(number_prefix)) = number_prefix
    and substring(order_number from '([0-9]+)$') is not null;

  -- The settings-row UPDATE serializes simultaneous orders. Also catch up if
  -- the counter was reset or fell behind existing order numbers.
  update public.restaurant_settings
  set next_receipt_number =
        greatest(coalesce(next_receipt_number, 1), highest_existing_number + 1, 1) + 1,
      updated_at = now()
  where id = settings_id
  returning next_receipt_number - 1
    into issued_number;

  new.order_number := number_prefix || lpad(issued_number::text, 4, '0');
  return new;
end;
$$;

drop trigger if exists trg_quickbite_assign_receipt_number on public.food_orders;
create trigger trg_quickbite_assign_receipt_number
before insert on public.food_orders
for each row
execute function public.quickbite_assign_receipt_number();

-- Check the active counter after running:
-- select receipt_prefix, receipt_year, next_receipt_number
-- from public.restaurant_settings
-- order by updated_at desc
-- limit 1;
