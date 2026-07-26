---
name: Mangialoqui Menu Pro
description: Owner-facing menu management app for Mangialoqui restaurants — calm navy interface with warm amber accents.
colors:
  midnight-navy: "#163E78"
  deep-midnight: "#0F2F5D"
  navy-whisper: "#E8F0FB"
  navy-glow: "#2A5CAA"
  golden-highlight: "#E0A030"
  burnished-gold: "#B97D18"
  golden-whisper: "#FBF0DC"
  pale-sky: "#F5F7FB"
  pure-white: "#FFFFFF"
  soft-cloud: "#F0F4FA"
  powder-blue: "#E8EEF8"
  ink-navy: "#0F172A"
  slate-gray: "#475569"
  muted-steel: "#94A3B8"
  hairline-blue: "#D9E2F0"
  faint-divider: "#E5ECF5"
  confirm-green: "#15803D"
  caution-amber: "#D97706"
  alert-red: "#DC2626"
typography:
  headlineLarge:
    fontFamily: "Inter, sans-serif"
    fontSize: "34px"
    fontWeight: 700
    lineHeight: 1.1
  headlineMedium:
    fontFamily: "Inter, sans-serif"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.15
  titleLarge:
    fontFamily: "Inter, sans-serif"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.2
  titleMedium:
    fontFamily: "Inter, sans-serif"
    fontSize: "18px"
    fontWeight: 600
    lineHeight: 1.25
  bodyLarge:
    fontFamily: "Inter, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.45
  bodyMedium:
    fontFamily: "Inter, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
  labelLarge:
    fontFamily: "Inter, sans-serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.2
  labelMedium:
    fontFamily: "Inter, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.3px"
rounded:
  sm: "10px"
  md: "16px"
  lg: "22px"
  xl: "28px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
  xxxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.midnight-navy}"
    textColor: "{colors.pure-white}"
    typography: "{typography.labelLarge}"
    rounded: "{rounded.lg}"
    height: "54px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.midnight-navy}"
    typography: "{typography.labelLarge}"
    rounded: "{rounded.lg}"
    height: "54px"
  card:
    backgroundColor: "{colors.pure-white}"
    rounded: "{rounded.lg}"
    padding: "20px"
  chip-default:
    backgroundColor: "{colors.navy-whisper}"
    textColor: "{colors.midnight-navy}"
    rounded: "{rounded.pill}"
    padding: "6px 10px"
  chip-selected:
    backgroundColor: "{colors.midnight-navy}"
    textColor: "{colors.pure-white}"
    rounded: "{rounded.pill}"
    padding: "6px 10px"
  input:
    backgroundColor: "{colors.pure-white}"
    rounded: "{rounded.md}"
    padding: "16px"
---

# Design System: Mangialoqui Menu Pro

## Overview

**Creative North Star: "The Navy Ledger"**

Menu Pro reads like a well-kept ledger a restaurant owner would actually trust with the numbers that matter: a deep, steady navy carries structure and authority, while a warm amber only ever marks the entries worth noticing — a sold-out badge, a highlighted price, the active tab. The tone is warm, reassuring, and friendly rather than corporate-cold: rounded-everywhere geometry, generous internal padding, and gentle press/entrance animation keep a tool used under real operational pressure (service about to start, a dish just ran out) from feeling clinical.

Components stay flat at rest — Material elevation is switched off across app bars, cards, and buttons — and depth is instead suggested by soft, navy-tinted ambient glows under a handful of key surfaces (the home hero, empty states, intro cards). This isn't a load-bearing rule the system polices everywhere; it's simply how the current screens create lift where it matters (the welcome hero, feature intros) without resorting to hard drop shadows.

**Key Characteristics:**
- Deep navy structure, amber used only as a rare accent for status and emphasis.
- Flat Material components (zero elevation) lifted selectively with soft, color-tinted ambient glows rather than gray/black shadows.
- Very generous corner rounding (10–28px) and pill-shaped chips/badges — no sharp corners anywhere in the system.
- Inter throughout, one type family carrying both weight and warmth.
- Soft, responsive micro-interactions: a slight scale-down on press, a gentle fade-and-rise on screen entry.

## Colors

A cool, professional navy field punctuated by a single warm accent, so the eye always knows where to look for status and money.

