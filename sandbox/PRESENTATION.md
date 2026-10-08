# Prototype fidelity pass

The theme is a restrained stone training courtyard: inset paving, a painted
sparring ring, stone buttresses/caps, blue banners, warm sunlight and a muted
procedural sky. Traversal blocks are restyled as stone practice platforms.
The existing 40 m floor, boundaries, pillar, platforms and ramp keep their
collision transforms and shapes. Added decoration has no gameplay collision.
The open central ring concentrates combat without adding a level or AI paths.

## Characters and weapons

Existing articulated box humanoids gain simple helmets/visors, shoulder plates,
chest armor, belts and boots. Player cloth/shield is teal; opponent cloth/shield
is warm red, with different armor tones. Cloth is rough; weapon/armor materials
have restrained metallic highlights. Shoulder shapes and the shield rim clarify
arm roles. Sword pivot is near the right hand; Greatsword is wider and uses a
two-handed broad-swing pose. The opponent's Greatsword identity also shows an
oversized blade. These are approximate placeholder silhouettes, not final rigs.

Block is raised slightly more visibly, normal stagger leans farther, and HP
loss produces a brief body flash. Existing overhead, parry, bash and Guard
Break poses still use the authoritative combat states and phase timings.
No animation tree or gameplay timing changes.

## HUD and debug

Startup is **Playtest mode**: red HP, relevant green Guard, weapon/name labels,
floating damage numbers and essential block/parry/stagger/break cues. Timers,
combo grammar, input hints and resource diagnostics are omitted from this view.
The player panel is closer to the lower-left; the opponent panel still projects
above its head. Signals/frame refresh keep resource values reliable.
Floating numbers retain actual HP loss, independent lifetimes, rise and fade.

**F3** toggles full instrumentation and hitboxes on both weapon sets and the
opponent. Existing timing, AI and resource data remains available. Hitbox fills
are translucent to keep character poses visible. Debug HUD layout moves upward
to accommodate its extra text. F4/F6/F7 training controls remain unchanged.

## Effects and sound

combat_feedback.gd is a small disposable mesh/audio helper, not a combat manager:
- hit: short warm ring/sparks and impact;
- Heavy hit: larger amber cue and deeper impact;
- block: blue impact and metal contact;
- perfect parry: brighter cyan/white cue and clang;
- reflect: teal burst and resonant cue, alongside the existing cyan projectile;
- Guard Break: larger pink burst; full-duration pose/text remains authoritative;
- bash: short thud; sword/Greatsword active phases have light/heavy whooshes;
- spell release: a short cast cue.

Effects are placed on the camera-visible side of the target, billboard toward
the camera, expand/fade over 0.24 s (0.36 for break), then free themselves.
They have no colliders, damage, input, camera or AI authority. Only actual HP
loss creates hit effects. Blocks/parries/reflects use their actual outcome;
breaking blocks produce the break cue instead of duplicate block feedback.

weapon_trail.gd samples the visible blade during ATTACK_ACTIVE. Its short ribbon
fades over 0.10 s and clears on reset/weapon switch. No trail during startup.
Bash/hilt attacks use impact emphasis rather than an unrelated blade ribbon.
Hitbox queries still determine contacts; ribbon geometry does not deal damage.

The ten short mono WAVs in audio/ are original procedural placeholders created
for this project: noise whooshes, damped thuds and metallic tones. No external
assets or license dependencies. AudioStreamPlayer3D uses -12 dB, 6 m unit size
and a 22 m maximum range, freeing after playback. Headless automation skips
silent playback to avoid pending audio-driver resources at immediate exit.
Replace these WAVs in place for better sound; no mixer/state architecture added.

## Files

Added combat_feedback.gd, weapon_trail.gd, audio/*.wav (+ import metadata), and
tests/presentation_test.gd. Restyled arena.gd/arena.tscn, humanoid.gd,
sword_shield.gd, greatsword.gd and test_enemy.gd. Updated movement_debug.gd and
combat_hud.gd for view separation. Lightweight cue hooks added to incoming_attack,
melee_swing, player, enemy/bot and dummy scripts. hud_capture.gd captures normal,
break, active-Greatsword and full-debug views under ignored .godot/.

No changes to damage/Guard costs, attack phases, commitment/cancel windows,
movement, jump, dodge, defense timing, Spell Reflect ownership/speed, hit detection,
AI decisions or weapon-switch rules. Previous uncommitted Guard work is retained.

## Verification and next polish

presentation_test checks default/F3 behavior, unchanged test collision layout,
non-authoritative effect lifetime, imported audio and active-only trails/reset.
Existing movement/combat/Guard suites run too. Renderer captures are reviewed for
layout/silhouettes. Headless tests validate assets/hooks, not perceived audio
quality. Human playtesting is still needed for mix balance, trail intensity,
moving-camera legibility and whether the improved feedback feels satisfying.

Best next presentation refinements: authored combat poses with better hand/weapon
alignment, replace synthesized sounds, adjust impact placement/levels after
playtesting, and add a few modeled courtyard details. Current geometry, poses,
sparks and sound remain deliberately placeholder-quality.

Open the project once in Godot to import WAVs, or use --headless --editor --quit
before running headless suites from a fresh clone. Run hud_capture.gd with a
renderer (without --headless) to regenerate the ignored review images.
