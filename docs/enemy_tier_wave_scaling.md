# N1-N5 enemy and Boss scaling

Ordinary enemies, elites and summons use their authored defaults, the selected N-tier's initial multipliers, and the wave when they appear. Small and final Bosses receive the N-tier initial health and attack multipliers, but never receive per-wave stat growth. N6 and higher are not redefined.

| Tier | Initial HP | Initial attack | HP per wave | Speed per wave | Flat attack per wave | DR every 5 waves |
|---|---:|---:|---:|---:|---:|---:|
| N1 | 0.8 | 0.8 | 0 | 0 | 0 | 0 |
| N2 | 1 | 1 | 15% | 0 | 0 | 0 |
| N3 | 2 | 1.5 | 20% | 1% | 0 | 0 |
| N4 | 2.5 | 2 | 20% | 1.5% | 1.5 | 0 |
| N5 | 2.5 | 2.5 | 25% | 2% | 2 | 5% |

For non-Boss wave w, growth has w-1 steps. HP and movement speed compound. Attack = default attack * initial multiplier + flat growth * (w-1). Initial speed uses its default value. N5 DR = default DR + floor(w/5)*0.05, capped at 100%. Bosses use the table's initial HP and attack multipliers with zero growth steps at every wave; their speed and damage reduction remain at authored values.

For N1-N5, these rules replace the global HP x2.04, old wave HP curve, old tier stat multipliers, tier attack-interval/projectile-count changes and tier projectile speed bonuses. Skills keep their authored attack coefficients and unique passives: shotgun damage is 200% attack; Stalwart Body normally deals 150%. Independent projectile damage preserves its authored ratio to attack, without the legacy generic projectile damage x2.

First appearance at wave 10 gives non-Boss enemies all nine growth steps. A seed and a hatching young tree recompute from their own templates and current wave, never from multiplied parent stats. Skulltomb summons use the ordinary spawn path. Rose minions have no separate HP/movement template; their bullet attack uses the owner's authored attack coefficient and current non-Boss scaling, not the Boss runtime attack.

Without a wave flow (developer mode), non-Bosses use wave 1. Save restoration preserves saved attributes and does not apply scaling twice. N1-N5 are resolved in enemy_tier_wave_scaling.gd; legacy difficulty profile values remain for unspecified higher tiers.

Validation: enemy_tier_wave_scaling_smoke.gd covers all 100 non-Boss tier/wave combinations, actual shotgun projectile damage, elite scaling, seed/hatch scaling, additive DR, Boss initial multipliers across all tiers and waves, developer initial stats and save restoration.
