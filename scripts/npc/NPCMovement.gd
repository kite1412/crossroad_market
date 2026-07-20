class_name NPCMovement
extends RefCounted


static func move_to(npc: CharacterBody2D, target: Vector2, speed: float, arrival_threshold: float) -> bool:
	if npc == null:
		return true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var distance := npc.global_position.distance_to(target)

	if distance <= arrival_threshold:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		return true

	npc.velocity = npc.global_position.direction_to(target) * speed
	npc.move_and_slide()
	return false
