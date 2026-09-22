-- Lista di ingredienti personalizzata per ristorante (sezione "Ingredienti"),
-- da poter selezionare rapidamente quando si aggiunge un piatto a mano.

create table if not exists public.restaurant_ingredients (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (restaurant_id, name)
);

create index if not exists restaurant_ingredients_restaurant_id_idx
  on public.restaurant_ingredients (restaurant_id, sort_order);

alter table public.restaurant_ingredients enable row level security;

drop policy if exists "restaurant_ingredients_public_select" on public.restaurant_ingredients;
create policy "restaurant_ingredients_public_select"
  on public.restaurant_ingredients
  for select
  to anon, authenticated
  using (true);

drop policy if exists "restaurant_ingredients_staff_write" on public.restaurant_ingredients;
create policy "restaurant_ingredients_staff_write"
  on public.restaurant_ingredients
  for all
  to authenticated
  using (
    restaurant_id in (
      select restaurant_id from public.profiles
      where id = auth.uid() and is_hired = true
    )
  )
  with check (
    restaurant_id in (
      select restaurant_id from public.profiles
      where id = auth.uid() and is_hired = true
    )
  );

-- Ingredienti selezionati per ogni piatto (nomi liberi, come gia' avviene
-- per gli allergeni), indipendente dalla descrizione testuale del piatto.
alter table public.menu_items
  add column if not exists ingredients text[] not null default '{}';
