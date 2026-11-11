# QuickBite — QR Food Ordering Admin Starter

Admin-only first phase built with HTML, CSS, JavaScript and Supabase.

## Included
- Supabase email/password admin login
- Home dashboard: available items, categories, active locations and today's orders
- Add/edit/delete categories
- Add/edit/delete food items, category association, price, optional image URL, availability toggle
- Add/edit/delete rooms or tables; unique QR code value is generated for each
- Orders list, search/filter and status updates
- Basic summary reports and CSV order export
- Responsive layout for desktop and mobile

## Setup
1. Create a Supabase project.
2. Open **SQL Editor**, paste and run `supabase/schema.sql`.
3. In Supabase **Authentication → Users**, create your admin user (email/password).
4. Open `js/config.js` and replace `SUPABASE_URL` and `SUPABASE_ANON_KEY` with your project's URL and anon/public key.
   - Project Settings → API.
   - Never use the `service_role` key in browser code.
5. Open `index.html` using a local web server (recommended: VS Code Live Server), or host the folder on a static host.
6. Sign in using the admin user you created.

## Important security note
This starter grants full table access to any authenticated Supabase user. For production, use an admin-role table or custom claims and policies that verify the user's admin role. Do not create public sign-up for admin accounts. Customer portal RLS policies and order-submission validation should be added in the customer phase.

## QR/customer phase
Each room/table stores a unique `qr_code` value. This phase does not yet generate QR image files or implement customer ordering. The next portal can use a URL such as:
`https://your-site.example/customer.html?location=QB-XXXXXXXXXX`
and resolve the location code in Supabase.

## Notes
- Currency display is currently Nu. (Bhutanese ngultrum); change the `money()` function in `js/app.js` if needed.
- Reports summarize the orders currently loaded (up to 500 most recent).

## Added: User management and Settings
- User management supports staff profile create/edit, activate/deactivate and profile deletion.
- Create actual login credentials through Supabase Authentication → Users. This browser-only starter intentionally does not store passwords or administer Auth users directly; production provisioning/deletion requires a protected Edge Function.
- Settings stores restaurant name, location and a public logo image URL. Direct image upload is not included yet; use a public image URL for now.
- Re-run the updated `supabase/schema.sql` in SQL Editor (safe `create table if not exists` additions).

## Direct image uploads
Food item images and the restaurant logo can now be uploaded from the admin forms (image file, max 5 MB). Images are stored in the Supabase Storage bucket `quickbite-media`; public URLs are saved in the database. Run the updated `supabase/schema.sql` to create the bucket and storage policies. Allowed formats: JPEG, PNG, WebP, GIF.

## Customer QR ordering portal
- Open `customer.html` for the customer menu and cart.
- QR links should point to `customer.html?qr=YOUR_EXACT_QR_CODE`, where the value matches `dining_locations.qr_code` in Supabase.
- After placing an order, customers see a successful order message and are taken directly to the **My Order** page. Their phone number is filled in and their order status is loaded automatically. The My Bill section remains available separately.
- The customer portal uses the same Supabase values in `js/config.js` as the admin page.
- Run the customer policy section at the bottom of `supabase/schema.sql` in Supabase SQL Editor after the existing schema. It is safe to re-run because policies are dropped before creation.
- For local testing, serve the folder with VS Code Live Server or another static web server; don't open HTML as a `file://` URL.

**Privacy/security note:** This starter's anonymous receipt SELECT policies are an MVP convenience and allow anonymous users to query order records. Before public production use, replace them with a secure Edge Function/RPC and an unguessable receipt token so customers can only retrieve their own receipt. Do not expose a Supabase service-role key in browser code.


## SmartDine improvements in this version

### Bhutanese restaurant home page
- The admin Home page now has a large Bhutanese restaurant hero photograph.
- Existing dashboard statistic cards, food categories, recently added food and recent orders are retained.
- Replace `assets/bhutanese-restaurant-hero.png` with another image if the restaurant wants a different look. Keep the same filename or update the CSS background path.

