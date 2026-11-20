# Just Us — loading screen fix

Replace exactly these 3 files in the ROOT of your existing `spental/justus` GitHub repository:

- `index.html`
- `app.js`
- `sw.js`

**Do not delete or replace `config.js` or `database.sql`.** Your existing Supabase project connection and data remain unchanged.

This patch adds an alternate Supabase library host, a startup error screen if module loading fails, a timeout for initial sign-in/database access, and network-first updates for cached app files.

After GitHub Pages deploys, visit `https://spental.github.io/justus/` and do a hard refresh (Mac: Cmd+Shift+R; Windows: Ctrl+Shift+R). If it still shows a problem, open Developer Tools → Console and share the first red error line (do not share passwords or secret keys).

Note: We could verify the published repository source, but could not run the app inside your own browser or Supabase session. This is a defensive fix, not a confirmation of the exact underlying network error.
