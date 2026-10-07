The default F5 scene is now the third-person movement and Sword & Shield sandbox. See [sandbox/README.md](sandbox/README.md) for controls and tuning. The previous prototype below remains available through main.tscn.

# Stonewatch

A procedural 3D tower-defense skeleton: free placement, an invulnerable builder, a fixed enemy road, and self-contained ten-wave matches. Open project.godot in Godot and press F5.

## Controls

- Right-click open terrain to move the builder. Movement routes around towers, trees, and the keep. Roads are walkable.
- Press 1, 2, or 3, or use the bottom build menu, to choose a tower.
- Move the cursor over the map. A green ghost indicates valid terrain; red explains the placement restriction. The ring shows attack range.
- Left-click to order construction. The builder walks into reach and spends two seconds constructing the tower.
- Left-click near an existing tower's base to select it, then use Upgrade. The builder must reach it to finish the upgrade. Towers continue firing while being upgraded.
- Escape or Cancel stops movement and unfinished work. Unfinished construction and upgrades refund their full reserved cost.
- Giving a new move order or choosing another tower also cancels and refunds unfinished work. There is one builder order at a time; no construction queue yet.
- Mouse wheel zooms. Space starts the next wave. Restart resets the entire match.

## Towers

| Tower | Cost | Role |
| --- | ---: | --- |
| Watchtower | 50 | Fast single-target crossbow fire |
| Bombard | 80 | Slower attacks with a 1.8-unit splash radius |
| Hex Obelisk | 65 | Light damage and a 45% movement slow lasting two seconds; repeated hits refresh it |

Each tower has three levels. Upgrades improve damage, range, and firing speed. Tower placement keeps roads, structures, trees, the builder's footprint, and map boundaries clear. The builder must have a route to the site before gold is reserved. Terrain positions are free, not tied to pads; only builder navigation uses an internal grid.

Start with 150 gold and 20 lives. Kills award 8 gold, completed waves award a bonus, and an enemy reaching the keep costs one life. Complete ten waves to win. There are no heroes or persistent unlocks. Art is deliberately simple stone/timber/iron geometry; attacks currently use instant damage with short visual traces.

## Files

- main.gd: match rules, builder navigation, construction orders, input, UI, tower data, and combat.
- prototype_art.gd: replaceable procedural models and materials.
- main.tscn: starting scene.
- tests/smoke_test.gd: placement, navigation, refunds, upgrades, tower roles, earned-gold campaign, defeat, and reset checks.
- tests/input_test.gd: actual keyboard/mouse event checks, including UI click isolation.
- backups/: earlier playable versions, excluded from Godot's resource scan.

Run the checks with the Godot console executable:

    Godot --headless --path <project-folder> --script res://tests/smoke_test.gd --quit-after 600
    Godot --headless --path <project-folder> --script res://tests/input_test.gd --quit-after 120

Look for PASS output and no assertion/script errors. The quit-after guard prevents an assertion failure from leaving a test process running.
