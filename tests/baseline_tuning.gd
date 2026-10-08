extends RefCounted
# Older mechanic suites use an explicit preset; pacing_test validates shipped values.
const VALUES = {
	"Player": {
		"move_speed": 9.0,
		"ground_acceleration": 180.0,
		"ground_deceleration": 220.0,
		"ground_turn_acceleration": 360.0,
		"air_acceleration": 6.0,
		"jump_speed": 10.0,
		"gravity": 28.0,
		"dodge_speed": 18.0,
		"dodge_duration": 0.16,
		"dodge_cooldown": 0.35
	},
	"Player/SwordShield": {
		"block_startup": 0.0,
		"perfect_block_duration": 0.16,
		"parry_stagger_duration": 0.85,
		"defender_recovery": 0.08,
		"parry_hit_stop": 0.045,
		"block_hit_stop": 0.015,
		"hard_feint_recovery": 0.15
	},
	"Player/Greatsword": {
		"parry_startup": 0.04,
		"parry_window": 0.18,
		"parry_recovery": 0.3,
		"successful_parry_recovery": 0.08,
		"parry_stagger_duration": 0.9,
		"parry_hit_stop": 0.055,
		"hard_feint_recovery": 0.15
	},
	"Player/Staff": {
		"startup_duration": 0.16,
		"recovery_duration": 0.24,
		"projectile_speed": 18.0,
		"projectile_lifetime": 3.0,
		"max_charge_time": 1.2,
		"staff_min_damage": 24.0,
		"staff_max_damage": 60.0,
		"draw_duration": 0.75,
		"auto_release_time": 0.0
	},
	"Player/Bow": {
		"startup_duration": 0.2,
		"recovery_duration": 0.28,
		"projectile_speed": 48.0,
		"projectile_lifetime": 2.0,
		"max_charge_time": 1.2,
		"staff_min_damage": 24.0,
		"staff_max_damage": 60.0,
		"draw_duration": 0.75,
		"auto_release_time": 0.0
	},
	"Player/SwordShield/Guard": {
		"regeneration_rate": 25.0,
		"regeneration_delay": 1.25,
		"break_stun_duration": 1.6,
		"post_break_immunity": 0.75
	},
	"TestEnemy/Guard": {
		"regeneration_rate": 25.0,
		"regeneration_delay": 1.25,
		"break_stun_duration": 1.6,
		"post_break_immunity": 0.75
	},
	"Player/SwordShield/PrimaryChain": {
		"combo_timeout": 0.65
	},
	"Player/Greatsword/PrimaryChain": {
		"combo_timeout": 0.8
	},
	"Player/SwordShield/Sword": {
		"startup_duration": 0.09,
		"active_duration": 0.12,
		"recovery_duration": 0.2,
		"turn_speed_degrees": 0.0,
		"stagger_duration": 0.0,
		"hit_stop_duration": 0.035,
		"commitment_time": -1.0,
		"feint_window_start": -1.0,
		"feint_window_end": -1.0
	},
	"Player/SwordShield/Reverse": {
		"startup_duration": 0.11,
		"active_duration": 0.12,
		"recovery_duration": 0.22,
		"turn_speed_degrees": 0.0,
		"stagger_duration": 0.0,
		"hit_stop_duration": 0.035,
		"commitment_time": -1.0,
		"feint_window_start": -1.0,
		"feint_window_end": -1.0
	},
	"Player/SwordShield/Finisher": {
		"startup_duration": 0.15,
		"active_duration": 0.12,
		"recovery_duration": 0.26,
		"turn_speed_degrees": 0.0,
		"stagger_duration": 0.0,
		"hit_stop_duration": 0.045,
		"commitment_time": -1.0,
		"feint_window_start": -1.0,
		"feint_window_end": -1.0
	},
	"Player/SwordShield/Heavy": {
		"startup_duration": 0.42,
		"active_duration": 0.12,
		"recovery_duration": 0.42,
		"turn_speed_degrees": 180.0,
		"stagger_duration": 0.7,
		"hit_stop_duration": 0.06,
		"commitment_time": 0.273,
		"feint_window_start": 0.1,
		"feint_window_end": 0.26
	},
	"Player/SwordShield/Bash": {
		"startup_duration": 0.06,
		"active_duration": 0.09,
		"recovery_duration": 0.24,
		"turn_speed_degrees": 0.0,
		"stagger_duration": 0.2,
		"hit_stop_duration": 0.045,
		"commitment_time": -1.0,
		"feint_window_start": -1.0,
		"feint_window_end": -1.0
	},
	"Player/SwordShield/Feint": {
		"startup_duration": 0.07,
		"active_duration": 0.08,
		"recovery_duration": 0.32,
		"turn_speed_degrees": 0.0,
		"stagger_duration": 0.2,
		"hit_stop_duration": 0.025,
		"commitment_time": -1.0,
		"feint_window_start": -1.0,
		"feint_window_end": -1.0
	},
	"Player/Greatsword/Slash": {
		"startup_duration": 0.22,
		"active_duration": 0.18,
		"recovery_duration": 0.38,
		"turn_speed_degrees": 0.0,
		"stagger_duration": 0.3,
		"hit_stop_duration": 0.055,
		"commitment_time": -1.0,
		"feint_window_start": -1.0,
		"feint_window_end": -1.0
	},
	"Player/Greatsword/Reverse": {
		"startup_duration": 0.25,
		"active_duration": 0.18,
		"recovery_duration": 0.42,
		"turn_speed_degrees": 0.0,
		"stagger_duration": 0.35,
		"hit_stop_duration": 0.055,
		"commitment_time": -1.0,
		"feint_window_start": -1.0,
		"feint_window_end": -1.0
	},
	"Player/Greatsword/Finisher": {
		"startup_duration": 0.29,
		"active_duration": 0.18,
		"recovery_duration": 0.46,
		"turn_speed_degrees": 0.0,
		"stagger_duration": 0.4,
		"hit_stop_duration": 0.065,
		"commitment_time": -1.0,
		"feint_window_start": -1.0,
		"feint_window_end": -1.0
	},
	"Player/Greatsword/Heavy": {
		"startup_duration": 0.48,
		"active_duration": 0.12,
		"recovery_duration": 0.65,
		"turn_speed_degrees": 180.0,
		"stagger_duration": 0.95,
		"hit_stop_duration": 0.075,
		"commitment_time": 0.312,
		"feint_window_start": -1.0,
		"feint_window_end": -1.0
	},
	"Player/Greatsword/Feint": {
		"startup_duration": 0.08,
		"active_duration": 0.08,
		"recovery_duration": 0.38,
		"turn_speed_degrees": 0.0,
		"stagger_duration": 0.2,
		"hit_stop_duration": 0.025,
		"commitment_time": -1.0,
		"feint_window_start": -1.0,
		"feint_window_end": -1.0
	},
	"TestEnemy": {
		"move_speed": 1.5,
		"attack_interval": 1.4,
		"melee_startup": 0.8,
		"melee_active": 0.16,
		"melee_recovery": 1.0,
		"melee_stagger": 0.0,
		"melee_hit_stop": 0.0,
		"fireball_startup": 0.9,
		"fireball_recovery": 1.1,
		"projectile_speed": 5.0,
		"flash_duration": 0.09,
		"recoil_return_speed": 1.5,
		"reaction_delay": 0.28,
		"reaction_jitter": 0.07,
		"turning_speed_degrees": 180.0,
		"block_duration": 0.5,
		"parry_prediction_delay": 0.1,
		"parry_prediction_jitter": 0.1,
		"parry_window": 0.18,
		"parry_attacker_stagger": 0.6,
		"parry_hit_stop": 0.035,
		"defensive_recovery": 0.28,
		"missed_parry_recovery": 0.4,
		"dodge_recovery": 0.3,
		"pressure_move_speed": 9.5,
		"pressure_attack_interval": 0.06,
		"ranged_move_speed": 5.0,
		"ranged_strafe_speed": 2.0,
		"staff_full_charge_extra_hold": 0.25,
		"bow_extra_hold": 0.25,
		"dodge_speed": 9.0,
		"dodge_duration": 0.2,
		"dodge_cooldown": 0.0
	}
}
static func apply(arena: Node) -> void:
	for path in VALUES:
		var node = arena.get_node(path)
		for property in VALUES[path]:
			node.set(property, VALUES[path][property])
