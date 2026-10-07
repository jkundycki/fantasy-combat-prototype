The enemy now supports imperfect sparring: F4 cycles personality; F6 toggles back to the original melee/fireball tester while idle. See [SPARRING.md](SPARRING.md) for reaction/decision tuning.

Primary chains, finisher feints and 2x Spell Reflect are now implemented. See [COMBOS.md](COMBOS.md) for current timing values and controls; it supersedes earlier single-attack/combo-free notes below.

Q/Y/Triangle switches between Sword & Shield and Greatsword while idle. See [GREATSWORD.md](GREATSWORD.md) for Greatsword mechanics and tuning.

# Movement and Sword & Shield prototype

F5 launches sandbox/arena.tscn. WASD/left stick moves; mouse/right stick looks.
Space/A/Cross jumps. Left Shift/B/Circle dodges. Sprint is removed.

Primary: Left Mouse/X/Square.
Special: E/RB/R1.
Defense: Left Ctrl/LB/L1 (held shield or timed Greatsword parry). Hold RMB for independent camera-facing control.
F3 toggles combat states, shield arc, hitboxes, health, projectile flags and events.
Escape releases the cursor; the first subsequent primary mouse click recaptures it.

[COMBAT.md](COMBAT.md) explains mechanics, input routing, independent airborne
facing/momentum, editable defaults, file changes and regression commands.

Start with the brown stationary dummy for attack spacing. The red test enemy has
slow gold telegraphs: try ordinary blocks, timed melee parries, and reflecting its
orange fireball. Cyan fireballs are reflected. Blue enemy color indicates stagger.
Targets and the player reset automatically after defeat.

The previous tower-defense prototype remains available in main.tscn (F6).
There are no classes, inventory, stamina, combos, weapon swapping or networking.