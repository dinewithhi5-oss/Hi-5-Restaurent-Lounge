-- SmartDine: clear transaction/order history for a fresh start.
-- Run this manually in Supabase Dashboard -> SQL Editor.
-- This deletes order line items, orders, and daily closing snapshots ONLY.
-- It preserves food menu, categories, dining locations/QR codes, staff,
-- restaurant settings, uploaded Storage images, and Supabase Auth users.
-- Take a backup first if you may need the old transactions later.

begin;

delete from public.food_order_items;
delete from public.food_orders;
delete from public.daily_closings;

commit;

-- Verify that transaction tables are empty.
select
  (select count(*) from public.food_orders) as remaining_orders,
  (select count(*) from public.food_order_items) as remaining_order_items,
  (select count(*) from public.daily_closings) as remaining_daily_closings;
