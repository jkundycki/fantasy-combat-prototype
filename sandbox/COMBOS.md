Current finisher rule: feint_startup_fraction=0.65 on Shield Slam and Greatsword Finisher. Special can feint from startup entry up to (but not including) 65% of startup; the final 35%, ACTIVE and RECOVERY are committed. This fraction scales with startup duration and overrides the older finisher windows listed below. Facing-lock timing remains independent. Standalone Heavy retains its .10–.28 s window.

# Combo, commitment and feint playtest

Inputs are unchanged: Primary LMB/X, Special E/RB, Defense Left Ctrl/LB,
RMB camera-facing, Q/Y weapon switch, Shift/B dodge, F3 debug.

## Primary buffering and reset

Each weapon has one PrimaryChain child holding three existing MeleeSwing nodes.
A Primary press during the final 65% of recovery buffers ONE next attack. The
buffer_recovery_fraction default is 0.35. Startup/active presses are rejected,
not retained. Repeated presses cannot queue multiple steps, shorten recovery,
skip an attack, or repeat a finisher. Full recovery always completes before the
next buffered startup. A new step captures the current intended facing normally.

Without a buffered press, the next step remains available for combo_timeout:
Sword & Shield 0.65 s; Greatsword 0.80 s, starting after recovery. Expiry or completing
step 3 returns to step 1. Defense cancels continuation but not the current attack;
Special, successful feint, dodge, weapon switch, death and interruption reset the
chain. Impact freeze pauses attack and chain time. A whiff can continue the chain;
no target lock or automatic facing assistance is added.

## Attack defaults

Each row has its own editable node in player.tscn. All times are seconds, reach
is meters, movement is a fraction of normal grounded speed. Hitbox height/center
remain editable too. Restart after changing geometry values.

| Attack node | Startup / active / recovery | Damage | Reach / arc | Movement | Stagger | Hit-stop |
| --- | --- | ---: | --- | ---: | ---: | ---: |
| SwordShield/Sword | .09 / .12 / .20 | 25 | 2.2 / 100Ã‚Â° | .55 | 0 | .035 |
| SwordShield/Reverse | .11 / .12 / .22 | 27 | 2.2 / 100Ã‚Â° | .55 | 0 | .035 |
| SwordShield/Slam | .42 / .12 / .42 | 30 | 1.65 / 75Ã‚Â° | .30 | .70 | .060 |
| SwordShield/Bash (Special) | .06 / .09 / .24 | 8 | 1.25 / 65Ã‚Â° | .65 | .20 | .045 |
| SwordShield/Feint | .07 / .08 / .32 | 5 | 1.1 / 55Ã‚Â° | .55 | .20 | .025 |
| Greatsword/Slash | .22 / .18 / .38 | 40 | 2.9 / 140Ã‚Â° | .40 | .30 | .055 |
| Greatsword/Reverse | .25 / .18 / .42 | 43 | 2.9 / 140Ã‚Â° | .35 | .35 | .055 |
| Greatsword/Finisher | .80 / .14 / .85 | 85 | 3.2 / 45Ã‚Â° | .15 | 1.15 | .085 |
| Greatsword/Heavy (Special) | .48 / .12 / .65 | 65 | 3.1 / 40Ã‚Â° | .20 | .95 | .075 |
| Greatsword/Feint | .08 / .08 / .38 | 4 | 1.05 / 50Ã‚Â° | .45 | .20 | .025 |

First swings and reverse swings have locked facing (turn_speed_degrees=0).
Reverse swings visibly rotate the opposite way. Sword & Shield's third Primary
is a wound-up shield slam, distinct from the much quicker, lower-damage Special.
Quick Special stagger was deliberately reduced from 0.65 to 0.20 s. It has no
reflect or guard-bypass property. The third slam is faster than the Greatsword
combo overhead, with more of its payoff in stagger rather than enormous damage.
Greatsword finisher is slower and stronger than standalone Heavy and more costly
on a miss. Heavy remains a separate practical punish instead of maximum payoff.

## Early turning, commitment, and feints

| Attack | Early turn rate | Commitment time after startup begins | Feint window |
| --- | ---: | ---: | --- |
| Shield Slam | 180Ã‚Â°/s | .28 s | [.10, .26) s |
| Greatsword standalone Heavy | 180Ã‚Â°/s | .30 s | [.10, .28) s |
| Greatsword combo Finisher | 240Ã‚Â°/s | .45 s | [.15, .42) s |

