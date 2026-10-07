Primary chains, finisher feints and 2x Spell Reflect are now implemented. See [COMBOS.md](COMBOS.md) for current timing values and controls; it supersedes earlier single-attack/combo-free notes below.

Two weapon sets are now available: Q/Y/Triangle switches. Defense is Left Ctrl/LB/L1. See [GREATSWORD.md](GREATSWORD.md) for selection and comparison tuning.

# Sword & Shield laboratory

Open project.godot and press F5. The brown stationary capsule is a spacing dummy.
The red capsule is a minimal enemy: gold signals attack startup, blue signals
stagger. It alternates actions based on distance, with long delays. Dead targets
and the player reset automatically so testing can continue.

## Controls and routing

| InputMap action | Keyboard/mouse | Controller |
| --- | --- | --- |
| move_* | WASD | Left stick |
| look_* | Mouse (also handled directly for motion) | Right stick |
| jump | Space | A / Cross |
| mobility | Left Shift | B / Circle |
| primary | Left Mouse | X / Square |
| special | E | RB / R1 |
| camera_facing | Hold Right Mouse | Existing right-stick look |
| defense | Hold Left Ctrl | Hold LB / L1 |
| combat_debug | F3 | Bind as desired in InputMap |

Escape releases the mouse; the next primary mouse click only recaptures it.
Sprint is removed: holding mobility neither sprints nor repeats dodge.

The player routes primary/special presses and defense hold/release to its
SwordShield child. Movement, jump, facing and dodge remain in player.gd.
SwordShield owns what those three inputs do, guard timing, impacts and the
primitive sword/shield visuals. It has two MeleeSwing children, Sword and Bash.
There is no class layer, equipment registry, inventory or weapon-swap system.
Future weapon components can implement the same small primary/special/defense,
tick, busy, movement_scale and defend interface when they are actually needed.

## Sword and bash

Each press starts exactly one committed STARTUP -> ACTIVE -> RECOVERY sequence.
No automatic repeat, input queue or combos. Both actions are mutually exclusive.
Dodge is rejected during committed attacks; attacks are rejected during dodge and
mobility recovery. Jump remains available without bonus damage or invulnerability.

Facing is captured when an attack begins. turn_speed_degrees defaults to zero:
movement can change without freely rotating the swing. Raising it permits bounded
turning toward intended facing, in degrees/second. Attack movement multipliers
change grounded target speed; ordinary acceleration/braking still applies. Airborne
launch momentum is retained rather than scaled down when beginning an attack.

Both hitboxes are convex fan prisms, centered in front of the committed facing.
During ACTIVE, a Godot shape query overlaps Area3D hurtboxes on physics layer 2.
The exact query shape is the debug wireframe. Target radius naturally allows slight
edge overlap. Vertical separation, range and facing can all cause misses. A ray
against arena geometry blocks strikes through walls. Hurtbox instance IDs prevent
repeated damage to the same target during one swing.

Sword is chiefly damage. Bash is shorter, narrower and lower damage; it applies a
simple stagger timer that interrupts the test enemy's startup or active action.
Enemy stagger stops movement and attacks, recoils its visual, and then returns it
to IDLE. There is no resistance, immunity buildup or crowd-control framework.
The stationary dummy deliberately only demonstrates damage/flash/recoil/reset.
Hitboxes cover their whole arc throughout active frames, not exact blade sweeps.

## Shield, perfect timing and incoming properties

Holding defense raises the shield when the weapon is idle and not dodging. Release
lowers it immediately, including during hit-stop. The optional block_startup is
vulnerable RAISING time. PERFECT BLOCK follows for perfect_block_duration, then
becomes ordinary BLOCK while held. Holding does not continually refresh the window.
After an attack/dodge ends, a still-held defense raises the shield anew; that new
raise has a fresh window. Set perfect_block_duration to zero to disable it.