### Primary
- **Midnight Navy** (`#163E78`): the app's structural color — primary buttons, active nav icon/label, focused input border, section headers' implicit emphasis, the home hero gradient's base tone.
- **Deep Midnight** (`#0F2F5D`): the darker end of the hero gradient; reserved for gradient depth, not used as a flat fill elsewhere.
- **Navy Glow** (`#2A5CAA`): the `ColorScheme.secondary`; a lighter navy used sparingly for secondary emphasis inside the primary family.

### Secondary
- **Navy Whisper** (`#E8F0FB`): the tint behind selected chips, icon badges, and default chip backgrounds — navy at its quietest.

### Tertiary
- **Golden Highlight** (`#E0A030`): the system's only warm color, and deliberately rare — badges, highlighted prices, secondary CTAs, and the active/published-status pill. It never fills a large surface.
- **Burnished Gold** (`#B97D18`): the darker accent tone for text/icons that need amber emphasis with better contrast (e.g. the "sold out" stat tile).
- **Golden Whisper** (`#FBF0DC`): amber's own soft tint, mirroring Navy Whisper's role but for accent-family surfaces.

### Neutral
- **Pale Sky** (`#F5F7FB`): the app's base background; nearly every screen sits on a subtle top-to-bottom gradient from near-white into this tone.
- **Pure White** (`#FFFFFF`): card and surface fill.
- **Soft Cloud** (`#F0F4FA`) / **Powder Blue** (`#E8EEF8`): alternate surface tints (chat bubbles, secondary surfaces).
- **Ink Navy** (`#0F172A`): primary text color — also doubles as the dark snackbar background.
- **Slate Gray** (`#475569`): secondary/supporting text.
- **Muted Steel** (`#94A3B8`): tertiary/disabled text, unselected nav labels.
- **Hairline Blue** (`#D9E2F0`): the system's one border color, used on nearly every card, input, and container.
- **Faint Divider** (`#E5ECF5`): list and section dividers.
- **Confirm Green** (`#15803D`) / **Caution Amber** (`#D97706`) / **Alert Red** (`#DC2626`): reserved for success/warning/error states; not yet widely exercised in the UI but defined as the system's semantic trio.

### Named Rules
**The Amber-as-Detail Rule.** Golden Highlight (and its dark/soft variants) is used only for details that need to stand out — a badge, a price, an active tab, a status pill — never as a background fill or a large surface. Navy carries structure; amber marks what matters.

## Typography

**Display/Body/Label Font:** Inter (system sans-serif fallback)

**Character:** One typeface across the entire hierarchy, differentiated by weight and size rather than by switching families — this keeps the warm, approachable tone consistent from a 34px hero headline down to a 12px eyebrow label.

### Hierarchy
- **Headline Large** (700, 34px, 1.1 line-height): top-level hero text (e.g. the restaurant name on the Home hero card).
- **Headline Medium** (700, 28px, 1.15): page-level headings (public menu title, appearance intro card headline).
- **Title Large** (600, 22px, 1.2, −0.3 letter-spacing where applied): section titles ("Il tuo menu in numeri", "Gestisci", "Colori").
- **Title Medium** (600, 18px, 1.25): card and list-item titles (shortcut card titles, dialog titles).
- **Body Large** (400, 16px, 1.45): primary reading text, menu item names on the public menu.
- **Body Medium** (400, 14px, 1.4, Slate Gray): secondary/supporting copy, descriptions, helper text.
- **Label Large** (600, 15px, 1.2): button and interactive-control labels.
- **Label Medium** (600, 12px, 1.2, 0.3px letter-spacing, Muted Steel): small uppercase-style eyebrow labels ("BENVENUTO") and nav bar labels.

## Layout

Mobile-first, single-column layout with generous outer padding (20–24px screen margins via the `xl`/`xxl` spacing tokens) and a consistent vertical rhythm built from a 4/8/12/16/20/24/32px spacing scale. Every screen sits on the same subtle vertical gradient backdrop (near-white fading into Pale Sky) rather than a flat fill.

The Home shortcuts use a 2-column grid (`childAspectRatio: 1.35`) of compact action cards. The AI chat screen is the one place with an explicit responsive breakpoint: below 980px width it renders as a single stacked mobile chat panel; at or above 980px it renders the same chat panel widened for desktop/tablet use. Primary navigation is a persistent 5-item bottom `NavigationBar` (68px tall, hairline top border) — Home, Menù, AI, Disponibilità, Altro.

## Elevation & Depth

