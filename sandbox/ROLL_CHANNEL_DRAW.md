# Roll, Staff channel and Bow release tuning

Staff stationary channeling and the original roll speed described below were subsequently replaced by [continuous Staff charging and the slower visual roll](STAFF_CONTINUOUS_CHARGE.md). Bow details remain current.

No DESIGN.md was present in the game directory or its subfolders during this pass. The attached task and existing prototype conventions guided the implementation.

## Controls

Primary uses the existing LMB / X / Square InputMap action for both press and release. Staff: tap for a mobile quick bolt; hold for stationary channel and automatic charged release. Bow: press to draw, hold as long as desired, release to fire. Q/Y still cycles four sets. F5 toggles ALL_OUT; F8 toggles Mirror (default on).

Staff taps preserve normal 0.16 s startup and 0.24 s recovery, 24 damage, 18 m/s speed, 0.22 m radius and 3 s lifetime. A release before startup ends waits only the remaining startup. Holding past hold_threshold = 0.25 s begins CHANNELING if grounded; this necessarily waits to distinguish a tap from a hold. An airborne hold falls back to a normal shot, preserving jump-turn-fire.

Channel duration AFTER the threshold is 1.0 s (1.25 s total by default). Channeling zeros horizontal velocity immediately, ignores jump/dodge input and prevents switching/actions. Camera/facing remains live, including RMB. Gravity and vertical velocity still apply if displaced airborne. The shot uses actual facing at cast completion, never channel-start facing. Releasing early cancels with cancel_recovery = 0.15 s and fires nothing. Holding through completion fires once, never auto repeats. Focus loss cancels a pending/drawn/channelled action safely.

Charged defaults: damage 60 (2.5? normal); radius 0.40 m (1.82? normal, diameter 0.80 m); speed 14 m/s versus normal 18; lifetime 4 s. Larger orb, tail and stronger blue impact distinguish it. Guard cost remains 15. It explicitly remains reflectable and blockable, not melee-parryable. Reflection changes ownership and faction, uses defender facing and the existing multiplier: normally 28 m/s reflected. Returned charged shots can damage the original caster.

Bow quick press/release preserves 0.20 s minimum startup and 0.28 s recovery. Releasing before startup ends schedules one arrow at the remaining startup, with direction and strength captured at release. Longer draws release immediately. Full draw time is 0.75 s; it can remain held indefinitely without auto firing. Draw movement multiplier = 0.50, giving 4.5 m/s ground movement at normal speed 9. Airborne launch momentum stays independent of facing and draw restrictions.

Draw strength is zero through the initial quick-shot startup, then increases linearly to full at 0.75 s. Damage interpolates 28 ? 37.8 (full_draw_damage_multiplier = 1.35); speed 48 ? 57.6 m/s (full_draw_speed_multiplier = 1.20). Radius 0.055 m and lifetime 2 s remain unchanged. Facing is captured when Primary is released, with no camera-origin aim or homing. Dodge/jump cancels a held draw without firing or extra recovery and leaves the normal movement input intact; ordinary dodge eligibility/cooldown still applies.

Projectile origins are model-relative: Staff uses the casting-hand point near the staff, Bow the front of the held arrow. Direction is independently normalized character forward, horizontally, including in the air. Bot projectiles now also use horizontal facing instead of deriving a vertical angle from spawn height/target position.

## Presentation and AI

The procedural humanoid's body parts are wrapped in RollVisual, a body-center pivot. During the existing dodge window it crouches/tucks, rotates one turn along dodge_direction, then restores standing. Only model transforms change: no root motion, camera roll, collider rotation or invulnerability is added. Dodge remains 18 m/s, 0.16 s duration and 0.35 s cooldown. The selected player weapon is temporarily hidden during the roll.

Player Inspector Roll presentation tuning (also available on the procedural humanoid): roll_tuck_fraction = 0.15, roll_recovery_fraction = 0.15, roll_crouch_depth = 0.35 m. Fractions adapt the visual to gameplay dodge duration. Staff channel raises both arms and grows an energy orb from 30% to full size over actual channel time. Bow extends the holding arm, pulls the drawing arm and shifts the string/held arrow as actual draw fraction increases.

AI charged_staff_chance = 0.30: otherwise normal shots. Selected charges wait the same threshold and full channel duration, stand still, turn at the existing bounded speed, auto fire and respect recovery/stagger/Guard Break. They never cancel based on player input. AI held_bow_chance = 0.45: otherwise quick draws. Held draws last draw_duration plus a random 0?bow_extra_hold = 0.25 s, visibly draw while repositioning and release with matching strength. Drawing speed is capped at the player's slowed ground speed; all committed ranged movement respects the player's corresponding speed cap. AI decisions remain random and tracking remains bounded; released projectiles do not track.

## Tune first

1. Staff hold_threshold and channel_duration: tap discrimination versus commitment.
2. Charged damage/speed/radius: danger, dodgeability and forgiveness.
3. Bow draw_duration and draw_movement_multiplier: release rhythm and mobility.
4. Bow full-draw damage/speed multipliers: modest reward for holding.
5. Roll tuck/recovery fractions and crouch depth, without changing dodge balance.
6. Bot charged/held probabilities and bow_extra_hold.

Primary gameplay changes are confined to ranged press/release, movement restrictions/cancellation and bot ranged branches. Existing Sword & Shield/Greatsword actions, feints, Guard and reflection authority remain unchanged. Heavy/Bash/Defense remain undefined for Staff/Bow.

tests/charged_draw_test.gd covers acceptance A?J; all existing movement, combat, defense, reflection, Greatsword, combo, sparring, readability, Guard, presentation and ranged suites remain part of validation.