IncomingAttack is a small Resource with damage, melee, blockable, parryable,
reflectable, stagger_duration and hit_stop. All capability flags default false.
They are independent: being a spell/projectile does not imply reflectability.
The shield compares the horizontal direction toward the incoming origin with the
player's actual facing. Outside half the defensive arc, the attack hits normally.
Jump and dodge have no special damage immunity; incoming attacks use geometry and
shield coverage. The enemy's tall melee volume covers ordinary jump height so jump
is not an intentional substitute for defense.

| In the frontal shield arc | Result |
| --- | --- |
| Normal guard + blockable attack | BLOCK; configured damage fraction; attacker does not stagger |
| Perfect guard + melee/parryable | PARRY; no damage; attacker stagger/recoil |
| Perfect guard + non-melee/reflectable | SPELL REFLECT; no damage; returned projectile |
| Perfect guard but incompatible special flags | Ordinary BLOCK if blockable, otherwise HIT |
| Behind/outside arc, shield down/raising, committed attack or dodge | HIT |

blocked(outcome, impact, attacker) is emitted after successful defense. This is the
single future attachment point for guard costs; no stamina or guard-break exists.
Defender recovery briefly gates attacking after a defense success. Parry stagger
is longer than that recovery so a counter opportunity exists without a special
counterattack or damage bonus.

## Enemy and fireball

TestEnemy approaches slowly in IDLE, faces the player, and starts melee nearby or
fireball at distance. Melee locks its yaw at startup and queries its visible forward
volume during active frames. Moving out of that volume causes a miss. Parry/bash
stagger cancels the attack; normal block does not cancel or stagger the enemy.
The enemy aims the fireball at the player's position when startup begins, not by
tracking after launch. The fireball moves physically and sweeps each traveled
segment against world/player bodies, avoiding tunneling. It is ray-based rather
than a radius sweep; the visual ball is intentionally small.

Fireball defaults blockable=true, parryable=false, reflectable=true. Ordinary block
dissipates it. Perfect guard changes its color to cyan and points its velocity once along the
player's character forward vector: normalized -player.visual.global_basis.z.
It assigns damage ownership to that player and then collides with enemy bodies
and world geometry, ignoring the player/shield. The original shooter or any other
enemy may be hit only if physically in its path. It never targets an entity.
reflection_offset (0.05 m) moves it slightly beyond its contact point. The frontal
defensive arc still governs eligibility; timing alone does not reflect side/rear hits. Shots aimed away
from the player, or blocked by walls, miss. Unreflectable/unblockable properties
are supported without inventing future spell types.

## Air momentum and facing

Ground movement still uses current camera yaw. On takeoff (or walking off a ledge),
the last grounded camera yaw becomes air_reference_yaw. Air steering uses that
fixed reference until landing; current camera yaw controls airborne facing.
Horizontal velocity is never rotated when the camera turns. Thus jump forward,
turn 180 degrees, attack backward, turn forward can retain forward trajectory,
even while forward movement input is held. Explicit strafe/back input can steer
with modest air_acceleration. Airborne attacks use ordinary timing and damage.
No jump i-frames, special avoidance, bonus attacks or ranged player attacks exist.
Right-stick look was added so this facing behavior is also testable on controller.

## Tunable prototype defaults

Open sandbox/player.tscn and select SwordShield/Sword or SwordShield/Bash. Select
SwordShield for defense, Player for movement, and TestEnemy in arena.tscn for enemy
settings. Inspector overrides take precedence over script defaults.

| Value | Sword | Bash |
| --- | ---: | ---: |
| startup_duration (s) | 0.09 | 0.06 |
| active_duration (s) | 0.12 | 0.09 |
| recovery_duration (s) | 0.20 | 0.24 |
| damage | 25 | 8 |
| reach (m) | 2.2 | 1.25 |
| arc_degrees (total) | 100 | 65 |
| movement_multiplier (ground speed fraction) | 0.55 | 0.65 |
| turn_speed_degrees (degrees/s; 0 locks) | 0 | 0 |
| stagger_duration (s) | 0 | 0.65 |
| hit_stop_duration (s; 0 disables) | 0.035 | 0.045 |
| hitbox_height / hitbox_center_height (m) | 1 / 1 | 1 / 1 |

