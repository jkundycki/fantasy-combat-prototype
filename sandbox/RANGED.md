# Staff, Bow and mirrored sparring

The subsequent [roll/channel/draw pass](ROLL_CHANNEL_DRAW.md) supersedes the one-shot-only Primary controls and bot ranged aiming details below. Normal projectile defaults remain unchanged.

Q / Y / Triangle cycles Sword & Shield ? Greatsword ? Staff ? Bow ? Sword & Shield. Primary remains LMB / X / Square. RMB facing, movement, jumping and dodge bindings are unchanged.

F8 toggles Mirror Weapon (ON by default). F5 toggles Balanced / ALL_OUT immediately. F4 cycles the existing personalities plus ALL_OUT. F3 shows attack/debug geometry and detailed AI state. The opponent panel shows its weapon, MIRROR/MANUAL, and ALL_OUT when selected. F6 still toggles the legacy slow-fireball fixture; disable that fixture to use mirrored sparring. F7 remains ALWAYS_BLOCK for Sword & Shield.

## Initial tuning

Values live on Player/Staff and Player/Bow in player.tscn, using ranged_weapon.gd.

| Parameter | Staff | Bow | Meaning |
| --- | ---: | ---: | --- |
| startup_duration | 0.16 s | 0.20 s | Cast or draw before releasing exactly one shot |
| recovery_duration | 0.24 s | 0.28 s | Mandatory interval before another Primary |
| damage | 24 HP | 28 HP | Damage for a physical hit |
| guard_damage | 15 | 15 | Guard cost of an ordinary shield block |
| projectile_speed | 18 m/s | 48 m/s | Straight-line travel speed |
| projectile_radius | 0.22 m | 0.055 m | Actual swept sphere radius; diameters are 0.44 m / 0.11 m |
| projectile_lifetime | 3 s | 2 s | Shot expires even if nothing is hit |
| movement_multiplier | 0.85 | 0.85 | Ground movement during startup/recovery; airborne momentum is preserved |

Neither weapon has a Light combo or attack queue. A Primary press during commitment is ignored; a fresh press after recovery fires again. Heavy, Bash, Defense and hard Cancel are deliberately no-ops. There are no resources or charge mechanics.

The player aims with actual character facing at release, including turns during the short cast/draw. There is no camera pitch aiming mode: player shots leave at chest height in the horizontal character-facing direction. Turning backward in the air changes the shot direction without writing movement velocity or changing the launch reference.

Staff uses a blue orb with a short tail and blue impact. Bow uses a narrow shaft/head and warm impact. Both use the existing health, damage-number, recoil, death/reset and feedback paths. Collision sweeps the entire traveled segment with a sphere, including starting overlaps; walls block both types and arrows cannot skip thin walls at high speed.

Only this Staff bolt sets IncomingAttack.reflectable = true. Perfect Sword & Shield Block returns REFLECT, changes the shot's owner and collision faction, launches along the defender's facing and multiplies its original speed by the existing reflect multiplier (2 by default: 36 m/s). Returned bolts can hit the original caster or another opponent. One reflection per shot follows the existing rule. Arrows set reflectable = false; they can be ordinarily blocked, including during perfect timing, and cannot be melee-parried.

## Opponent

Mirror selection waits for an idle/approach state after full attack/defensive recovery, hit-stop, stagger and Guard Break. ALWAYS_BLOCK can change equipment when otherwise safe. Disabling Mirror leaves the current loadout equipped and enables the Inspector opponent_weapon selector. Mirror changes made while committed apply at the next safe boundary. For manual Inspector selection, edit opponent_weapon while the bot is idle.

Mirrored melee uses the existing player's actual three Light attacks' damage, Guard damage, startup, active time, recovery, range, arc and stagger settings. Full preceding recoveries are respected; the bot does not acquire new Heavy/Bash abilities in this pass.

ALL_OUT has the same reaction delay, jitter, perception and parry timing as Balanced. Its weighted decision favors offensive greed (B/P/D/G = 1/1/1/12 vs Balanced 3/2/2/3). It pursues at pressure_move_speed = 9.5 m/s and uses pressure_attack_interval = 0.06 s after full recovery instead of attack_interval = 1.4 s. It can close on a visible whiff/recovery and resume offense after a successful defense; it never skips defensive recovery, stagger or Guard Break. Balanced retains its slower 1.5 m/s melee approach and longer pauses.

Staff prefers staff_min_range / staff_max_range = 6?9 m. Bow prefers bow_min_range / bow_max_range = 9?13 m. Both strafe at ranged_strafe_speed = 2 m/s, create space when rushed at ranged_move_speed = 5 m/s, and pursue if outside the band. ALL_OUT pursues at 9.5 m/s. Repositioning continues through casts/recovery; heading remains committed. arena_limit = 17 m biases movement inward near the courtyard edges. This is simple local movement, not navigation/pathfinding around obstacles.

Before firing, the bot turns toward the player's currently visible location, captures that location at startup and commits its heading. The projectile's horizontal direction is the bot's actual facing, with a small vertical aim toward the captured body position so jumping targets can be attacked. Once launched it never updates direction or predicts movement. Physical sidesteps/dodges can make it miss. Ranged loadouts cannot block or parry; their delayed weighted defense can select a physical dodge or offensive greed.

## Tune first

1. projectile_speed and projectile_radius: speed versus forgiveness/dodgeability.
2. startup_duration and recovery_duration: responsiveness versus repeated-shot rhythm.
3. movement_multiplier: how freely shots can be fired on the ground.
4. The two preferred range bands, ranged_move_speed and ranged_strafe_speed.
5. pressure_attack_interval and pressure_move_speed for the stress test. Reaction settings are separate; ALL_OUT does not sharpen them.

Architecture additions are limited to ranged_weapon.gd (one-shot timing and primitive model) and ranged_projectile.gd (swept collision/ownership). Existing melee attack components are preserved. The existing bot gains weapon-specific tuning, safe mirroring and a small ranged movement branch.

tests/ranged_test.gd covers A?G, including actual hit/miss/radius/wall collisions, reflection ownership/direction/speed/caster damage, nonreflectable arrow blocking, independent air velocity, safe mirroring, mirrored Greatsword parameters, pursuit, ranged spacing, committed aim and full recovery/stagger.