The weapon may rotate at the bounded rate toward player intended facing during
early startup. Holding RMB lets camera yaw supply that intended facing. At the
commitment_time cutoff, direction freezes for the rest of the attack. Active and
recovery phases never reopen turning on these attacks. Set turn_speed_degrees=0
for complete lock; commitment_time=-1 preserves the previous unrestricted-by-phase
turn-rate behavior for deliberate experiments. Default normal attacks have zero
turn rate. No target's position influences facing adjustment.

Press Special within a valid heavy/finisher window to branch into its weapon's
short bash. For standalone Greatsword Heavy, this means pressing Special again.
Before the window, at/after its end, and after commitment, presses do not cancel.
The branch cancels only that windup, clears the combo buffer and starts the bash's
own full startup/active/recovery. There is no free idle cancel, bash chaining or
bash-to-heavy loop. Bashes lock their direction on entry and do not track targets.

IncomingAttack has one guard_break flag. Feint bashes set it and disable ordinary
blockable/parryable flags. Both weapon defense resolvers treat it as HIT, even
inside perfect defense. It grants no auto-hit, stun immunity or anti-dodge bonus.
The short physical volume can miss with a sideways dodge or sufficient distance.
Normal damaging attacks are now explicitly blockable/parryable, making committed
windups punishable by appropriate defenses. A parry/interrupt clears the chain.

## Parry follow-ups and dodge

Existing defensive timings are preserved. Sword & Shield parry stagger is .85 s,
defender recovery .08 s: enough opportunity for a quick retaliation. Greatsword
parry stagger is .90 s, successful recovery .08 s. Standalone Heavy startup .48 s
fits promptly into the remaining opening (allowing for position and input time).
Reaching combo step 3 requires earlier full attacks/recoveries and is not guaranteed
by that single parry. Both retain their existing local parry hit-stop. Greatsword
still has no normal block or Spell Reflect; shield normal block never staggers.

Dodge mechanics are unchanged. An attacker cannot dodge-cancel committed swings
or recovery. A defender moves out of physical hitboxes using ordinary dodge and
spacing. Early camera-facing adjustments may follow an anticipated early dodge;
movement after direction locks may evade it. No artificial anti-dodge damage,
stamina, vulnerability or special dodge attacks exist.

## Accelerated directional reflection

SwordShield.spell_reflect_speed_multiplier defaults to 2.0. Fireball records
base_speed when spawned, then sets speed = base_speed * multiplier on reflect.
For the default 5 m/s fireball, reflected speed is 10 m/s. It never compounds its
current speed. The existing one-reflection collision behavior remains unchanged.
Direction is normalized -player.visual.global_basis.z captured at impact; ownership
transfers to the player. Enemy/world collision, self-collision exclusion, contact
offset and reflectable flag gating are preserved. Quick/feint bashes do not reflect.

## Debugging and comparison

F3 shows weapon, combo step, one-slot buffer, idle reset timer, phase, each current
attack's startup/active/recovery values, valid feint window, facing lock, guard-break
branch, event feedback, and enemy/player stagger timers. Existing hitbox, defensive
arc, health and projectile property feedback remains. Standalone Heavy shows its
own window rather than the Primary node's values.

For direct guard-matchup tests, set TestEnemy.test_guard_mode in the Inspector:
OFF (default unchanged behavior), BLOCK, or PARRY. This is a static testing fixture,
not new defensive AI or a timing model. Face the enemy toward the player and use
it to compare guarded ordinary attacks with feint bashes. Enemy parries interrupt
the attacker for .60 s; incoming stagger similarly interrupts a player if used.
These simple interruptions cancel combat while preserving gravity/momentum, and
suppress queued inputs. The dummy remains a pure damage/spacing target.

Start by comparing recovery lengths and buffer_recovery_fraction. Then tune
commitment_time alongside feint_window_start/end and early turn_speed_degrees.
Finally compare finisher range/stagger/damage, bash reach/whiff recovery, parry
stagger versus Heavy startup, and hit-stop (zero it for a mechanics-only comparison).
The defaults are experiments, not a final balance decision.

## Implementation scope

Created primary_chain.gd and tests/combo_test.gd. Changed both weapon scripts,
MeleeSwing, IncomingAttack, player.tscn, projectile base-speed scaling, debug,
optional enemy guard fixture, simple player interruption and relevant tests/docs.
Movement/camera/jump/air steering and dodge formulas are unchanged. Player only
gains combo-reset hooks and simple interruption handling required by test parries.
No classes, stamina, stats, loot, inventory, new weapons, guard meters, networking,
CC taxonomy, combo graph or general fighting-game framework was added.

Run with the local Godot console executable:

    Godot --headless --path <project-folder> --script res://tests/combo_test.gd --quit-after 3000

Existing movement, combat, defense, reflection and Greatsword checks remain.
Interactive playtesting is still needed to judge pressure and counterplay feel.