SwordShield:
- defensive_arc_degrees = 120: total horizontal frontal coverage.
- block_startup = 0 s: time before defense begins working.
- perfect_block_duration = 0.16 s: perfect window after startup; zero disables.
- parry_stagger_duration = 0.85 s: attacker interruption after a melee parry.
- defender_recovery = 0.08 s: delay before an offensive action after defense.
- parry_hit_stop = 0.045 s: local impact freeze for parry/reflect; zero disables.
- block_hit_stop = 0.015 s: local freeze for normal block; zero disables.
- blocked_damage_multiplier = 0: fraction received on ordinary block, from 0 to 1.
- defense_movement_multiplier = 0.7: grounded speed while shield is raised.

TestEnemy:
- move_speed = 1.5 m/s; attack_interval = 1.4 s between actions.
- melee_startup/active/recovery = 0.8/0.16/1.0 s.
- melee_range = 2.1 m; melee_arc = 90 degrees; melee_height = 2.8 m.
- melee_damage = 14.
- fireball_startup/recovery = 0.9/1.1 s; projectile_speed = 5 m/s.
- projectile_damage = 12; projectile_blockable/reflectable = true.
- max_health = 100; reset_delay = 1 s; ai_enabled disables automatic decisions.
- flash_duration = 0.09 s, hit_recoil_distance = 0.1 m,
  stagger_recoil_distance = 0.3 m, recoil_return_speed = 1.5 m/s.

Player:
- move_speed = 9 m/s, ground_acceleration/deceleration/turn = 180/220/360 m/sÃƒâ€šÃ‚Â².
- air_acceleration = 6 m/sÃƒâ€šÃ‚Â² (reduced from 28); air_deceleration = 0.
- jump_speed = 10 m/s; gravity = 28 m/sÃƒâ€šÃ‚Â²; falling multiplier = 1.35.
- jump_release_multiplier = 0.5; coyote_time = 0.08 s; jump buffer = 0.1 s.
- dodge speed/duration/cooldown/recovery = 18 m/s, 0.16/0.35/0 s.
- max_health = 100; reset_delay = 1 s (testing only).

Fireball lifetime is 8 s; speed is inherited from the enemy when spawned.
TrainingDummy retains configurable health, flash, visual recoil and reset delay.
Geometry is built at startup: restart after changing ranges/arcs/heights.
Hit-stop is local to the player/weapon and hit target, not global time scale;
mouse/right-stick camera and HUD remain responsive. Impact feedback values can
be zeroed individually. No camera-shake, particles or audio framework was added.

## Files and checks

Created: incoming_attack.gd, melee_swing.gd, sword_shield.gd, test_enemy.gd,
enemy_hurtbox.gd, fireball.gd, tests/defense_test.gd.
Changed: player.gd, player.tscn, arena.tscn, camera_rig.gd, training_dummy.gd,
movement_debug.gd, project.godot, combat/movement tests and prototype docs.
Removed: obsolete warrior_attack.gd and its UID, along with sprint fields,
logic and old action names.

Run each check with the local Godot console executable:

    Godot --headless --path <project-folder> --script res://tests/movement_test.gd --quit-after 3000
    Godot --headless --path <project-folder> --script res://tests/combat_test.gd --quit-after 3000
    Godot --headless --path <project-folder> --script res://tests/defense_test.gd --quit-after 4000

The tests verify mechanics and regressions; final feel and timing need interactive
playtesting. Defaults are starting points, not a final balance recommendation.
RMB now provides camera-facing independently of the Left Ctrl defense action. Captured
mouse look, guarded facing, melee commitment and air momentum behavior are preserved.
