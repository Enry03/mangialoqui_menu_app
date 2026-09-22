-- Sezione opzionale "Menu/Combo" (piu' piatti+bevande a prezzo promozionale)
-- e "varianti" per piatto (es. burger singolo/doppio/triplo).
-- Tabelle nuove: nessuna colonna esistente viene toccata.

create table if not exists public.menu_combos (
  id uuid primary key default gen_random_uuid(),
  menu_id uuid not null references public.menus(id) on delete cascade,
  name text not null,
  description text,
  price_cents integer not null check (price_cents > 0),
  currency text not null default 'EUR',
  sort_order integer not null default 0,
  menu_combo_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists menu_combos_menu_id_idx
  on public.menu_combos (menu_id, sort_order);

create table if not exists public.menu_combo_items (
  id uuid primary key default gen_random_uuid(),
  combo_id uuid not null references public.menu_combos(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id) on delete cascade,
  quantity integer not null default 1 check (quantity > 0),
  created_at timestamptz not null default now(),
  unique (combo_id, menu_item_id)
);

create index if not exists menu_combo_items_combo_id_idx
  on public.menu_combo_items (combo_id);

-- menu_id denormalizzato per poter caricare tutte le varianti di un menu
-- con una sola query, come gia' si fa per categorie/piatti.
create table if not exists public.menu_item_variants (
  id uuid primary key default gen_random_uuid(),
  menu_id uuid not null references public.menus(id) on delete cascade,
  item_id uuid not null references public.menu_items(id) on delete cascade,
  label text not null,
  icon_key text not null default 'restaurant_menu',
  price_cents integer not null check (price_cents > 0),
  sort_order integer not null default 0,
  menu_item_variant_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists menu_item_variants_menu_id_idx
  on public.menu_item_variants (menu_id, sort_order);

create index if not exists menu_item_variants_item_id_idx
  on public.menu_item_variants (item_id);

alter table public.menu_combos enable row level security;
alter table public.menu_combo_items enable row level security;
alter table public.menu_item_variants enable row level security;

-- Lettura pubblica: il menu lato cliente deve poter mostrare combo e
-- varianti senza login, come gia' avviene per categorie e piatti.
drop policy if exists "menu_combos_public_select" on public.menu_combos;
create policy "menu_combos_public_select"
  on public.menu_combos
  for select
  to anon, authenticated
  using (true);

drop policy if exists "menu_combo_items_public_select" on public.menu_combo_items;
create policy "menu_combo_items_public_select"
  on public.menu_combo_items
  for select
  to anon, authenticated
  using (true);

drop policy if exists "menu_item_variants_public_select" on public.menu_item_variants;
create policy "menu_item_variants_public_select"
  on public.menu_item_variants
  for select
  to anon, authenticated
  using (true);

-- Scrittura riservata allo staff del ristorante proprietario del menu,
-- stesso criterio gia' usato altrove (profiles.restaurant_id + is_hired).
drop policy if exists "menu_combos_staff_write" on public.menu_combos;
create policy "menu_combos_staff_write"
  on public.menu_combos
  for all
  to authenticated
  using (
    menu_id in (
      select m.id from public.menus m
      join public.profiles p on p.restaurant_id = m.restaurant_id
      where p.id = auth.uid() and p.is_hired = true
    )
  )
  with check (
    menu_id in (
      select m.id from public.menus m
      join public.profiles p on p.restaurant_id = m.restaurant_id
      where p.id = auth.uid() and p.is_hired = true
    )
  );

drop policy if exists "menu_combo_items_staff_write" on public.menu_combo_items;
create policy "menu_combo_items_staff_write"
  on public.menu_combo_items
  for all
  to authenticated
  using (
    combo_id in (
      select c.id from public.menu_combos c
      join public.menus m on m.id = c.menu_id
      join public.profiles p on p.restaurant_id = m.restaurant_id
      where p.id = auth.uid() and p.is_hired = true
    )
  )
  with check (
    combo_id in (
      select c.id from public.menu_combos c
      join public.menus m on m.id = c.menu_id
      join public.profiles p on p.restaurant_id = m.restaurant_id
      where p.id = auth.uid() and p.is_hired = true
    )
  );

drop policy if exists "menu_item_variants_staff_write" on public.menu_item_variants;
create policy "menu_item_variants_staff_write"
  on public.menu_item_variants
  for all
  to authenticated
  using (
    menu_id in (
      select m.id from public.menus m
      join public.profiles p on p.restaurant_id = m.restaurant_id
      where p.id = auth.uid() and p.is_hired = true
    )
  )
  with check (
    menu_id in (
      select m.id from public.menus m
      join public.profiles p on p.restaurant_id = m.restaurant_id
      where p.id = auth.uid() and p.is_hired = true
    )
  );
