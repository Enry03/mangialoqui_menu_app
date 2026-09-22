-- La tabella restaurants usa grant espliciti per colonna (non sull'intera
-- tabella): una colonna nuova non eredita automaticamente i permessi delle
-- altre. Concediamo esplicitamente l'accesso alla nuova colonna:
-- - anon: deve poter leggerla, serve al popup recensioni nel menu pubblico
--   per costruire il link di reindirizzamento a Google.
-- - authenticated: deve poterla leggere e modificare dalla pagina
--   Impostazioni dell'app (le righe restano comunque filtrate dalle policy
--   RLS gia' esistenti sulla tabella).
grant select (google_review_url) on public.restaurants to anon;
grant select (google_review_url) on public.restaurants to authenticated;
grant update (google_review_url) on public.restaurants to authenticated;
