class_name PlayerMovementController
extends RefCounted

var player = null


func setup(player_node) -> void:
	player = player_node


func process_locked_movement() -> void:
	player.is_sprinting = false
	player.velocity = Vector2.ZERO
	player.move_and_slide()


func process_movement() -> Vector2:
	var input_dir: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if input_dir != Vector2.ZERO:
		player.facing_direction = input_dir.normalized()
		update_interaction_area_position()

	player.is_sprinting = input_dir != Vector2.ZERO and Input.is_action_pressed("sprint")
	var movement_speed = player.speed * 2.0 if player.is_sprinting else player.speed
	player.velocity = input_dir * movement_speed
	player.move_and_slide()
	return input_dir


func update_interaction_area_position() -> void:
	if player.interaction_area == null:
		return

	player.interaction_area.position = player.facing_direction * player.interaction_distance
