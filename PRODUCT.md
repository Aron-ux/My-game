# Product Context

## Register

Product UI for a desktop three-role survivors-like game.

## Users

Players who pause combat to compare the swordsman, gunner, and mage, then inspect the build they have actually assembled during the current run.

## Purpose

The interface must answer four questions quickly:

1. What are this role's live combat stats and equipment?
2. Which blessings are currently owned and what do they do?
3. Which ordinary upgrades are active on each of the role's six skill records?
4. Which player-level role talents are active and which alternatives did they lock?

The current panel does not yet answer question four. Until that ledger is implemented, talent ownership is visible only in the selection flow and runtime/save state.

## Personality

Tactical, weighty, readable, and restrained. The visual metaphor is a dark-gold build archive: dense enough for experienced players, but organized like a dependable tool rather than a decorative fantasy book.

## Anti-references

- Generic mobile-RPG clutter with badges, bars, currencies, and repeated lock icons.
- Blue SaaS dashboards that ignore the game's combat identity.
- Fantasy parchment overload, realistic book textures, and ornate metal framing.
- Tiny card grids or raw debug-text lists that force players to decode the build.

## Accessibility

- Keep body text readable at the supported 1280×720 baseline.
- Never use color as the only state signal; pair it with labels, borders, or symbols.
- Preserve keyboard focus, `C`/`Esc` close behavior, and standard scrolling.
- Keep important information visible without requiring hover.
