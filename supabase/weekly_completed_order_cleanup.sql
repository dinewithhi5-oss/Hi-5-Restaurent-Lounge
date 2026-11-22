-- QuickBite: delete completed orders from the PREVIOUS FULL calendar week.
-- Week boundaries use Bhutan time (Asia/Thimphu), Monday 00:00 through
-- the following Monday 00:00. The current week is never included.
-- Order line items are removed automatically by ON DELETE CASCADE. Since
-- customer receipts and tracking pages read from food_orders, deleting the
-- parent order also removes those receipts from customer lookup.
-- Compact archive rows preserve historical report totals and order dates.

create or replace function public.archive_and_delete_last_week_completed_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  current_week_start timestamp;
  previous_week_start timestamp;
  deleted_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  current_week_start := date_trunc('week', now() at time zone 'Asia/Thimphu');
  previous_week_start := current_week_start - interval '1 week';

  insert into public.food_order_report_archive (id, order_number, total_amount, status, created_at)
  select id, coalesce(order_number, id::text), total_amount, 'completed', created_at
  from public.food_orders
  where status = 'completed'
    and created_at >= (previous_week_start at time zone 'Asia/Thimphu')
    and created_at < (current_week_start at time zone 'Asia/Thimphu')
  on conflict (id) do nothing;

  delete from public.food_orders
  where status = 'completed'
    and created_at >= (previous_week_start at time zone 'Asia/Thimphu')
    and created_at < (current_week_start at time zone 'Asia/Thimphu');

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.archive_and_delete_last_week_completed_orders() from public, anon;
grant execute on function public.archive_and_delete_last_week_completed_orders() to authenticated;

-- Remove access to the obsolete rolling-seven-day cleanup function so the
-- application cannot accidentally call the old date range.
drop function if exists public.archive_and_delete_last_7_days_completed_orders();
