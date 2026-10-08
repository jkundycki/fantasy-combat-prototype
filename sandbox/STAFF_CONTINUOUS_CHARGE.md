# Continuous Staff charge and roll speed adjustment

The subsequent [slower pacing pass](SLOWER_PACING.md) supersedes numerical defaults and adds a maximum-hold automatic launch. Continuous partial-charge release still applies.

This supersedes Staff stationary-channel instructions in ROLL_CHANNEL_DRAW.md. Bow retains its previous draw/release mechanics.

## Staff controls and tuning

Press Primary (LMB / X / Square) to gather magic immediately. Hold to increase charge, including past maximum indefinitely. Release to fire once, immediately, from the current casting-hand pose along the character's current horizontal facing. RMB/camera controls remain unchanged. There is no hold threshold, grounded channel lock, auto-fire, cancel recovery or release-time direction snapshot from charge start.

Player/Staff Inspector ? Staff continuous charge:

| Parameter | Default | Effect |
| --- | ---: | --- |
| max_charge_time | 1.2 s | Time held to reach full power |
| staff_charge_move_multiplier | 0.50 | Ground speed while held; 4.5 m/s at normal 9 m/s |
| staff_min_damage | 24 | Zero-time quick-shot damage |
| staff_max_damage | 60 | Full damage: 2.5? minimum |
| staff_min_radius | 0.22 m | Small projectile visual/collision radius |
| staff_max_radius | 0.44 m | Full projectile radius: 2? minimum |
| projectile_speed | 18 m/s | Constant at every charge level |
| projectile_lifetime | 3 s | Same lifetime for every charge level |
| recovery_duration | 0.24 s | Full post-release attack recovery |
| guard_damage | 15 | Existing ordinary-block Guard cost |

Use the Staff-specific damage/radius fields above; the shared generic damage/projectile_radius fields continue serving Bow and should not be used to tune Staff charge endpoints.

charge_fraction = clamp(time_held / max_charge_time, 0, 1). Damage and radius interpolate linearly. At half charge (0.6 s): 42 damage, radius 0.33 m. Diameters at minimum/half/full are 0.44/0.66/0.88 m. Projectile visual radius matches its actual swept sphere radius; no separate inflated hitbox.

A brief 0.04 s tap produces about 25.2 damage and radius 0.227 m, close to the original quick bolt. Zero-time release gives exactly 24 / 0.22. Unlike the previous Staff implementation, actual Primary releases no longer wait for the old 0.16 s startup. Recovery remains mandatory; holding does not repeat shots.

The held orb grows from minimum to maximum radius and lightens slightly toward full charge. The upper body holds the casting pose while legs continue locomotion; release uses a short forward casting motion over recovery. Projectile direction is independent of hand height, movement velocity and camera position.

Jump or Dodge cancels the held charge, hides the orb and restores normal movement scaling with no added cancellation penalty. The original jump/dodge conditions still determine whether movement can actually happen. Releasing the canceled Primary fires nothing.

Already-airborne charging is permitted: gravity continues and launch momentum remains independent of facing/charge. Ground movement slowing does not rewrite airborne velocity. Jumping from a ground charge first cancels it, so the held shot is not carried through that jump. Focus loss cancels a held action without firing.

All Staff charge levels remain explicitly reflectable. Reflection keeps the same projectile instance, charge_fraction, damage, mesh size and swept collision sphere; only ownership/faction, direction, reflected tint and the existing speed/lifetime rules change. With default 2? reflect speed the returned projectile travels at 36 m/s at every charge level. Health/damage numbers consume actual scaled damage, including reflected shots.

## Sparring

AI still uses the existing ranged sparring branch, bounded rotation and ALL_OUT recovery rules. It selects a hold duration BEFORE charging and does not optimize release using player inputs.

staff_charge_weights = Vector4(3, 2, 2, 2), ordered quick / short / medium / full:
- Quick: random 0.02?0.08 s.
- Short: random 20?40% of maximum time.
- Medium: random 45?70% of maximum time.
- Full: maximum time plus random 0?staff_full_charge_extra_hold (default 0.25 s).

Every hold advances through actual elapsed time. Player and bot call the same staff_fraction and apply_staff_charge helpers for fraction, damage, radius and constant speed. While charging, bot movement is capped at the exact player slowed speed. Released shots follow its release-facing direction and never track afterward. Existing defensive reactions, commitment, stagger and Guard Break remain authoritative.

## Roll

The old turn was compressed into 70% of the dodge (0.112 s at the current 0.16 s dodge), and smoothstep further concentrated angular speed around the center. It did not rotate multiple times, but its peak spin was excessive.

Rotation now progresses once across the FULL visual window using gentle easing: turn_fraction = p - 0.04 ? sin(2?p). Tuck/recovery fractions affect posture only; they no longer cut time out of the turn.

Player Inspector ? Roll presentation ? roll_visual_duration_multiplier = 1.25. Visual duration is dodge_duration ? multiplier: currently 0.20 s, with a 0.04 s presentation tail after the 0.16 s movement. Half of the visual window is upside down; it completes one turn and settles upright. The new default peak angular speed is less than half the old peak. A new action, stagger/death or Guard Break interrupts the visual tail without delaying gameplay.

Dodge gameplay is unchanged: speed 18 m/s, duration 0.16 s, cooldown 0.35 s, recovery 0. No root motion, collider/camera rotation or new invulnerability. The animation recalculates its duration if dodge timing is tuned. Increasing the multiplier further slows presentation but lengthens its tail; multiplier 1 keeps the visual entirely within gameplay dodge time.

## Verification and tune first

tests/charged_draw_test.gd verifies monotone one-turn rotation, adaptive durations, camera/collider invariants, unchanged dodge constants, Staff tap/partial/full/manual release, grounded speed and mixed locomotion/charge pose, jump/dodge cancellation, air momentum/gravity, partial/full reflection properties and actual damage numbers, and matching AI charge rules and varied hold selection. It retains Bow quick/full/cancel regression checks.

Tune roll_visual_duration_multiplier and max_charge_time first, then staff_charge_move_multiplier, damage/radius endpoints and AI weights. No changes were made to Sword & Shield/Greatsword attacks, Guard, damage-number handling or Bow mechanics in this adjustment.
