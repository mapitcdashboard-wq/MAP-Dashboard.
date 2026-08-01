# South Zone WD Performance Portal

Two pages backed by Supabase:
- `index.html` — WD-facing viewer. WDs enter a login code and see only their own data.
- `admin.html` — Admin / branch manager panel. Upload CSVs, generate WD login codes.

## Setup (one-time)

### 1. Create a Supabase project
Go to [supabase.com](https://supabase.com) → New Project. Free tier is enough.

### 2. Run the schema
Project → SQL Editor → New query → paste in the contents of `schema.sql` → Run.
This creates the tables, locks them down with row-level security, and sets up
the secure function WD viewers use to fetch only their own data.

### 3. Get your API keys
Project → Settings → API → copy the **Project URL** and **anon public key**.

### 4. Edit `config.js`
Open `config.js` in this repo and replace the two placeholder values:
```js
window.SUPABASE_URL = 'https://xxxxxxxx.supabase.co';
window.SUPABASE_ANON_KEY = 'eyJhbGciOi...';
```
That's the only file you need to touch — both `index.html` and `admin.html`
read from it automatically.

### 5. Create logins
**Supabase Dashboard → Authentication → Users → Add User** — create one for
yourself and one per branch manager (email + password).

Then, back in **SQL Editor**, run one `insert` per person (swap in their real
user ID from the Users list, and their branch code for managers — leave
`branch` as `null` for yourself as super admin):

```sql
insert into profiles (id, email, role, branch, full_name)
values ('paste-user-uuid-here', 'you@company.com', 'super_admin', null, 'Kunal');

insert into profiles (id, email, role, branch, full_name)
values ('paste-user-uuid-here', 'manager@company.com', 'branch_manager', 'SHYD', 'Manager Name');
```

### 6. Push this repo to GitHub and enable Pages
```bash
git init
git add .
git commit -m "WD performance portal"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```
Then: repo → **Settings → Pages** → Source: `main` branch, `/ (root)` folder → Save.

GitHub gives you a live URL within a minute or two, typically:
```
https://YOUR_USERNAME.github.io/YOUR_REPO/          → WD viewer (index.html)
https://YOUR_USERNAME.github.io/YOUR_REPO/admin.html → Admin panel
```

## Day-to-day use

1. Log into `admin.html`.
2. Upload a CSV with columns: `branch, code, wd, city, level, category, channel, metric, ach, target`
3. Enter a period (e.g. `2026-08`).
4. Preview, then confirm upload.
5. Generate a login code per WD under "Generate WD Login Code" and share it with them.
6. Send WDs the `index.html` link — they type their code and see only their own numbers.

## Files

| File | Purpose |
|---|---|
| `index.html` | WD-facing dashboard (public link) |
| `admin.html` | Admin / branch manager upload panel |
| `config.js` | Your Supabase URL + key (only file you edit) |
| `schema.sql` | Run once in Supabase SQL Editor to set up the database |
