# Slower playtest tuning

This pass supersedes earlier numeric defaults and Staff indefinite-hold behavior. No global Engine.time_scale change is used; camera/input response and HUD updates remain responsive.

## Movement and jump

Normal speed: 9 ? 7.2 m/s (80%). Ground acceleration/deceleration/turn acceleration and air acceleration also scale to 80%, preserving responsiveness relative to speed.

Jump velocity: 10 ? 8 m/s. Gravity: 28 ? 22.4 m/s?. Together they produce approximately 80% of the old jump height with the same rising/falling time profile. Fall-gravity and release multipliers remain unchanged. Airborne momentum/facing separation is retained.

Bot ordinary, ranged and ALL_OUT pursuit movement speeds also scale to 80%. Its charging speed cap follows the player's 7.2 ? 0.5 = 3.6 m/s.

## Combat

Half-speed means durations double, not merely increasing times by 50%. This applies to attack startup/active/recovery, combo timeout, feint commitment times/windows, defense/parry timing, stagger/hit-stop, AI reaction/decision/recovery timing, and Guard regeneration delay/break stun/protection. Early tracking and AI turning rates halve so the angles available over the doubled action times remain comparable. Guard regeneration rate halves.

Projectile speed halves and lifetime doubles to preserve maximum travel distance:
- Staff: 18 ? 9 m/s; lifetime 3 ? 6 s.
- Bow: 48 ? 24 m/s; lifetime 2 ? 4 s.
- Legacy bot fireball fixture: 5 ? 2.5 m/s.

Bow draw time: 0.75 ? 1.5 s. Bow quick startup: 0.20 ? 0.40 s; recovery 0.28 ? 0.56 s. Staff post-shot recovery: 0.24 ? 0.48 s. Staff quick manual release remains immediate.

Impact effects and blade-trail fades last twice as long. Existing audio, camera sensitivity, input forgiveness, health totals and melee damage values remain unchanged. Respawn delays remain short for convenient testing.

## Staff hold cutoff and damage

Player/Staff:
- max_charge_time = 2.4 s.
- auto_release_time = 2.4 s: automatic launch at the cutoff. Zero disables this limit for tuning.
- staff_min_damage = 12, staff_max_damage = 30: both halved.
- staff_min_radius = 0.22 m, staff_max_radius = 0.44 m: size endpoints unchanged.
- projectile_speed = 9 m/s at every charge level.
- staff_charge_move_multiplier = 0.50, giving 3.6 m/s grounded charge movement.

Hold time still increases damage and physical/visual radius linearly. At 1.2 s: 21 damage, 0.33 m radius. At 2.4 s: 30 damage, 0.44 m radius. Release earlier for a smaller weaker shot; reaching the cutoff fires in current facing without waiting for release. Continuing to hold, or releasing after the automatic shot, never creates an extra shot. A fresh press after recovery starts the next charge.

Jump/dodge still discard a held charge. Air charging still preserves gravity and launch velocity. All sizes reflect through the existing rules and preserve their scaled damage/radius; default reflected speed is now 18 m/s. AI Staff holds use the same cutoff and reduced damage endpoints.

## Roll

Player dodge_speed = 9 m/s, dodge_duration = 0.432 s:
- Nominal unobstructed distance: 3.888 m.
- Previous distance: 18 ? 0.16 = 2.88 m.
- Increase: exactly 35% nominal.
- dodge_cooldown = 5.0 s, measured from activation.
- roll_visual_duration_multiplier = 1.25, so the one-turn visual lasts 0.54 s.

Movement duration is 2.7? the old value; the visual takes 2.7? as long as the previous 0.20 s visual. The final 0.108 s is presentation only and does not delay another action. No root motion, camera/capsule roll or new invulnerability.

Bot dodges also gain a five-second cooldown. Its own old 1.8 m dodge now travels nominally 2.43 m (+35%), at 4.5 m/s over 0.54 s. Weighted decisions cannot bypass that cooldown.

## Validation and next tuning

tests/pacing_test.gd tests the actual shipped scene, including real roll displacement/cooldown, slowed attack/defense/Guard values, 80% jump-height ratio, half-speed projectiles, continuous reduced Staff power, automatic cutoff with no double shot, mirrored AI limits and reduced reflected damage.

Existing mechanic suites use tests/baseline_tuning.gd to explicitly retain the original preset their timing assertions were written for. They continue checking the underlying movement/combat/reflect/Guard rules; pacing_test separately guards the new defaults.

Tune dodge_duration/dodge_speed together to preserve distance while adjusting roll time, auto_release_time/max_charge_time for the Staff cutoff, and individual attack recovery times if this broader slowdown feels too deliberate.
