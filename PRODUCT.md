# Product Context

## Register

Product UI for a desktop three-role survivors-like game.

## Users

Players who pause combat to compare the three selected roles from the swordsman, gunner, mage, and mechanic roster, then inspect the build they have actually assembled during the current run.

## Purpose

The interface must answer four questions quickly:

1. What are this role's live combat stats and equipment?
2. Which blessings are currently owned and what do they do?
3. What do this role's skills currently do, and what will the next level change?
4. Which saved role talents are actually owned and what effects do they provide?

The character sheet opens on an eleven-stat overview with a fixed source inspector. Skills, blessings, and equipment share the same team / list / detail structure. Saved `level_talents` appear as a read-only list; their disabled acquisition flow stays disabled. Placeholder effects are explicitly labeled.

Mechanic skill talents use the current level-5 choice and level-10 completion route. Its eight skill lines show 16 named effects with owned/pending status, while other roles' unimplemented slots remain labeled as placeholders. Runtime values and talent descriptions must agree across reward cards, combat hover and the character sheet.

The camp supports one preparation loop: inspect permanent gains and carried items, choose and order the next three-role team, then review the loadout before selecting or continuing an N tier. All four roster members, including mechanic, have camp representation and useful role information. Permanent purchases survive return to camp; transactions only appear as complete after the save succeeds.

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
