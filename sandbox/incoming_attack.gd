extends Resource

# Independent properties: a projectile is not automatically reflectable.
@export var damage: float = 12.0
@export var melee: bool = false
@export var blockable: bool = false
@export var parryable: bool = false
@export var reflectable: bool = false
@export var stagger_duration: float = 0.0
@export var hit_stop: float = 0.0
@export var guard_break: bool = false
