---
name: My Game
description: A tactical dark-gold build archive for a three-role survivors-like game.
colors:
  archive-backdrop: "#000000B8"
  archive-bg: "#0B0D14FA"
  archive-bg-soft: "#131621F5"
  archive-card: "#1C202EFA"
  archive-card-alt: "#161A26FA"
  archive-border: "#5C6B94E6"
  archive-gold: "#FFC23D"
  text-primary: "#F2F7FFFF"
  text-muted: "#C7D4F0F0"
  text-gold: "#FFE070FF"
  state-good: "#6BFF94FF"
  state-danger: "#D62E2EF5"
typography:
  headline:
    fontFamily: "Godot UI Default, sans-serif"
    fontSize: "28px"
    fontWeight: 600
    lineHeight: 1.2
  title:
    fontFamily: "Godot UI Default, sans-serif"
    fontSize: "21px"
    fontWeight: 600
    lineHeight: 1.25
  body:
    fontFamily: "Godot UI Default, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "Godot UI Default, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.3
rounded:
  compact: "8px"
  control: "10px"
  card: "12px"
  modal: "16px"
spacing:
  xs: "6px"
  sm: "8px"
  md: "10px"
  lg: "12px"
  xl: "16px"
components:
  archive-panel:
    backgroundColor: "{colors.archive-bg}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.modal}"
    padding: "{spacing.xl}"
  archive-card:
    backgroundColor: "{colors.archive-card}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.card}"
    padding: "{spacing.sm}"
  archive-tab-selected:
    backgroundColor: "{colors.archive-card-alt}"
    textColor: "{colors.text-gold}"
    rounded: "{rounded.control}"
    height: "42px"
---

# Design System: My Game

## Overview

**Creative North Star: "The Tactical Build Archive"**

The interface is a dependable combat tool presented as a dark-gold archive. Near-black navy surfaces keep dense build information calm; thin amber borders establish hierarchy; green is reserved for effects that are already active. Ornament supports the frame but never competes with the player's numbers, equipment, blessings, or skill build.

The system rejects generic mobile-RPG clutter, blue SaaS dashboards, fantasy parchment overload, and tiny card grids or raw debug-text lists. Standard tabs, lists, buttons, and scrolling should disappear into the task.

**Key Characteristics:**
- Three stable information zones: team, role record, build record.
- Compact, fixed typography with explicit empty and locked states.
- Selection is shown by border, surface, and text together.
- Supported desktop layouts start at 1280×720.

## Colors

The palette is restrained navy-black with a scarce amber-gold accent and semantic green/red states.

### Primary
- **Archive Gold** (`#FFC23D`): selected tabs, primary frame borders, and decisive values.
- **Text Gold** (`#FFE070`): section titles and selected labels.

### Secondary
- **State Good** (`#6BFF94`): an effect, role, or mutation that is currently active.
- **State Danger** (`#D62E2E`): unavailable or harmful states that require attention.

### Neutral
- **Archive Background** (`#0B0D14`): modal and deep workspace surfaces.
- **Archive Soft Background** (`#131621`): controls and secondary panels.
- **Archive Card** (`#1C202E`): list rows and information cards.
- **Archive Border** (`#5C6B94`): inactive boundaries and dividers.
- **Primary Text** (`#F2F7FF`): names and values.
- **Muted Text** (`#C7D4F0`): explanations, hints, and unavailable content.

**The Scarce Gold Rule.** Gold marks current selection, completion, or the screen's structural frame; it is not filler decoration.

## Typography

**Display Font:** Godot UI Default
**Body Font:** Godot UI Default
**Label/Mono Font:** Godot UI Default

**Character:** One familiar sans-serif family carries the entire product surface. Hierarchy comes from size, weight, and spacing rather than decorative typefaces.

### Hierarchy
- **Headline** (600, 28px, 1.2): modal titles only.
- **Title** (600, 21px, 1.25): section headings.
- **Body** (400, 15px, 1.4): skill, blessing, stat, and equipment content.
- **Label** (400, 12px, 1.3): scope, shortcut, count, and secondary-state labels.

**The Baseline Rule.** Core build information must remain legible at 1280×720; do not solve density by shrinking body text below 12px.

## Elevation

Depth is structural: nested navy surfaces, thin borders, and modest dark shadows separate the archive, sections, and rows. Surfaces remain visually flat at rest; hover and focus may lighten the existing surface but do not float cards dramatically.

### Shadow Vocabulary
- **Card Separation** (5–8px dark shadow): dense archive cards and sections.
- **Modal Separation** (14px dark shadow): the outer character-panel frame only.

**The Layer-Only Rule.** Shadows clarify nesting; they never decorate ordinary text or inactive controls.

## Components

### Buttons
- **Shape:** restrained rounded rectangle (10–12px).
- **Primary:** archive-soft surface, gold border/text, at least 40px high.
- **Hover / Focus:** lighten the same surface; focus uses a visible gold outline.
- **Secondary:** navy card surface with neutral blue-gray border.

### Chips
- **Style:** compact inline tier tokens such as `I×3 · II×1`; separators keep the ledger scannable without adding another row of controls.
- **State:** owned tiers are written explicitly; inactive future talent nodes use muted text and an open-circle symbol.

### Cards / Containers
- **Corner Style:** 12px for rows/cards; 16px for the main modal.
- **Background:** archive card over archive background.
- **Shadow Strategy:** structural only, following Elevation.
- **Border:** one pixel by default, two pixels for selected/current state.
- **Internal Padding:** 8–12px.

### Inputs / Fields
- **Style:** standard Godot controls on the archive-soft surface.
- **Focus:** visible gold border with no decorative animation.
- **Error / Disabled:** explicit text and muted/danger color; never color alone.

### Navigation
- Tabs live at the top of the right-hand build workspace. Default, hover, focus, selected, and disabled states reuse the same archive-card vocabulary. `C` and `Esc` close the panel; standard scrolling remains available.

### Skill Build Record

Each role keeps a six-skill selector beside one focused talent tree. Hover, focus, or click selects a skill; the detail pane shows three fixed left/right stages, the current path, and owned repeatable build upgrades below the tree. Only real talent definitions may appear: unavailable stages stay visibly locked instead of inventing thresholds or effects.

### Blessing Ledger

Blessings are grouped into team-shared role blessings and skill-bound blessings that affect matching skill types. Each row shows the owned I–IV tier counts and the strongest current effect; expansion reveals all owned-tier effects and recipe relevance.

## Do's and Don'ts

### Do:
- **Do** preserve the three-zone team / role / build layout.
- **Do** use explicit labels, borders, and symbols alongside state colors.
- **Do** teach from empty states, such as where a build or blessing will come from.
- **Do** keep core information visible without hover and preserve keyboard focus.

### Don't:
- **Don't** recreate generic mobile-RPG clutter with badges, bars, currencies, and repeated lock icons.
- **Don't** turn the interface into a blue SaaS dashboard that ignores the game's combat identity.
- **Don't** add fantasy parchment overload, realistic book textures, or ornate metal framing.
- **Don't** use tiny card grids or raw debug-text lists that force players to decode the build.
- **Don't** add star maps, cross-panel connector lines, or decorative motion for fixed talent choices.