Material `elevation` is set to `0` everywhere it's themed (app bar, card, buttons) — the system does not use Material's built-in shadow/tonal-elevation model. Instead, a handful of custom containers (the Home hero, intro cards, empty states, and the pressable action cards) add their own soft, navy-tinted `BoxShadow` for lift: large blur (24–28px), a downward offset (10–14px), and low opacity (0.05–0.10 at rest, up to 0.28 on the primary-gradient hero). This is an implementation pattern observed across the current screens rather than a strictly enforced rule — treat it as the default way to add lift to a standout surface, not as a constraint that every card must follow.

### Shadow Vocabulary
- **Ambient card glow** (`box-shadow: 0 10px 24px rgba(22,62,120,0.05)` approx.): the default lift on intro/empty-state cards.
- **Action-card glow** (`box-shadow: 0 12px 26px rgba(22,62,120,0.10)`, reducing to `0 6px 16px rgba(22,62,120,0.07)` on press): pressable shortcut cards.
- **Hero glow** (`box-shadow: 0 14px 28px rgba(22,62,120,0.28)`): the one strong shadow in the system, under the Home hero's navy gradient card.

## Shapes

A single generous-rounding language, scaled by container importance: `sm` (10px) for inputs and the smallest chip-style elements, `md` (16px) for inputs and icon badges, `lg` (22px) for most cards, buttons, and containers, `xl` (28px) for hero/intro/empty-state cards. Chips and status badges use a full pill/stadium shape. Icon badges and avatars are perfect circles (36–72px). No sharp corners appear anywhere in the observed system.

## Components

### Buttons
- **Shape:** `lg` rounding (22px), fixed 54px height across Filled, Elevated, and Outlined variants.
- **Primary (Filled/Elevated):** Midnight Navy background, white text/icon, zero elevation.
- **Outlined:** transparent background, Hairline Blue border, Midnight Navy text.
- Labels always use Label Large; there is no distinct hover state defined (mobile-first, touch-driven).

### Chips
- **Style:** stadium/pill shape, Navy Whisper background with Midnight Navy label by default; Midnight Navy background with white label when selected. Thin Midnight-Navy-at-10%-opacity border.

### Cards / Containers
- **Corner style:** `lg` (22px) for the themed `CardTheme`; `xl` (28px) for custom hero/intro/empty-state containers.
- **Background:** Pure White, occasionally a barely-there diagonal gradient (white → `#F8FBFF`) on pressable action cards.
- **Shadow strategy:** see Elevation & Depth — soft navy-tinted glow, not Material elevation.
- **Border:** Hairline Blue, 1px, on nearly every card and container.
- **Internal padding:** `lg`–`xxl` (16–24px), `xl` (20px) on the more prominent intro/hero cards.

### Inputs / Fields
- **Style:** filled Pure White background, `md` rounding (16px), Hairline Blue 1px border at rest.
- **Focus:** border shifts to Midnight Navy at 1.5px width (no glow/elevation change).
- **Hint text:** Muted Steel.

### Navigation
- **Style:** bottom `NavigationBar`, 5 destinations (Home, Menù, AI, Disponibilità, Altro), 68px tall, hairline top border, Pure White background.
- **States:** unselected uses the outlined icon variant with Muted Steel label (Label Medium, semi-bold); selected switches to the filled/rounded icon variant with a Navy Whisper pill indicator, Midnight Navy icon, and bold Midnight Navy label.

### Pressable Action Card (signature component)
The recurring `HomeActionCard`: an icon in a circular Navy-Whisper badge, title + subtitle, generous padding, ambient navy glow at rest. On press it scales to 0.985 over 140ms and its shadow contracts (less blur, less offset, lower opacity) before returning on release — the system's main tactile signature, giving every primary shortcut a soft, responsive feel. Screen content also enters with a shared 420ms ease-out fade-and-rise (18px upward translate) on first load.

## Do's and Don'ts

### Do:
- **Do** reserve Golden Highlight (and its dark/soft variants) for details only — badges, prices, active tab, status pills (**The Amber-as-Detail Rule**).
- **Do** keep buttons at a fixed 54px height, flat (no elevation), relying on color and the Hairline Blue border for affordance.
- **Do** round every corner — nothing in this system uses a radius below 10px.
- **Do** give pressable cards the scale-down + shadow-contract micro-interaction on tap; it's the system's main tactile signature.

### Don't:
- **Don't** introduce hard black/gray drop shadows — depth in this system, where it appears at all, is a soft navy-tinted glow.
- **Don't** give amber a large background fill or make it the base color of a screen — it reads as an accent, not a structural color.
- **Don't** invent a second display/heading typeface — the whole hierarchy runs on Inter, differentiated by weight and size only.