### New order alerts and sound
- The admin checks for new customer orders every 7 seconds while signed in.
- A pop-up notification appears with the order number, table/room and total.
- The Orders navigation badge continues to show the number of active orders, and the Orders page has a separate count of new orders received during the current admin session.
- Open **Orders** and click **Enable sound** once. Browsers require a user click before playing sound. After enabling, new orders play a chime and, where supported by the browser, speak: “You received a new order.”
- The sound setting remains active while navigating the admin pages in the current session. Use the same Orders button to turn it off.
- The alert counter can be reset with **Clear count**. This does not delete or change any order.

### Important
- New-order monitoring requires an active internet connection and working Supabase access.
- Keep the browser tab open and signed in for live alerts. If the browser or computer is asleep, notifications may be delayed until it becomes active again.
- Sound and spoken announcement depend on browser audio permissions and speech synthesis support.


## Admin order-page improvements
- Orders are displayed as readable cards in newest-first order instead of a crowded table.
- Search supports order number, customer name, and room/table; status filtering and per-order status updates remain available.
- The top-bar bell opens the Orders page and shows the count of newly received orders.
- New-order alerts include order number, table/room, customer, item summary, total, and a View order details action.
- The order history query now loads up to 1,000 recent orders; live polling can collect up to 200 new orders per check.


## SmartDine daily closing and revenue rules

- Daily closing is **manual**. Open Reports and summary, review the current day's totals, then select **Close day manually** and confirm. No automatic midnight close runs.
- Revenue includes **completed orders only**. Orders in any other status do not contribute to dashboard or report revenue.
- Daily closing snapshots are stored in `public.daily_closings`, with one row per business-local date. Run the updated `supabase/schema.sql` in the Supabase SQL Editor before using this feature.
- New-order notifications are de-duplicated by order ID, and the polling loop prevents overlapping checks to avoid duplicate voice announcements.

## Latest order tracking improvements

- Admin Orders cards now turn **green** when an order is `preparing` and **yellow** when an order is `completed`.
- Added an authenticated **Track Order** page in the admin sidebar. Search the loaded order history by the customer's exact phone number or receipt/order number, then open the order details or print its receipt.
- Added a standalone customer-facing `track-order.html` page, linked from the customer menu. Customers can look up their past orders by phone number or receipt/order number and see the latest status and itemized totals.
- These changes reuse the existing order and order-item tables; no additional database migration is required. The public customer lookup relies on the existing public read policies documented in `supabase/schema.sql`.

## Final handover and Supabase migration

See [`SUPABASE_MIGRATION_GUIDE.md`](SUPABASE_MIGRATION_GUIDE.md) for the recommended way to transfer this existing Supabase project to another email/organization, or to create a new project and migrate data. The full SQL setup is in `supabase/schema.sql`. Note that SQL schema does not include live database rows or uploaded Storage files.

## Final UI cleanup

- Removed the Supabase setup note from the bottom of the admin login form.
- Removed the welcome headline and descriptive overlay from the admin Home hero background while retaining the background image/banner.


## Customer status voice and successful order flow

- Customer status polling announces **confirmed**, **preparing**, **ready**, **completed**, and **cancelled** status changes.
- After a successful order submission, the customer sees a clear success message with the order number on the My Order page.
- The customer is taken to My Order only; the My Bill lookup is not automatically opened.

## Supabase fresh-start files

- `supabase/schema.sql` is the complete schema/setup SQL for this application.
- `supabase/reset_order_data.sql` clears only order items, orders, and daily closing snapshots. Run it manually in the Supabase SQL Editor after taking a backup.
- `supabase/SETUP_AND_RESET.md` explains new-project setup and how to reset order history.
- The reset SQL is included for you; it is not executed automatically against your live Supabase project.
