-- BETWEEN US v2: Run in Supabase SQL Editor as the project owner.
-- Fresh installation only. No service_role key belongs on GitHub.
-- App is designed for a single parent + a single teen per family.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.bu_families (
  id uuid primary key default gen_random_uuid(),
  invite_hash text not null unique,
  created_at timestamptz not null default now()
);
create table if not exists public.bu_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  family_id uuid not null references public.bu_families(id) on delete cascade,
  role text not null check (role in ('parent','teen')),
  display_name text not null check (char_length(display_name) between 1 and 60),
  joined_at timestamptz not null default now(),
  unique(family_id,role)
);
create index if not exists bu_members_family_idx on public.bu_members(family_id);
create table if not exists public.bu_entries (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.bu_families(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('checkin','message','pause')),
  body jsonb not null check (jsonb_typeof(body) = 'object' and pg_column_size(body) <= 12000),
  created_at timestamptz not null default now()
);
create index if not exists bu_entries_family_idx on public.bu_entries(family_id,created_at desc);
create table if not exists public.bu_plans (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.bu_families(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  problem text not null check (char_length(problem) between 1 and 600),
  teen_step text not null check (char_length(teen_step) between 1 and 1200),
  parent_step text not null check (char_length(parent_step) between 1 and 1200),
  review_on text not null default '' check (char_length(review_on) <= 100),
  parent_agreed boolean not null default false,
  teen_agreed boolean not null default false,
  archived boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists bu_plans_family_idx on public.bu_plans(family_id, created_at desc);

alter table public.bu_families enable row level security;
alter table public.bu_members enable row level security;
alter table public.bu_entries enable row level security;
alter table public.bu_plans enable row level security;

-- Fixed search_path and schema-qualified references prevent search-path hijacking.
create or replace function public.bu_is_member(p_family uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.bu_members m where m.family_id = p_family and m.user_id = (select auth.uid())) $$;

create policy bu_members_read on public.bu_members for select to authenticated
using (public.bu_is_member(family_id));
create policy bu_entries_read on public.bu_entries for select to authenticated
using (public.bu_is_member(family_id));
create policy bu_entries_insert on public.bu_entries for insert to authenticated
with check (author_id = (select auth.uid()) and public.bu_is_member(family_id));
create policy bu_plans_read on public.bu_plans for select to authenticated
using (public.bu_is_member(family_id));
create policy bu_plans_insert on public.bu_plans for insert to authenticated
with check (author_id = (select auth.uid()) and public.bu_is_member(family_id)
  and parent_agreed = false and teen_agreed = false and archived = false);

-- The invite secret is never stored in plaintext, and can only be used once.
create or replace function public.bu_create_family(p_name text)
returns text language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_code text; v_family uuid;
begin
  if v_user is null then raise exception 'Please sign in first'; end if;
  if char_length(trim(coalesce(p_name,''))) not between 1 and 60 then raise exception 'Enter a name (1-60 characters)'; end if;
  if exists (select 1 from public.bu_members where user_id = v_user) then raise exception 'You already belong to a family'; end if;
  v_code := encode(extensions.gen_random_bytes(16), 'hex');
  insert into public.bu_families(invite_hash) values (md5(v_code)) returning id into v_family;
  insert into public.bu_members(user_id,family_id,role,display_name)
  values (v_user,v_family,'parent',trim(p_name));
  return v_code;
end $$;

create or replace function public.bu_join_family(p_name text, p_code text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_family uuid; v_code text := lower(trim(coalesce(p_code,'')));
begin
  if v_user is null then raise exception 'Please sign in first'; end if;
  if char_length(trim(coalesce(p_name,''))) not between 1 and 60 then raise exception 'Enter a name (1-60 characters)'; end if;
  if exists(select 1 from public.bu_members where user_id = v_user) then raise exception 'You already belong to a family'; end if;
  if v_code !~ '^[0-9a-f]{32}$' then raise exception 'Invalid invitation code'; end if;
  select id into v_family from public.bu_families where invite_hash = md5(v_code) for update;
  if v_family is null then raise exception 'Invalid or already used invitation code'; end if;
  if exists(select 1 from public.bu_members where family_id = v_family and role = 'teen') then
    raise exception 'This family already has a teen account';
  end if;
  insert into public.bu_members(user_id,family_id,role,display_name)
  values(v_user,v_family,'teen',trim(p_name));
  update public.bu_families set invite_hash = md5(encode(extensions.gen_random_bytes(16),'hex')) where id = v_family;
  return true;
end $$;

create or replace function public.bu_rotate_invite()
returns text language plpgsql security definer set search_path = '' as $$
declare v_family uuid; v_code text;
begin
  select family_id into v_family from public.bu_members
  where user_id = auth.uid() and role = 'parent';
  if v_family is null then raise exception 'Only a parent can invite a teen'; end if;
  if exists(select 1 from public.bu_members where family_id = v_family and role = 'teen') then
    raise exception 'This family already has a teen account';
  end if;
  v_code := encode(extensions.gen_random_bytes(16),'hex');
  update public.bu_families set invite_hash = md5(v_code) where id = v_family;
  return v_code;
end $$;

create or replace function public.bu_plan_action(p_id uuid, p_action text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_role text; v_family uuid;
begin
  select family_id into v_family from public.bu_plans where id = p_id;
  if v_family is null then raise exception 'Plan not found'; end if;
  select role into v_role from public.bu_members
  where family_id = v_family and user_id = auth.uid();
  if v_role is null then raise exception 'Not allowed'; end if;
  if p_action = 'agree' then
    if v_role = 'parent' then
      update public.bu_plans set parent_agreed = true where id = p_id and not archived;
    else
      update public.bu_plans set teen_agreed = true where id = p_id and not archived;
    end if;
  elsif p_action = 'archive' then
    update public.bu_plans set archived = true where id = p_id;
  else
    raise exception 'Invalid action';
  end if;
  return true;
end $$;

-- Remove API table access unless explicitly permitted below.
revoke all on public.bu_families, public.bu_members, public.bu_entries, public.bu_plans from anon, authenticated;
grant select on public.bu_members to authenticated;
grant select,insert on public.bu_entries,public.bu_plans to authenticated;
revoke all on function public.bu_is_member(uuid), public.bu_create_family(text),
  public.bu_join_family(text,text), public.bu_rotate_invite(), public.bu_plan_action(uuid,text)
  from public, anon, authenticated;
grant execute on function public.bu_is_member(uuid), public.bu_create_family(text),
  public.bu_join_family(text,text), public.bu_rotate_invite(), public.bu_plan_action(uuid,text)
  to authenticated;
