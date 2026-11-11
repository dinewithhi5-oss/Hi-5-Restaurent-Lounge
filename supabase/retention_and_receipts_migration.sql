-- QuickBite completed-order retention and report preservation.
-- Run this once in the Supabase SQL Editor after the main schema.sql.
create table if not exists public.food_order_report_archive (
 id uuid primary key,
 order_number text not null,
 total_amount numeric(10,2) not null default 0,
 status text not null check (status = 'completed'),
 created_at timestamptz not null
);
create index if not exists food_order_report_archive_created_at_idx
 on public.food_order_report_archive(created_at);
alter table public.food_order_report_archive enable row level security;
drop policy if exists "authenticated read report archive" on public.food_order_report_archive;
create policy "authenticated read report archive" on public.food_order_report_archive
 for select to authenticated using (true);
grant select on public.food_order_report_archive to authenticated;

create or replace function public.archive_and_delete_last_month_completed_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  month_start timestamp;
  next_month_start timestamp;
  deleted_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  -- Use Bhutan business-local calendar months, then convert to timestamptz.
  month_start := date_trunc('month', now() at time zone 'Asia/Thimphu') - interval '1 month';
  next_month_start := date_trunc('month', now() at time zone 'Asia/Thimphu');

  insert into public.food_order_report_archive (id, order_number, total_amount, status, created_at)
  select id, order_number, total_amount, 'completed', created_at
  from public.food_orders
  where status = 'completed'
    and created_at >= (month_start at time zone 'Asia/Thimphu')
    and created_at < (next_month_start at time zone 'Asia/Thimphu')
  on conflict (id) do nothing;

  delete from public.food_orders
  where status = 'completed'
    and created_at >= (month_start at time zone 'Asia/Thimphu')
    and created_at < (next_month_start at time zone 'Asia/Thimphu');

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;
revoke all on function public.archive_and_delete_last_month_completed_orders() from public, anon;
grant execute on function public.archive_and_delete_last_month_completed_orders() to authenticated;
