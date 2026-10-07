# Imperfect sparring bot

F5 launches the arena with the existing enemy now using sparring_bot.gd.
Player inputs and weapon behavior are unchanged.
- F3 toggles combat/AI debug.
- F4 cycles BALANCED, TURTLE, PARRY_HAPPY, SLIPPERY, AGGRESSIVE.
- F6 toggles sparring versus the original melee/fireball tester, only while idle
  or approaching. Active defenses, attacks, recovery and stagger cannot be cancelled.
- Select TestEnemy in arena.tscn for all bot exports.

## Perception and reaction

The bot observes only a player melee swing already in STARTUP or ACTIVE, within
perception_range, perception_arc and an unobstructed world-geometry sight ray.
It does not read Input, combo buffers, next combo attacks, damage, feint eligibility,
commitment time or future hit timing. MeleeSwing's new attack_serial increments
when a swing visibly begins; together with node ID it prevents repeatedly reacting
to the same swing. Each new combo step/feint is a new visible action, but the bot
will only notice it when free to make another decision.

An observed action starts REACT. The bot waits reaction_delay plus random jitter,
then draws one response from its weights. It does not cancel the read if the player
stops, misses or feints while it is waiting. It can defend too late or against a
threat that is no longer there. It does not scan for better responses during a
committed decision, its recovery, offense or stagger.

## Responses

BLOCK holds its current facing and frontal guard for block_duration. Blockable
contacts are stopped without staggering the attacker. Guard-break attacks bypass
it, as do attacks outside defensive_arc_degrees.

PARRY_ATTEMPT waits an additional independent prediction delay plus jitter, then
opens PARRY_WINDOW for parry_window seconds. This guess is not calculated from the
player's attack durations. Only actual parryable melee contact during that finite
window succeeds. Before/after it, attacks hit normally. A miss incurs exposed
recovery. Success staggers the player and briefly freezes impact before recovery.
Neither block nor parry rotates to track a committed player swing.

DODGE commits to one lateral or backward vector and moves through move_and_slide.
It has no invulnerability or special anti-hit rule. Distance, walls and direction
can make it effective or ineffective. It can happen early enough for the player's
own early facing adjustment to follow it; late repositioning may escape committed
facing. Close, well-spaced attacks can still hit it.

GREED starts the existing telegraphed melee swing, potentially into a whiff or an
incoming attack. Its direction remains locked exactly as before. Idle offense is
also this one melee: the bot slowly approaches, faces at a limited rate, and attacks
on the inherited cooldown. No offensive combos or bot feints were added.

Block, attempt, window and dodge all enter recovery. A player finisher changed to
a feint bash cannot cause the bot to undo its earlier choice. Existing guard-break
properties defeat block/parry on physical contact. Dodge-created distance can make
the short bash miss. Stagger interrupts the bot and clears pending reaction/decision
timers; it cannot escape the player's punish window by choosing defense.

## Personality presets

| Preset | Block | Parry | Dodge | Greed |
| --- | ---: | ---: | ---: | ---: |
| BALANCED | 3 | 2 | 2 | 3 |
| TURTLE | 7 | 1 | 1 | 1 |
| PARRY_HAPPY | 1 | 7 | 1 | 1 |
| SLIPPERY | 1 | 1 | 7 | 1 |
| AGGRESSIVE | 1 | 1 | 1 | 7 |

They only alter weights. AGGRESSIVE challenges more often through Greed; no hidden
attack-speed or skill bonuses apply. Choose CUSTOM to retain Inspector-entered
weights at startup. Presets populate their weights when selected; afterward live
weight changes are usable until another preset is selected. All-zero weights fall
back to Greed. Negative weights are clamped out of the decision draw.

## Starting defaults to tune

Perception:
- perception_range = 4 m; perception_arc = 240 degrees.
- reaction_delay = .28 s; reaction_jitter = .07 s (normally .21–.35 s wait).
- turning_speed_degrees = 180 degrees/s outside committed actions.

Defense and recovery:
- block_duration = .50 s; defensive_arc_degrees = 120 degrees.
- parry_prediction_delay = .10 s; parry_prediction_jitter = .10 s.
- parry_window = .18 s; missed_parry_recovery = .40 s.
- defensive_recovery = .28 s after guard or successful parry.
- parry_attacker_stagger = .60 s; parry_hit_stop = .035 s.

Dodge:
- dodge_speed = 9 m/s; dodge_duration = .20 s.
- backward_dodge_chance = .35; otherwise choose either lateral direction.
- dodge_recovery = .30 s.

Inherited offense/feedback:
- move_speed = 1.5 m/s; attack_interval = 1.4 s.
- melee startup/active/recovery = .80/.16/1.0 s.
- existing melee reach, arc, height, damage, flash, recoil, reset and health exports
  remain tunable. Original projectile exports work in the F6 original-test mode.

random_seed = 0 randomizes playtests; a nonzero seed makes weighted rolls repeatable
for the same sequence of perceptions. ai_enabled=false still disables autonomous
behavior and retains the original enemy's manual test hooks.

Start with personality/weights and reaction delay, then parry prediction/window,
then defensive recovery and dodge displacement. Keep enough recovery to see wrong
reads punished. None of these defaults is a final balance recommendation.

## Debug and scope

The existing HUD now adds AI state, chosen decision, reaction/decision timer,
personality, parry-window flag, fixed dodge direction, weights and existing stagger
countdown. Guard is blue, parry preparation purple, actual parry window cyan, dodge
green; original startup/stagger/hit colors remain.

Created sparring_bot.gd, this document and tests/sparring_test.gd. Changed arena.tscn
to extend the original enemy, InputMap for development toggles, debug display, and
MeleeSwing with a visible attack-instance counter. No player movement, camera,
weapon timings, combo/feint logic, defense, reflection or projectile formulas changed.
Original test_enemy.gd still owns melee geometry, damage, recoil, reset and stagger.
The static guard fixture is ignored in active sparring mode; disable sparring/AI to
use that fixture for isolated mechanical checks.

No behavior tree, pathfinding/navigation system, predictive hit solver, counter
lookup, guard/stamina resources, offensive AI chains, new player weapons/abilities,
classes, networking or learned AI were introduced. The bot uses direct approach
movement and can get blocked by arena geometry. That is intentional for this lab.

Run:

    Godot --headless --path <project-folder> --script res://tests/sparring_test.gd --quit-after 3000

Existing movement/combat/defense/reflection/Greatsword/combo tests also remain.
Mechanical checks cannot decide whether its imperfect decisions feel human;
interactive playtesting is still needed.