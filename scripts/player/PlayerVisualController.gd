class_name PlayerVisualController
extends RefCounted

const CARRIED_OBJECT_FRONT_OFFSET: Vector2 = Vector2(0, -50)
const CARRIED_OBJECT_BACK_OFFSET: Vector2 = Vector2(0, -55)
const CARRIED_OBJECT_LEFT_OFFSET: Vector2 = Vector2(0, -55)
const CARRIED_OBJECT_RIGHT_OFFSET: Vector2 = Vector2(0, -55)
const CARRIED_OBJECT_FRONT_Z: int = 2
const CARRIED_OBJECT_BACK_Z: int = 2
const CARRIED_OBJECT_SIDE_Z: int = 2
const SPRITE_NORMAL_Z: int = 0
const SPRITE_ACTION_FRONT_Z: int = 0
const SPRITE_ACTION_BACK_Z: int = 1

var player = null


func setup(player_node) -> void:
	player = player_node


func initialize() -> void:
	apply_sprite_base_z_indexes()

	if player.sprite_move != null:
		player.sprite_move.visible = false
	if player.sprite_action != null:
		player.sprite_action.visible = false


func update_character_sprite(motion: Vector2) -> void:
	if player.sprite_move == null and player.sprite_idle == null and player.sprite_action == null:
		return

	var is_moving := motion != Vector2.ZERO
	var carrying_shelf := is_carrying_shelf()

	if is_moving:
		player._move_direction = get_direction(motion)

	var active_sprite := get_active_character_sprite(carrying_shelf, is_moving)
	set_character_sprite_visibility(active_sprite)

	if active_sprite == null:
		return

	if is_moving:
		if active_sprite.has_method("apply_motion_vector"):
			active_sprite.call("apply_motion_vector", motion)
	else:
		if active_sprite.has_method("play_direction_loop"):
			active_sprite.call("play_direction_loop", player._move_direction)


func get_active_character_sprite(is_carrying_shelf_value: bool, is_moving: bool) -> AnimatedSprite2D:
	if is_carrying_shelf_value:
		return player.sprite_action

	return player.sprite_move if is_moving else player.sprite_idle


func set_character_sprite_visibility(active_sprite: AnimatedSprite2D) -> void:
	for sprite in [player.sprite_move, player.sprite_idle, player.sprite_action]:
		if sprite == null:
			continue

		sprite.visible = sprite == active_sprite


func update_carried_object_visual(carried_object: Node2D = null) -> void:
	var object: Node2D = carried_object if carried_object != null else player._get_carried_object()
	if object == null:
		apply_sprite_base_z_indexes()
		return

	object.position = get_carried_object_offset()
	object.z_index = get_carried_object_z_index()
	apply_carry_sprite_z_index()


func is_carrying_shelf() -> bool:
	return player._get_carried_object() != null


func get_direction(motion: Vector2) -> CharacterSprite.Direction:
	if motion == Vector2.ZERO:
		return CharacterSprite.Direction.DOWN

	if abs(motion.x) > abs(motion.y):
		return CharacterSprite.Direction.RIGHT if motion.x > 0 else CharacterSprite.Direction.LEFT
	else:
		return CharacterSprite.Direction.DOWN if motion.y > 0 else CharacterSprite.Direction.UP


func get_carried_object_offset() -> Vector2:
	match player._move_direction:
		CharacterSprite.Direction.UP:
			return CARRIED_OBJECT_BACK_OFFSET
		CharacterSprite.Direction.LEFT:
			return CARRIED_OBJECT_LEFT_OFFSET
		CharacterSprite.Direction.RIGHT:
			return CARRIED_OBJECT_RIGHT_OFFSET
		_:
			return CARRIED_OBJECT_FRONT_OFFSET


func get_carried_object_z_index() -> int:
	match player._move_direction:
		CharacterSprite.Direction.UP:
			return CARRIED_OBJECT_BACK_Z
		CharacterSprite.Direction.LEFT, CharacterSprite.Direction.RIGHT:
			return CARRIED_OBJECT_SIDE_Z
		_:
			return CARRIED_OBJECT_FRONT_Z


func apply_sprite_base_z_indexes() -> void:
	if player.sprite_move != null:
		player.sprite_move.z_index = SPRITE_NORMAL_Z
	if player.sprite_idle != null:
		player.sprite_idle.z_index = SPRITE_NORMAL_Z
	if player.sprite_action != null:
		player.sprite_action.z_index = SPRITE_ACTION_FRONT_Z


func apply_carry_sprite_z_index() -> void:
	if player.sprite_action == null:
		return

	player.sprite_action.z_index = SPRITE_ACTION_BACK_Z if player._move_direction == CharacterSprite.Direction.UP else SPRITE_ACTION_FRONT_Z
