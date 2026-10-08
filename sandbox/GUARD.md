# Health, damage numbers and shield Guard

## Playtest

Open project.godot and F5. Red player health and green Guard/Stamina are in the
lower-left; the opponent's name/weapon, red HP, green Guard and state follow
its head in screen space. F3 only toggles detailed diagnostics/hitboxes.
Greatsword hides its Guard bar and keeps a finite parry rather than Block.

Press **F7** to toggle **ALWAYS_BLOCK** on the default Sword & Shield opponent.
The Inspector equivalent is TestEnemy.training_mode = ALWAYS_BLOCK and
opponent_weapon = SWORD & SHIELD. F4 personalities and F6 projectile testing
remain available. ALWAYS_BLOCK continuously faces the player at its existing
bounded turning rate, holds Block without idle drain, and pauses regeneration.
It cannot defend or attack during Guard Break.

Use Q / Y (Triangle) to select Greatsword. Repeated Light attacks deplete the
shield; each swing still contacts it at most once. After Guard Break, manually
aim and use E / RT (R2) for Heavy. Wrong range/facing can still miss.
Bash is F / RB (R1): it bypasses eligible guard instead of draining the meter.

## Parameters

Player: Player > SwordShield > Guard.
Opponent: TestEnemy > Guard. These are instances of the same small component.

| Parameter | Default | Meaning |
| --- | ---: | --- |
| max_guard | 100 | Capacity |
| starting_guard | 100 | Initial/death-reset amount, capped by capacity |
| regeneration_rate | 25/s | Regeneration when not holding shield |
| regeneration_delay | 1.25 s | Time after the last Guard-damaging block |
| break_stun_duration | 1.60 s | Fixed full action/movement lockout |
| post_break_guard_fraction | 0.30 | Partial Guard restored at stun end |
| post_break_immunity | 0.75 s | Cannot trigger another break during this window |

Parry/Reflect Guard cost is **zero**. No movement, jump, dodge, attack, feint,
or switch costs. Switching weapons preserves the shield's existing resource;
it does not refill Guard. The dormant shield can recover while not held.

Per-attack guard_damage is independent of damage (HP):
- Light 1 / Light 2: 15.
- Light 3: 25.
- Both Heavy moves: 40.
- Bash / feint-bash: 0; bypass remains unchanged.
Opponent melee_guard_damage and projectile_guard_damage both default to 15.

A normal frontal eligible block retains blocked_damage_multiplier (default
zero HP damage) and subtracts Guard. The hit that exhausts Guard retains
ordinary blocked HP rules; subsequent hits strike the exposed defender.
Perfect parries and successful Spell Reflect do not touch Guard or its delay.
Reflect retains facing direction, ownership and the existing 2x speed.

## Break and recovery

At zero Guard, the resource emits broken. The actor cancels its offense,
drops defense, clears queued movement actions and enters GUARD BREAK.
Horizontal movement and all gameplay actions (including switching) are
locked; gravity still applies. Look/camera input remains available.
The distinct slump pose and text use the actual resource stun timer.

The timer runs independently of ordinary hit-stop and stagger. HP hits
during the break cannot refresh it or queue extra stagger for its end.
On recovery, control returns, Guard restores to 30% and its regeneration
delay clears. During the brief post-break protection, blocks may drain Guard
down to one point but cannot create another break. This is break protection,
not HP immunity. Holding Block still pauses further regeneration.
Player defense is released by the break; raise it again afterward.
ALWAYS_BLOCK resumes its held shield after recovery.

Current Heavy phase seconds:
- SwordShield shield slam: 0.42 startup / 0.12 active / 0.42 recovery.
- Greatsword overhead: 0.48 startup / 0.12 active / 0.65 recovery.

The default 1.60-second stun covers the longest current attack recovery
(0.65) + slowest Heavy startup (0.48) + active duration (0.12) + 0.20 input
allowance = 1.45 seconds. Actual range and facing still decide the hit.
Revisit break duration if these attack timings are changed.

## Presentation and implementation

The old lower-left panel was outside the viewport because absolute negative
position was used with bottom anchors. It now uses bottom-relative offsets.
One existing enemy panel is projected above the head with camera
unproject_position; it hides behind the camera and is independent of F3.
Health setters emit health_changed for immediate bar updates, including
healing/reset. Guard emits changed; frame refresh also covers max-value edits
and weapon changes.

damage_number.gd spawns a short-lived billboard Label3D from **HP before minus
HP after** in player/enemy/dummy damage application. It therefore shows actual
chip/overkill-capped loss and never spawns for a zero-damage block, parry or
reflect. Independent labels follow the moving actor, separate close hits,
rise/fade over 0.8 seconds and free themselves. No number on healing.
Guard-damage/break notifications are distinct from HP numbers.

Added guard.gd and damage_number.gd. Updated HUD, attack-impact data, attacks,
player, shield, Greatsword action lock, enemy/bot, dummy and humanoid visuals,
player/arena scenes and InputMap. No attack timings or AI response weights
were changed. The opponent gains shield identity selection and the simple
ALWAYS_BLOCK development mode; ordinary sparring commitment remains intact.

## Validation

tests/guard_test.gd checks visible/projected health, immediate updates and
reset, actual chip/overkill and close-hit numbers, rise/fade/cleanup, Guard
costs/delay/hold pause, free parry/reflect, full action lockout, non-refreshable
stun, partial recovery/protection, real ALWAYS_BLOCK depletion and physical
Heavy hits for both weapons, and Greatsword identity.

The existing eight combat/movement/readability suites also run. Legacy
defense fixtures now reset Guard between independent cases and expect the
Guard-damage event while checking the same block/reflection outcomes.

tests/hud_capture.gd runs with a renderer (not --headless) and saves normal
HUD and break/number screenshots inside ignored .godot/. Rendered captures
were inspected for layout/visibility. Manual playtesting remains necessary
for moving-camera legibility, control feel and the desired punish duration.

Tune first: guard_damage, regeneration_rate/delay, break_stun_duration,
post_break_guard_fraction and post_break_immunity. Leave attack/defense
timings alone while judging the new resource.
