# Between Us — Secure Parent + Teen Edition

A lightweight GitHub Pages app using **Supabase Auth** and a **Postgres database with row-level security**. Separate parent and teen email/password accounts, shared check-ins, guided conversations, pause requests, and mutually approved plans.

## Install (about 10 steps)

1. Create a **new Supabase project** at https://supabase.com/dashboard. Do not reuse the database from a different app.
2. Open **SQL Editor → New query** and paste the complete contents of `database.sql`. Click **Run** exactly once. This creates four prefixed tables, security policies, and five functions. (It does **not** drop any existing tables.)
3. Open **Project Settings → API Keys** and get the **publishable key**, or legacy **anon** key. Also copy the **Project URL** from project settings.
4. Edit `config.js`: replace the two placeholders with your URL and **public** key. The publishable/anon key is designed to be public **when RLS is correctly configured**. **Never commit a service_role or secret key**.
5. In **Authentication → Providers → Email**, enable email/password signups. Consider leaving **Confirm email** enabled for security.
6. In **Authentication → URL Configuration**, set **Site URL** to your GitHub Pages address (e.g. `https://YOURNAME.github.io/between-us/`). Add the same URL under **Redirect URLs**. Set these *before* testing signup, confirmation, or password reset.
7. Create a new GitHub repository, e.g. `between-us`. Upload these files **at the repository root**: `index.html`, `app.js`, `config.js`, `sw.js`, `manifest.webmanifest`, `icon.svg`, `icon-192.png`, `icon-512.png`. You can keep `database.sql` and this README there too (they do not contain secrets).
8. GitHub repository → **Settings → Pages** → **Deploy from a branch** → `main` → `/ (root)` → Save. Wait until GitHub shows your published URL.
9. On the parent's device: create an account, confirm email if required, sign in, and choose **Create our family**. Copy and privately share the displayed invitation code with the daughter. If it gets lost before use, **Settings → Generate a new invitation code** invalidates the previous one.
10. On the daughter's device: create **her own** account with **her own email**, confirm it, sign in, choose **Join your parent**, and paste the invite. Then each can use their own phone independently.

## Security model

- Each member must authenticate with Supabase email/password. RLS ensures database records are readable only by authenticated members of the matching family; inserts require current user ID and matching family membership.
- First signup does not grant a parent/teen role. A parent creates a family; an invited second person becomes the teen. Each account can join only one family. Only one member per role is allowed.
- Invitation code is a cryptographically random 128-bit secret, stored only as a hash, consumed once, and cannot be read back from the database. Do not share it publicly.
- Plans can only be agreed to by the actual authenticated parent or teen through a restricted database function. One person cannot approve on behalf of both.
- Shared content is shown to **both** accounts. The app has no secret monitoring, journaling or private analytics.
- Auth sessions may be stored by Supabase in the browser, so sign out on shared devices. No offline family-data cache. The public app shell may be cached for installation.
- There is **no end-to-end encryption**: Supabase infrastructure/project administrators with privileged access may access stored content. Enable multi-factor authentication and careful project access controls for administrators where available.
- This is a functional starter, **not a formally audited medical or child-privacy product**. A parent should review privacy, informed consent, data retention, and applicable law before distributing it beyond their family. Avoid using it for emergencies.
- No realtime push: tap another navigation tab or reload to see newly shared content from another device. Entries are limited to recent 300 and plans to recent 100 per family in this version.

## Troubleshooting

- **“Connect your database”**: `config.js` is still a placeholder or has an invalid URL/key.
- **“relation public.bu_members does not exist”**: run `database.sql` in the same Supabase project whose URL you added.
- **No email arrives**: check Supabase email confirmation settings, sender limits, and the spam folder. Production apps should configure custom SMTP.
- **“Email not confirmed”**: use the confirmation link received after signup.
- **Confirmation links redirect to localhost**: fix the Auth URL Configuration first.
- **Already in family**: each account supports one family. Do not share a login between family members.
- **New site content not showing**: hard refresh and inspect browser cache/service worker.
- **Do not run v1 import**: The original v1 browser-only data is **not migrated automatically**. Version 2 uses a different database, so retain any v1 backup separately.

## Resource links

- https://supabase.com/docs/guides/auth/passwords
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/database/functions
- https://www.cdc.gov/adhd/about/
- https://chadd.org/for-parents/parenting-teens-with-adhd/
