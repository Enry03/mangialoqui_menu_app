-- Recensioni clienti (popup nella pagina menu pubblica) e link recensione
-- Google per ristorante.

alter table public.restaurants
  add column if not exists google_review_url text;

create table if not exists public.menu_reviews (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text,
  customer_name text,
  -- true quando la recensione (4-5 stelle) ha reindirizzato il cliente su Google.
  sent_to_google boolean not null default false,
  created_at timestamptz not null default now(),
  -- Le recensioni basse (<=3 stelle) restano solo nel gestionale: serve un
  -- nome per permettere al ristoratore di capire chi l'ha scritta.
  constraint menu_reviews_name_required_for_low_rating
    check (rating > 3 or customer_name is not null)
);

create index if not exists menu_reviews_restaurant_id_idx
  on public.menu_reviews (restaurant_id, created_at desc);

alter table public.menu_reviews enable row level security;

-- Il popup nel menu pubblico non richiede login: chiunque deve poter
-- inviare una recensione per un ristorante.
drop policy if exists "menu_reviews_public_insert" on public.menu_reviews;
create policy "menu_reviews_public_insert"
  on public.menu_reviews
  for insert
  to anon, authenticated
  with check (true);

-- Solo lo staff assegnato al ristorante (stesso criterio usato per le
-- altre tabelle: profiles.restaurant_id + is_hired) puo' leggere le
-- recensioni ricevute.
drop policy if exists "menu_reviews_staff_select" on public.menu_reviews;
create policy "menu_reviews_staff_select"
  on public.menu_reviews
  for select
  to authenticated
  using (
    restaurant_id in (
      select restaurant_id from public.profiles
      where id = auth.uid() and is_hired = true
    )
  );
