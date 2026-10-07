# Combat grammar and readability

InputMap: Primary = LMB / X (Square); Heavy = E / right trigger (RT/R2);
Bash (special) = F / right shoulder (RB/R1); hard Cancel = R / right-stick
click (R3). Defense, mobility, weapon switching and camera retain their bindings.

Primary uses a three-hit Light chain. SwordShield: chop, reverse chop, finishing
sword cut. Greatsword: broad swing, reverse swing, finishing sweep. Light 3 is
normally blockable/parryable and has no Heavy feint branches.

During Light 2 recovery, Primary queues Light 3; Heavy queues the same Heavy
node used from neutral. Both use the existing single-slot buffer (opens at
35% of recovery) and wait for full recovery. Latest valid branch input wins.
Once Light 2 finishes, either input can be pressed directly. Combo timeout
remains 0.65 seconds for SwordShield and 0.80 seconds for Greatsword.

Heavy startup: wait to commit, Bash to soft-feint, Cancel to hard-feint.
Primary is ignored, never buffered out of Heavy. Eligibility is strictly
elapsed startup < startup_duration * feint_startup_fraction; default fraction
0.65. Early facing follows player intent at the existing bounded turn rate;
facing locks at the same cutoff. No cancel in active or recovery phases.

Hard Cancel clears the Heavy and combo queue and enters 0.15 seconds of
hard_feint_recovery. Attacks, defense activation, dodge and weapon switching
cannot overlap this reset. Ordinary movement remains available. No automatic
follow-up is selected. Press a new action after recovery. Holding SwordShield
defense may raise it once the reset ends; Greatsword requires a fresh press
for its finite parry attempt.

SwordShield Heavy keeps the shield-slam behavior, now available from neutral,
with 45 damage and 0.42 / 0.12 / 0.42 phase seconds. Light 3 is a 29-damage
sword cut with 0.15 / 0.12 / 0.26 phases.
Greatsword Heavy remains the 65-damage overhead with 0.48 / 0.12 / 0.65 phases.
Light 3 is a 50-damage sweep with 0.29 / 0.18 / 0.46 phases.
Both Heavy moves are the exact same instances for neutral and combo branches.

Bash retains short physical range and mild stagger. Heavy soft-feints reuse
the existing guard-breaking shield/hilt jab. Neutral SwordShield Bash uses
its existing quick bash, now guard-breaking; Greatsword uses the hilt bash.
Neither homes, targets dodges, or grants anti-dodge bonuses.

Removed Chase nodes, Primary-to-chase routing, and forward-step support.
Slam was renamed Heavy; both former combo Heavy finishers were replaced by
Light 3. Input special now means Bash, so Greatsword Heavy uses the new
heavy action. Sparring AI implementation is unchanged: it reads observable
started swings and retains committed responses across hard/soft feints.

Tune first: Heavy.feint_startup_fraction, weapon.hard_feint_recovery,
Heavy startup/recovery durations and turn_speed_degrees, Light3 startup/
recovery, and PrimaryChain.buffer_recovery_fraction/combo_timeout.
Heavy commitment_time is retained for older non-fraction attacks; fraction-
configured Heavy uses its fraction for both cancel cutoff and facing lock.

HUD health and procedural humanoid poses remain. Development state text shows
LIGHT_COMBO_STEP, HEAVY_STARTUP/progress, HEAVY_FEINTABLE/HEAVY_COMMITTED,
BASH_SOFT_FEINT, HARD_FEINT/FEINT_RECOVERY and NEUTRAL. F3 toggles the detailed
diagnostics/hitboxes, independently of health bars.
