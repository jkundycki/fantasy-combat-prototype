Primary chains, finisher feints and 2x Spell Reflect are now implemented. See [COMBOS.md](COMBOS.md) for current timing values and controls; it supersedes earlier single-attack/combo-free notes below.

# Two-weapon playtest

Q / controller Y / Triangle toggles between Sword & Shield (default) and Greatsword.
Switching is for testing only: it requires idle combat, no held Defense, no impact
freeze, no attack/parry recovery, and no dodge/recovery. Requests are not queued.
The old set is reset and hidden; only the selected set receives input and ticks.
This prevents switching from cancelling a committed attack or recovery.

Universal inputs stay the same:
- Primary: Left Mouse / X / Square.
- Special: E / RB / R1.
- Defense: Left Ctrl / LB / L1. R is no longer Defense.
- RMB remains independent camera/facing control.
- F3 toggles the current weapon name, attack/parry states and hitboxes.

Player.weapon_set references one of two child components. The player routes
primary(), special(), defense(held), tick(), movement_scale() and defend() to that
component. It does not branch on weapon names for action behavior. Switching is a
small two-entry toggle, not inventory, equipment, persistence or a weapon registry.

sword_shield.gd continues to own quick sword, bash, sustained guard, perfect block,
melee parry and directional Spell Reflect. Its mechanics/tuning are unchanged.
greatsword.gd owns broad slash, overhead visuals, and a finite melee-only parry.
Both use melee_swing.gd for existing phase timing, forward fan hit detection,
committed direction, wall occlusion, single-hit deduplication and impact feedback.
No shared weapon base class or generalized ability framework is introduced.

## Greatsword attack defaults

Open sandbox/player.tscn and select Greatsword/Slash or Greatsword/Heavy.

| Parameter | Slash | Overhead Heavy |
| --- | ---: | ---: |
| startup_duration (s) | 0.22 | 0.48 |
| active_duration (s) | 0.18 | 0.12 |
| recovery_duration (s) | 0.38 | 0.65 |
| damage | 40 | 65 |
| reach (m) | 2.9 | 3.1 |
| arc_degrees | 140 | 40 |
| movement_multiplier | 0.4 | 0.2 |
| turn_speed_degrees (degrees/s; 0 locks facing) | 0 | 0 |
| stagger_duration (s) | 0.3 | 0.95 |
| hit_stop_duration (s) | 0.055 | 0.075 |

For comparison, Sword & Shield sword is 0.09/0.12/0.20 s, 25 damage, 2.2 m,
100 degrees, movement fraction 0.55, no stagger and 0.035 s hit-stop.
Greatsword's primitive blade is visibly thicker and longer. Primary rotates across
a broad arc; Special raises it overhead and chops down. Facing locks at the start
of startup by default, so camera turns do not automatically track the target.
Turn freedom is bounded by turn_speed_degrees if explicitly enabled for testing.
The overhead still uses a narrow forward fan prism, not precise blade simulation.
Targets can evade during windup; missing incurs the same substantial recovery.

Stagger is the simple existing enemy interruption timer, with stronger visual
recoil. No force-based knockback or crowd-control framework is added. Recoil
strength remains adjustable on TestEnemy. Shape height/center and all shared
MeleeSwing timing, damage, range, arc, movement and impact exports remain editable.
Restart after editing geometry settings because shapes are built at startup.

## Greatsword Defense defaults

Select Greatsword in player.tscn:
- parry_startup = 0.04 s: vulnerable windup.
- parry_window = 0.18 s: finite opportunity to negate parryable melee.
- parry_recovery = 0.30 s: recovery after an unused/missed attempt.
- successful_parry_recovery = 0.08 s: recovery after a successful parry.
- defensive_arc_degrees = 110: frontal coverage during the window.
- parry_stagger_duration = 0.90 s: enemy interruption/counter opportunity.
- parry_hit_stop = 0.055 s: brief local freeze; zero disables.
- parry_movement_multiplier = 0.65: grounded movement during the attempt/recovery.

Defense press starts PARRY_STARTUP -> PARRY_WINDOW -> RECOVERY -> DOWN. Holding
never repeats it and never becomes sustained block. Releasing does not cancel an
attempt or its recovery; release and press again after recovery for another attempt.
Appropriate frontal melee during the window returns PARRY and staggers the enemy.
A success consumes the window and enters shorter recovery, enabling a counter.
Before/after the window, or behind/outside the arc, incoming melee normally hits.
Defense recovery also blocks attacks, dodge and weapon switching.

The resolver explicitly requires impact.melee AND impact.parryable. All projectiles
return HIT, even blockable/reflectable Fireballs during the window. Greatsword has
no reflect outcome or persistent guard. The existing projectile code therefore
requires no weapon-specific branch. Sword & Shield still returns REFLECT and
redirects along character forward with player damage ownership.

## Compare by playtesting

Compare startup and recovery first, then reach/arc and movement/turn freedom.
For Heavy, compare damage/stagger payoff against the long narrow windup and whiff
recovery. For Defense, compare window/startup/missed recovery against held shield.
Zero hit-stop temporarily to judge contact mechanics separately from impact freeze.
These defaults are prototype starting points, not a recommended final balance.

Movement, jump, dodge, RMB facing, airborne momentum and projectile behavior were
preserved. The player gains only selection/routing; Sword & Shield gains a debug
text method, and shared melee gains configurable hit-feedback text.

Created: sandbox/greatsword.gd, this file, tests/greatsword_test.gd.
Changed: sandbox/player.gd, player.tscn, melee_swing.gd, sword_shield.gd,
movement_debug.gd, project.godot, reflection test's keyboard binding, prototype docs.

Run the new check with the Godot console executable:

    Godot --headless --path <project-folder> --script res://tests/greatsword_test.gd --quit-after 4000

Existing movement/combat/defense/reflection tests still target Sword & Shield by
default. No class, stamina, combos, loot, inventory, weapon stats, networking,
weapon factories or full equipment systems were introduced.