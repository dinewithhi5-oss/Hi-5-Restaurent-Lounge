# SmartDine Supabase setup and fresh-start guide

## What is included

- `schema.sql`: complete database setup used by this app (tables, columns, indexes, RLS policies, and the `quickbite-media` Storage bucket/policies).
- `reset_order_data.sql`: optional transaction cleanup script. It deletes order items, orders, and daily closing snapshots only.
- `../js/config.js`: current project URL and browser-safe publishable/anon key configuration. Never put a Supabase `service_role` or secret key in frontend files.

## Set up a new Supabase project

1. Create a Supabase project.
2. Open **SQL Editor** and run the entire `schema.sql` file.
3. In **Authentication -> Users**, create the restaurant admin login.
4. Copy the new project's Project URL and publishable/anon key from **Project Settings -> API** into `js/config.js`. Do not use a secret/service-role key.
5. In **Authentication -> URL Configuration**, add the deployed website URL to the allowed site/redirect URLs as needed.
6. Deploy this folder to a static web host or run it with a local development server.
7. Test admin sign-in, categories, menu items, QR locations, customer order placement, order status voice alerts, receipts, reports, image uploads, and manual daily closing.

## Start with an empty order history in the existing project

If you want to clear the current database's order history, first make a backup if it may be needed. Then open **Supabase Dashboard -> SQL Editor**, paste/run `reset_order_data.sql`, and confirm all three returned counts are zero. This script does not remove menu items, categories, QR locations, staff profiles, restaurant settings, Auth users, or Storage files.

The ZIP cannot execute SQL against your hosted Supabase project by itself. The reset script must be run in the Supabase SQL Editor for the live database to become empty.

## Important security note

This project currently uses the browser-side publishable/anon key and the RLS policies in `schema.sql`. The included customer order lookup policies are an MVP implementation and allow broad anonymous reads of order records. Before using real customer information at scale, replace them with a secure server-side order lookup using an unguessable receipt token or an Edge Function/RPC, and restrict authenticated admin policies to approved admin accounts.
