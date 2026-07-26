# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Primary: the restaurant owner (`role == 'owner'` in Supabase `profiles`), who signs in to manage their restaurant's digital menu end-to-end — categories, items, pricing, availability (sold out), appearance, and publishing.

Secondary (confirmed direction, not yet implemented): restaurant staff members with a non-owner `role`. Today `OwnerGate` (`lib/features/auth/owner_gate.dart`) blocks any non-owner profile from the whole app ("Questa funzione è riservata al proprietario del ristorante"). The product direction is for staff to get their own, narrower access — e.g. toggling item availability/sold-out — without the owner-only management surface (menu editing, appearance, publish, AI). Scope and screens for the staff role are not yet designed.

Tertiary: diners, who view the published menu as a public read-only web page at `{slug}.mangialoqui.it/menu` — no login, no app install.

## Product Purpose

A menu-management module that lets a restaurant owner (and, in the future, staff) keep their public-facing digital menu accurate and on-brand with minimal friction: edit categories/items, mark things sold out in real time, restyle the public page's look, and publish changes — including via a conversational AI assistant (typed or spoken) instead of manual form editing. Success is a public menu that is always accurate (nothing sold-out shown as available) and reflects the restaurant's current offering and branding with as little owner effort as possible.

## Positioning

Part of the broader Mangialoqui platform (mangialoqui.it), which also covers other restaurant-facing services (e.g. reservations, per the `/api/prenow/account` endpoint this app calls to claim platform access) — this app is specifically the menu module ("Menu Pro" internally), not the whole platform. Its differentiator versus a typical menu-CMS is natural-language editing: the owner can type or speak an instruction ("Aggiungi categoria pesce", "Nascondi categoria pesce dal menu", "Aggiungi un burger vegetariano a 11€") and the AI assistant (`lib/features/ai/`) translates it into concrete category/item changes, rather than requiring the owner to navigate forms.

## Operating Context

- Owner-facing app (this Flutter codebase) ships to Android, iOS, and desktop (macOS/Windows/Linux); a `web` build target also exists.
- Public menu is a plain web page (no auth) at a per-restaurant subdomain: `{restaurant.slug}.mangialoqui.it/menu`.
- Backend is Supabase (Postgres + Auth) — tables include `restaurants`, `profiles` (with `role`), `menu_categories`, `menu_items`. `.env` holds `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `DEV_USE_ANON`.
- Cross-app account linking: this app calls `https://www.mangialoqui.it/api/prenow/account` to claim platform access from an allowed email, implying a separate Mangialoqui platform surface/backend beyond this repo.
- Owner workflow observed in the code: Home (status + shortcuts) → Menu (categories/items) → Availability (sold-out toggles) → Appearance (font/theme/logo) → Publish (status/versions) → AI chat as a cross-cutting fast-edit tool.
- Italian is the UI language throughout; the market is Italian restaurants.

## Capabilities and Constraints

- Menu structure: categories and items, each with an active/inactive (hidden) flag and items additionally with a sold-out flag, price in cents + currency, and sort order.
- Appearance customization (`lib/features/appearance/`): font choice (Moderno/Elegante/Classico/Compatto), theme/color preset (e.g. "Ocean Light"), logo upload/display toggle.
- Publishing (`lib/features/publish/`): explicit publish action with published/unpublished status and version history, distinct from live-editing the draft menu.
- AI assistant (`lib/features/ai/`): typed or voice (`speech_to_text`) natural-language requests, resolved into a fixed action vocabulary (`create_category`, `hide_category`/`delete_category`, `create_item`, `hide_item`/`delete_item`) applied directly to Supabase; keeps a history log per prompt (`ai_repository`/`saveHistory`).
- Auth: Supabase email/password sign-in; `profiles.role` distinguishes `owner` from other roles, but only `owner` currently has any in-app capability — staff-specific screens/permissions are an open, unimplemented product decision.
- Undecided: exact staff-role permission boundary (which screens/actions staff should reach), and how deep the Mangialoqui platform integration (reservations, etc.) should surface inside this app versus staying external.

## Brand Commitments

- Product/company name: **Mangialoqui** (platform), this app's owner-facing surface is internally called **Menu Pro** (see copy in `owner_gate.dart`: "accesso a Menu Pro").
- Public menu URL pattern is a fixed brand asset: `{slug}.mangialoqui.it`.

## Evidence on Hand

- No testimonials, case studies, pricing, or press exist in the repo — none should be fabricated.
- Real domain/brand asset: `mangialoqui.it` and the `{slug}.mangialoqui.it/menu` public-menu URL pattern.
- App icon/web assets exist at `web/favicon.png`, `web/icons/`, `web/manifest.json` but were not inspected for brand fidelity.

## Product Principles

- Owner speed over completeness: the fastest path to "menu is accurate right now" (sold-out toggle, AI quick edits) matters more than exhaustive management screens.
- Draft vs. published are distinct states — nothing an owner edits should reach diners until an explicit publish.
- Natural language is a first-class input method, not a gimmick bolted onto forms; typed and spoken requests should reach parity with manual editing wherever feasible.
- The public menu is the actual product from a diner's perspective: it must stay simple, fast, and correct even though all the app's complexity lives on the owner side.
- Owner-only today, multi-role tomorrow: design decisions should not assume `owner` is the only role forever, even though staff access isn't built yet.
