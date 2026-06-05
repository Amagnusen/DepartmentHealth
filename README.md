# ClearPath OS — Daily Performance Management Module

Daily Performance Management (Day-By-The-Hour station health) module for **ClearPath OS**,
endorsed by Spectrum Killian. Tracks hourly target-vs-actual production, WIP, top operators,
and hot-list cases per business unit and station. The dashboard is a fixed **1920×1080**
"wall display" canvas that scales to fit the viewport, so on-screen type is intentionally
larger than the base design-system scale.

## Branding

Follows the **ClearPath OS Design System** and the standard module **HEADER-SPEC**
(see `../ClearPath-Header-Kit`). Logos live in `logos/`. Light theme.

### Header (two bars)

- **Upper bar** — fixed ClearPath lockup + "Operating System" (Lab Gold) on the left,
  the module title **"Daily Performance Management Module"** centered at true page center
  with a small **"Tier 1"** label near the bottom, and the Spectrum Killian endorsement
  on the right.
- **Subheader** — station picker (e.g. "Case Entry") on the left, the **BU tabs**
  (FA · C&B · REM-A · REM-P) centered on the page, and **Metrics | Out of Hours** on the
  right with the live "Updated …" status pinned to the bottom-right corner.
  - BU tabs: medium gray `#8B929E`, weight 600; the selected unit is navy (Spectrum Blue).

## Color palette

**Brand:** Spectrum Blue `#052030` · Killian Blue `#1882C7` · Dental Blue `#4ABEEE` ·
Lab Gold `#B3A369` · Alliance Blue `#C3E8FA` · Solutions Silver `#B0B7C3`.

**UI tokens (light):**

| Token | Value |
|---|---|
| app bg | `#eef3f8` |
| panel / card | `#ffffff` |
| line | `#dde6ee` |
| line-2 / header divider | `#c6d4e0` |
| text | `#0e2433` |
| text-2 | `#41566a` |
| text-3 / muted | `#7e8ea0` |
| accent (interactive) | `#1882C7` |

**Status:** meets / positive green `#1E9E6A` · miss / constraint red `#D6453B`
(light bg tint `#fbeceb`) · queued = Lab Gold `#B3A369` · active = Killian `#1882C7`.

## Typography

- **Montserrat** — all UI, headings, numbers, labels (variable axis `300..800`).
- **Lora** (serif) — body copy / descriptive sub-text only.
- **Panel/card headings** (Today's Count, Top Operators, Hot List): dark text on the white
  panel with a **2px Lab-Gold underline**, per spec.
- Type sizes are scaled up from the base design-system scale for the 1920×1080 wall display.
