-- ============================================================
-- SCHE / South Zone WD Performance Dashboard — Supabase Schema
-- Run this once in Supabase: Project → SQL Editor → New query → Run
-- ============================================================

-- 1. PROFILES table (extends Supabase auth.users)
-- Every branch manager / admin who logs in gets a row here.
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  role text not null check (role in ('super_admin', 'branch_manager')),
  branch text, -- branch code e.g. 'SHYD', 'SBLR' — null for super_admin
  full_name text,
  created_at timestamptz default now()
);

-- 2. WD_PERFORMANCE table — the actual dashboard data
create table if not exists wd_performance (
  id bigserial primary key,
  branch text not null,
  wd_code text not null,
  wd_name text not null,
  city text,
  level text,           -- 'Category' / 'Subcat' / 'Sub Cat'
  category text,         -- e.g. 'Chocolate', 'DF FILLS', 'MP creams', 'Savlon Handwash'
  channel text,           -- 'GR1A' / 'GR1B' / 'GR2' / 'CFP'
  metric text,            -- 'Value' / 'UOB'
  ach numeric,
  target numeric,
  period text default to_char(now(), 'YYYY-MM'), -- upload batch/month, e.g. '2026-08'
  uploaded_by uuid references auth.users(id),
  uploaded_at timestamptz default now()
);

create index if not exists idx_wd_performance_branch on wd_performance(branch);
create index if not exists idx_wd_performance_wd_code on wd_performance(wd_code);
create index if not exists idx_wd_performance_period on wd_performance(period);

-- 3. WD_LOGIN_CODES table — maps a WD's simple access code to their wd_code
-- (keeps the WD-facing login simple, like the old passcode gate,
--  without giving WDs a full Supabase Auth account)
create table if not exists wd_login_codes (
  id bigserial primary key,
  login_code text unique not null,  -- what the WD types in to view their dashboard
  wd_code text not null,            -- matches wd_performance.wd_code
  branch text not null,
  active boolean default true,
  created_at timestamptz default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table profiles enable row level security;
alter table wd_performance enable row level security;
alter table wd_login_codes enable row level security;

-- Profiles: users can read their own profile
create policy "Users can read own profile"
  on profiles for select
  using (auth.uid() = id);

-- WD_PERFORMANCE: branch managers can read/write only their branch;
-- super_admins can read/write everything.
create policy "Branch managers manage their branch data"
  on wd_performance for all
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid()
      and (profiles.role = 'super_admin' or profiles.branch = wd_performance.branch)
    )
  )
  with check (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid()
      and (profiles.role = 'super_admin' or profiles.branch = wd_performance.branch)
    )
  );

-- IMPORTANT: no policy grants direct SELECT to anonymous/public users.
-- WD viewers NEVER query wd_performance directly — they go through
-- the get_wd_dashboard() function below, which is the only door in.

-- WD_LOGIN_CODES: only admins/branch managers can manage codes
create policy "Branch managers manage their branch codes"
  on wd_login_codes for all
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid()
      and (profiles.role = 'super_admin' or profiles.branch = wd_login_codes.branch)
    )
  );

-- ============================================================
-- SECURE RPC FUNCTION — the only way anonymous WD viewers get data
-- SECURITY DEFINER bypasses RLS internally, but only ever returns
-- rows matching the exact WD tied to the submitted login code.
-- ============================================================

create or replace function get_wd_dashboard(p_login_code text)
returns table (
  branch text,
  wd_code text,
  wd_name text,
  city text,
  level text,
  category text,
  channel text,
  metric text,
  ach numeric,
  target numeric,
  period text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wd_code text;
begin
  select wl.wd_code into v_wd_code
  from wd_login_codes wl
  where wl.login_code = p_login_code and wl.active = true;

  if v_wd_code is null then
    return; -- empty result, invalid code
  end if;

  return query
  select wp.branch, wp.wd_code, wp.wd_name, wp.city, wp.level,
         wp.category, wp.channel, wp.metric, wp.ach, wp.target, wp.period
  from wd_performance wp
  where wp.wd_code = v_wd_code
  order by wp.period desc, wp.category, wp.channel;
end;
$$;

-- Allow anonymous (anon) role to call this function — but NOT to
-- query wd_performance or wd_login_codes directly.
grant execute on function get_wd_dashboard(text) to anon;

-- ============================================================
-- SETUP NOTES (do these after running this script)
-- ============================================================
-- 1. Create branch manager logins:
--    Supabase Dashboard → Authentication → Users → Add User
--    (set email + temporary password, they can reset it later)
--
-- 2. For each user created, insert their profile row, e.g.:
--    insert into profiles (id, email, role, branch, full_name)
--    values ('<paste-user-uuid-here>', 'manager@example.com', 'branch_manager', 'SHYD', 'Name');
--
-- 3. For yourself (super admin):
--    insert into profiles (id, email, role, branch, full_name)
--    values ('<your-user-uuid>', 'you@example.com', 'super_admin', null, 'Kunal');
--
-- 4. Generate WD login codes as you upload data, e.g.:
--    insert into wd_login_codes (login_code, wd_code, branch)
--    values ('HY4352-2026', 'HY4352', 'SRAY');
