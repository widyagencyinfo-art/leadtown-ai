-- ============================================================
-- LeadTown AI — Setup de Supabase
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- ============================================================

-- 1. Perfiles de usuario (extiende auth.users)
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  name text,
  email text,
  avatar_url text,
  plan text default 'free',
  plan_active boolean default false,
  stripe_customer_id text,
  stripe_subscription_id text,
  cities jsonb default '[]'::jsonb,
  price_per_web integer default 400,
  monthly_goal integer default 5,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. Estados de leads (nuevo, contactado, respondio, vendido)
create table if not exists public.lead_states (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  lead_key text not null,
  status text not null default 'nuevo',
  updated_at timestamptz default now(),
  unique(user_id, lead_key)
);

-- 3. Leads guardados/destacados
create table if not exists public.saved_leads (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  lead_key text not null,
  created_at timestamptz default now(),
  unique(user_id, lead_key)
);

-- 4. CRM — clientes vendidos
create table if not exists public.clients (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  amount numeric default 0,
  city text,
  note text,
  lead_key text,
  created_at timestamptz default now()
);

-- 5. Registro de visitas / analytics básico
create table if not exists public.analytics (
  id bigint generated always as identity primary key,
  event text not null,
  user_id uuid references public.profiles(id) on delete set null,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table public.profiles enable row level security;
alter table public.lead_states enable row level security;
alter table public.saved_leads enable row level security;
alter table public.clients enable row level security;
alter table public.analytics enable row level security;

-- Profiles
create policy "Users read own profile"
  on public.profiles for select using (auth.uid() = id);
create policy "Users update own profile"
  on public.profiles for update using (auth.uid() = id);
create policy "Users insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

-- Lead states
create policy "Users manage own lead_states"
  on public.lead_states for all using (auth.uid() = user_id);

-- Saved leads
create policy "Users manage own saved_leads"
  on public.saved_leads for all using (auth.uid() = user_id);

-- Clients
create policy "Users manage own clients"
  on public.clients for all using (auth.uid() = user_id);

-- Analytics: insert para todos los autenticados, select solo admin
create policy "Auth users insert analytics"
  on public.analytics for insert with check (auth.uid() is not null);

-- ============================================================
-- Trigger: crear perfil automáticamente al registrarse
-- ============================================================
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name, email, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture')
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- Índices
-- ============================================================
create index if not exists idx_lead_states_user on public.lead_states(user_id);
create index if not exists idx_saved_leads_user on public.saved_leads(user_id);
create index if not exists idx_clients_user on public.clients(user_id);
create index if not exists idx_analytics_event on public.analytics(event, created_at);
