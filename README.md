# Fantasy Combat Prototype

A Godot 4.7.2 / GDScript third-person fantasy action combat sandbox. Open
`project.godot` and press F5 to play the stone training courtyard.

The prototype includes responsive movement and jumping, dodge, directional
Sword & Shield and Greatsword attacks, three-hit Light chains, independent
Heavy attacks, Bash soft-feints, hard-feint recovery, block/parry, directional
Spell Reflect, a sparring opponent, health bars and procedural humanoid poses.

## Controls

| Action | Keyboard / mouse | Xbox / PlayStation |
| --- | --- | --- |
| Move | WASD | Left stick |
| Look | Mouse | Right stick |
| Camera-facing | Hold RMB | Face through movement / guarded facing |
| Jump | Space | A / Cross |
| Dodge | Left Shift | B / Circle |
| Light | LMB | X / Square |
| Heavy | E | RT / R2 |
| Bash | F | RB / R1 |
| Hard-feint Cancel | R | Right-stick click |
| Defense | Left Ctrl | LB / L1 |
| Switch weapon | Q | Y / Triangle |
| Debug / hitboxes | F3 | ? |
| Bot personality | F4 | ? |
| Bot sparring / projectile mode | F6 | ? |
| ALWAYS_BLOCK training mode | F7 | ? |

During Light 2 recovery, Light queues Light 3 and Heavy queues the same Heavy
used from neutral. Heavy permits Bash or hard Cancel during the first 65% of
startup. Cancel has a 0.15-second recovery; Light never directly soft-feints
Heavy. Timing, facing and physical spacing determine hits.

## Tuning and validation

See [presentation and feedback notes](sandbox/PRESENTATION.md),
[health, Guard and Guard Break tuning](sandbox/GUARD.md),
[current combat grammar and tuning](sandbox/READABILITY.md) and
[sparring opponent notes](sandbox/SPARRING.md). Some older sandbox design notes
describe earlier iterations; READABILITY.md documents the current grammar.

Run the current regression suites with your Godot console executable:

```powershell
$godot = "C:\path\to\Godot_console.exe"
foreach ($suite in @("movement", "combat", "defense", "reflection", "greatsword", "combo", "sparring", "readability", "guard", "presentation")) {
    & $godot --headless --path . --script "res://tests/${suite}_test.gd" --quit-after 4000
}
```

Look for PASS output and no script errors. Godot-generated `.godot/` cache and
local `backups/` are excluded; script `.uid` files are tracked.

The previous tower-defense experiment remains in `main.tscn`; its original
notes are preserved in [LEGACY_PROTOTYPE.md](LEGACY_PROTOTYPE.md). The default
scene for this repository is `sandbox/arena.tscn`.

Staff/Bow and mirrored opponent controls, defaults and tuning: [sandbox/RANGED.md](sandbox/RANGED.md). Q/Y now cycles all four sets; F5 toggles ALL_OUT and F8 toggles Mirror (default ON).

Current ranged press/hold/release and visual roll controls: [sandbox/ROLL_CHANNEL_DRAW.md](sandbox/ROLL_CHANNEL_DRAW.md) (supersedes the one-shot input details in RANGED.md).

Latest Staff controls and roll speed tuning: [sandbox/STAFF_CONTINUOUS_CHARGE.md](sandbox/STAFF_CONTINUOUS_CHARGE.md). Staff now holds to charge while moving slowly and fires only on release.

Current slower playtest defaults and Staff forced-release cutoff: [sandbox/SLOWER_PACING.md](sandbox/SLOWER_PACING.md).
