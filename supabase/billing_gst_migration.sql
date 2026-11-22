-- QuickBite billing upgrade: run once in Supabase SQL Editor.
-- Existing orders keep their stored total and receive zero-valued breakdown defaults.
-- New orders store a permanent snapshot of subtotal, service charge and GST.
begin;

alter table public.restaurant_settings
  add column if not exists gst_enabled boolean not null default false;

alter table public.food_orders
  add column if not exists subtotal_amount numeric(10,2) not null default 0,
  add column if not exists service_charge_amount numeric(10,2) not null default 0,
  add column if not exists gst_rate numeric(5,2) not null default 0,
  add column if not exists gst_amount numeric(10,2) not null default 0;

alter table public.food_order_report_archive
  add column if not exists subtotal_amount numeric(10,2) not null default 0,
  add column if not exists service_charge_amount numeric(10,2) not null default 0,
  add column if not exists gst_rate numeric(5,2) not null default 0,
  add column if not exists gst_amount numeric(10,2) not null default 0;

-- Backfill historical subtotal to their already-recorded total without changing payable totals.
update public.food_orders
set subtotal_amount = total_amount
where subtotal_amount = 0 and service_charge_amount = 0 and gst_rate = 0 and gst_amount = 0;
update public.food_order_report_archive
set subtotal_amount = total_amount
where subtotal_amount = 0 and service_charge_amount = 0 and gst_rate = 0 and gst_amount = 0;

commit;
