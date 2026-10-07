extends Area3D

func receive_attack(impact: Resource, origin: Vector3, attacker: Node) -> String:
	# Area owns overlap geometry; the body owns health and stagger.
	return get_parent().receive_attack(impact, origin, attacker)