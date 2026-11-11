# SmartDine — Supabase ownership transfer and migration guide

This package includes the complete SmartDine SQL setup used by this application in `supabase/schema.sql`, including the app tables, columns, indexes, Row Level Security (RLS) policies, and the `quickbite-media` Storage bucket and policies.

**Important distinction:** the SQL schema creates the database structure. It does not contain your live order/menu/staff rows, Supabase Auth accounts, or uploaded image files. Those live inside your Supabase project and are not embedded in this website ZIP.

## Recommended: move the existing project to the other email without creating a new project

If the goal is simply for another email/account to own and pay for the same SmartDine backend, transfer the existing Supabase project to an organization controlled by that email. This is safer than creating a fresh project because the existing project remains the same backend and its database, Auth users, Storage files, project URL, and keys stay with it.

1. The recipient signs up for Supabase using the new email and creates an organization.
2. Invite the current Supabase account into that target organization. The current account must be the **owner of the source organization** and at least a member of the target organization.
3. In the current project, open **Project Settings → General → Transfer project** (wording may vary slightly in the dashboard).
4. Select the recipient's target organization and complete the transfer prompts.
5. Sign in with the recipient account and confirm the project appears there. Check the project status and billing plan.
6. Open the SmartDine site and test admin login, customer ordering, order tracking, image uploads, payment QR display, reports, and receipts.

Supabase's project transfer requirements can include no active GitHub integration, no project-scoped roles, and no log drains. Plan differences can affect available features; moving from a paid plan to Free can cause brief downtime. The target organization becomes responsible for usage after transfer. See the official guide: https://supabase.com/docs/guides/platform/project-transfer

If you only want to change the email address used to sign in to the **same Supabase account**, update the account email in Supabase account settings instead; a project migration may not be necessary.

## Alternative: create a separate new Supabase project

Use this only if you want a separate backend under the new email rather than transferring the existing project.

1. Create a new Supabase project under the recipient's organization.
2. In the new project's **SQL Editor**, run the complete `supabase/schema.sql` from this package.
3. Create the admin login in **Authentication → Users**. The `admin_staff` table stores staff profile details only; passwords are managed by Supabase Auth.
4. Copy the menu, dining locations, order history, staff profiles, restaurant settings, and daily closing data from the old project. Running `schema.sql` alone does not copy these rows.
5. Recreate the `quickbite-media` Storage bucket and upload the existing food photos, restaurant logo, owner photo, and payment QR image if they are not already present. The SQL file creates the bucket and policies, but does not copy binary files.
6. Reconfigure Auth settings (site URL, redirect URLs, email templates/providers), API keys, and any project-level settings in the new project.
7. Update `js/config.js` with the **new project's** Project URL and publishable/anon key. Never place a `service_role` or secret key in browser code.
8. Test the full application before changing the live website to use the new backend.

For paid projects with physical backups enabled, Supabase documents a **Restore to a new project** flow. It can copy database schema and data, including Auth records, but Storage objects/settings, Edge Functions, Auth settings/API keys, Realtime settings, and some extensions/settings require manual reconfiguration. See: https://supabase.com/docs/guides/platform/clone-project

For manual database backup/restore with the Supabase CLI, follow the current official guide: https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore. It requires database connection strings/passwords and appropriate local tools. Do not put those secrets into this ZIP or commit them to source control.

## What is included in this package's Supabase folder

- `supabase/schema.sql` — full SmartDine schema and policies required by the current app, including daily closing and payment QR settings.
- This guide — recommended ownership transfer and new-project migration steps.

## Security note

The current customer lookup policies are an MVP convenience and allow public reads of order records. Before public production use with real customer data, replace broad anonymous order reads with a secure server-side lookup using an unguessable receipt token or an Edge Function/RPC. Restrict authenticated admin access to authorized admin accounts; the starter policies currently grant broad table access to authenticated users. Never share database passwords, service-role keys, or Supabase access tokens.
