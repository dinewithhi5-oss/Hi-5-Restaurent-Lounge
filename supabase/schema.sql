-- QuickBite QR Food Ordering: run in Supabase SQL Editor.
-- Admin users are created in Supabase Authentication (Dashboard → Authentication → Users).
-- Do NOT expose service_role key in the frontend.
create extension if not exists pgcrypto;

create table if not exists public.food_categories (
 id uuid primary key default gen_random_uuid(),
 name text not null unique,
 description text,
 is_active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.food_items (
 id uuid primary key default gen_random_uuid(),
 category_id uuid references public.food_categories(id) on delete set null,
 name text not null,
 description text,
 price numeric(10,2) not null default 0 check(price>=0),
 image_url text,
 is_available boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.dining_locations (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 location_type text not null default 'table' check(location_type in ('room','table')),
 capacity integer check(capacity is null or capacity>0),
 description text,
 qr_code text not null unique,
 is_active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.food_orders (
 id uuid primary key default gen_random_uuid(),
 order_number text not null unique default ('QB-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
 dining_location_id uuid references public.dining_locations(id) on delete set null,
 customer_name text,
 total_amount numeric(10,2) not null default 0 check(total_amount>=0),
 status text not null default 'pending' check(status in ('pending','confirmed','preparing','ready','completed','cancelled')),
 created_at timestamptz not null default now()
);
create table if not exists public.food_order_items (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references public.food_orders(id) on delete cascade,
 food_item_id uuid references public.food_items(id) on delete set null,
 item_name text not null,
 quantity integer not null check(quantity>0),
 unit_price numeric(10,2) not null check(unit_price>=0),
 line_total numeric(10,2) not null check(line_total>=0)
);
alter table public.food_categories enable row level security;
alter table public.food_items enable row level security;
alter table public.dining_locations enable row level security;
alter table public.food_orders enable row level security;
alter table public.food_order_items enable row level security;

-- Authenticated admins can manage all current admin-side tables.
-- For a real deployment, restrict admin access further using an admin-role table/claims.
drop policy if exists "authenticated manage categories" on public.food_categories;
create policy "authenticated manage categories" on public.food_categories for all to authenticated using (true) with check (true);
drop policy if exists "authenticated manage items" on public.food_items;
create policy "authenticated manage items" on public.food_items for all to authenticated using (true) with check (true);
drop policy if exists "authenticated manage locations" on public.dining_locations;
create policy "authenticated manage locations" on public.dining_locations for all to authenticated using (true) with check (true);
drop policy if exists "authenticated manage orders" on public.food_orders;
create policy "authenticated manage orders" on public.food_orders for all to authenticated using (true) with check (true);
drop policy if exists "authenticated manage order items" on public.food_order_items;
create policy "authenticated manage order items" on public.food_order_items for all to authenticated using (true) with check (true);

-- Public read policies are intentionally not enabled yet. Add customer-portal policies
-- when building the QR customer interface, limiting reads to active menu/location data.

-- Admin-side staff directory and restaurant branding settings.
-- Passwords are deliberately NOT stored here; use Supabase Authentication.
create table if not exists public.admin_staff (
 id uuid primary key default gen_random_uuid(),
 created_at timestamptz not null default now()
);
alter table public.admin_staff add column if not exists username text;
alter table public.admin_staff add column if not exists email text;
alter table public.admin_staff add column if not exists role text not null default 'staff';
alter table public.admin_staff add column if not exists is_active boolean not null default true;
do $$ begin
 if not exists (select 1 from pg_constraint where conname='admin_staff_username_key') then
  alter table public.admin_staff add constraint admin_staff_username_key unique (username);
 end if;
 if not exists (select 1 from pg_constraint where conname='admin_staff_email_key') then
  alter table public.admin_staff add constraint admin_staff_email_key unique (email);
 end if;
 if not exists (select 1 from pg_constraint where conname='admin_staff_role_check') then
  alter table public.admin_staff add constraint admin_staff_role_check check (role in ('staff','manager'));
 end if;
 -- Neutralize any stray legacy column (e.g. full_name) that this app never populates,
 -- so inserts from this admin UI don't fail on an unrelated NOT NULL constraint.
 if exists (select 1 from information_schema.columns where table_schema='public' and table_name='admin_staff' and column_name='full_name' and is_nullable='NO') then
  alter table public.admin_staff alter column full_name drop not null;
 end if;
end $$;

create table if not exists public.restaurant_settings (
 id uuid primary key default gen_random_uuid(),
 updated_at timestamptz not null default now()
);
alter table public.restaurant_settings add column if not exists restaurant_name text not null default 'My Restaurant';
alter table public.restaurant_settings add column if not exists location text not null default '';
alter table public.restaurant_settings add column if not exists logo_url text;

alter table public.dining_locations add column if not exists location_type text not null default 'table';
alter table public.dining_locations add column if not exists capacity integer;
alter table public.dining_locations add column if not exists description text;
alter table public.dining_locations add column if not exists qr_code text;
do $$ begin
 if not exists (select 1 from pg_constraint where conname='dining_locations_qr_code_key') then
  alter table public.dining_locations add constraint dining_locations_qr_code_key unique (qr_code);
 end if;
end $$;

alter table public.admin_staff enable row level security;
alter table public.restaurant_settings enable row level security;
drop policy if exists "authenticated manage staff profiles" on public.admin_staff;
create policy "authenticated manage staff profiles" on public.admin_staff for all to authenticated using (true) with check (true);
drop policy if exists "authenticated manage restaurant settings" on public.restaurant_settings;
create policy "authenticated manage restaurant settings" on public.restaurant_settings for all to authenticated using (true) with check (true);

-- Direct image uploads for food photos and restaurant logo.
-- Creates a public-read bucket; authenticated users may upload/update/delete files.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('quickbite-media', 'quickbite-media', true, 5242880, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public=true, file_size_limit=5242880,
 allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif'];

drop policy if exists "authenticated upload quickbite images" on storage.objects;
create policy "authenticated upload quickbite images" on storage.objects
 for insert to authenticated with check (bucket_id='quickbite-media');
drop policy if exists "authenticated update quickbite images" on storage.objects;
create policy "authenticated update quickbite images" on storage.objects
 for update to authenticated using (bucket_id='quickbite-media') with check (bucket_id='quickbite-media');
drop policy if exists "authenticated delete quickbite images" on storage.objects;
create policy "authenticated delete quickbite images" on storage.objects
 for delete to authenticated using (bucket_id='quickbite-media');
drop policy if exists "public read quickbite images" on storage.objects;
create policy "public read quickbite images" on storage.objects
 for select to public using (bucket_id='quickbite-media');

-- CUSTOMER QR PORTAL POLICIES (MVP)
-- Public customers can read active menu/location records and create orders/items.
-- NOTE: The simple receipt lookup policy below allows anonymous SELECT on orders and
-- order items. For production privacy, replace with a server-side RPC/Edge Function
-- using an unguessable receipt token before exposing this portal publicly.
drop policy if exists "public read active categories" on public.food_categories;
create policy "public read active categories" on public.food_categories for select to anon, authenticated using (is_active = true);
drop policy if exists "public read available food items" on public.food_items;
create policy "public read available food items" on public.food_items for select to anon, authenticated using (is_available = true);
drop policy if exists "public read active dining locations" on public.dining_locations;
create policy "public read active dining locations" on public.dining_locations for select to anon, authenticated using (is_active = true);
drop policy if exists "public create customer orders" on public.food_orders;
create policy "public create customer orders" on public.food_orders for insert to anon, authenticated with check (status = 'pending' and total_amount >= 0);
drop policy if exists "public read order receipts MVP" on public.food_orders;
create policy "public read order receipts MVP" on public.food_orders for select to anon, authenticated using (true);
drop policy if exists "public add order line items" on public.food_order_items;
create policy "public add order line items" on public.food_order_items for insert to anon, authenticated with check (quantity > 0 and unit_price >= 0 and line_total >= 0);
drop policy if exists "public read receipt line items MVP" on public.food_order_items;
create policy "public read receipt line items MVP" on public.food_order_items for select to anon, authenticated using (true);

-- Customer name/phone lookup and order notes (safe to rerun).
alter table public.food_orders add column if not exists customer_phone text;
alter table public.food_orders add column if not exists notes text;
create index if not exists food_orders_customer_phone_idx on public.food_orders(customer_phone);
-- Public customer order flow. Existing policy names are replaced idempotently.
drop policy if exists "public create customer orders" on public.food_orders;
create policy "public create customer orders" on public.food_orders for insert to anon, authenticated with check (status = 'pending' and total_amount >= 0);
drop policy if exists "public read order receipts MVP" on public.food_orders;
create policy "public read order receipts MVP" on public.food_orders for select to anon, authenticated using (true);
drop policy if exists "public create customer order items" on public.food_order_items;
create policy "public create customer order items" on public.food_order_items for insert to anon, authenticated with check (quantity > 0 and unit_price >= 0 and line_total >= 0);
drop policy if exists "public read customer order items" on public.food_order_items;
create policy "public read customer order items" on public.food_order_items for select to anon, authenticated using (true);


-- Customer-facing restaurant contact details (editable through admin settings UI once fields are added there)
alter table public.restaurant_settings add column if not exists contact_email text not null default '';
alter table public.restaurant_settings add column if not exists contact_phone text not null default '';

-- Owner details shown in the customer page footer and editable in Admin Settings
alter table public.restaurant_settings add column if not exists owner_name text not null default '';
alter table public.restaurant_settings add column if not exists owner_photo_url text;


-- Customer pages are anonymous (QR scan, no login), so allow public read-only
-- access to the single restaurant branding/settings row. Admin writes remain
-- restricted to authenticated users by the policy above.
grant select on public.restaurant_settings to anon, authenticated;
drop policy if exists "public read restaurant settings" on public.restaurant_settings;
create policy "public read restaurant settings" on public.restaurant_settings
  for select to anon, authenticated using (true);

-- Owner contact fields (kept separate, with fallback to restaurant contact).
alter table public.restaurant_settings add column if not exists owner_email text not null default '';
alter table public.restaurant_settings add column if not exists owner_phone text not null default '';


-- Manual daily closing snapshots. One record per business-local calendar date.
-- Revenue snapshots include completed orders only; the admin UI performs the
-- close explicitly and upserts by business_date to prevent duplicate records.
create table if not exists public.daily_closings (
 business_date date primary key,
 closed_at timestamptz not null default now(),
 completed_orders integer not null default 0 check(completed_orders>=0),
 revenue numeric(12,2) not null default 0 check(revenue>=0)
);
alter table public.daily_closings enable row level security;
drop policy if exists "authenticated manage daily closings" on public.daily_closings;
create policy "authenticated manage daily closings" on public.daily_closings
 for all to authenticated using (true) with check (true);

-- Admin-managed payment QR image shown from the order detail dialog.
alter table public.restaurant_settings add column if not exists payment_qr_url text;


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
