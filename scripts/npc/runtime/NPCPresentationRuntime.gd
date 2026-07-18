class_name NPCPresentationRuntime
extends RefCounted

var npc = null


func setup(npc_node) -> void:
	npc = npc_node


func apply_name_label() -> void:
	NPCVisualController.apply_name_label(npc, npc.npc_data)


func apply_visual() -> void:
	NPCVisualController.apply_visual(npc, npc.npc_data)


func setup_trust_display() -> void:
	update_trust_display()

	var trust_callable := Callable(npc, "_on_trust_changed")

	if should_show_trust_display():
		if not RelationshipManager.trust_changed.is_connected(trust_callable):
			RelationshipManager.trust_changed.connect(trust_callable)
	else:
		disconnect_trust_signal()


func disconnect_trust_signal() -> void:
	var trust_callable := Callable(npc, "_on_trust_changed")

	if RelationshipManager.trust_changed.is_connected(trust_callable):
		RelationshipManager.trust_changed.disconnect(trust_callable)


func should_show_trust_display() -> bool:
	return (
		npc.npc_data != null
		and npc.npc_data.npc_category == NPCData.NPCCategory.STORY
		and npc.npc_data.npc_id != ""
	)


func update_trust_display() -> void:
	if npc._trust_label == null:
		return

	if not should_show_trust_display():
		npc._trust_label.visible = false
		return

	var trust_value := RelationshipManager.get_trust(npc.npc_data.npc_id)
	npc._trust_label.visible = true
	npc._trust_label.text = "Trust: %d/100" % trust_value


func on_trust_changed(npc_id: String, _new_trust: int, _delta: int) -> void:
	if npc.npc_data == null or npc_id != npc.npc_data.npc_id:
		return

	update_trust_display()


func update_character_sprite() -> void:
	if npc.sprite_idle == null or npc.sprite_move == null:
		return

	if npc.velocity == Vector2.ZERO:
		npc.sprite_move.visible = false
		npc.sprite_idle.visible = true
		npc.sprite_idle.play_direction_loop(npc._move_direction)
		return

	npc.sprite_idle.visible = false
	npc.sprite_move.visible = true
	npc.sprite_move.apply_motion_vector(npc.velocity)
	npc._move_direction = get_direction(npc.velocity)


func get_direction(motion: Vector2) -> CharacterSprite.Direction:
	if abs(motion.x) > abs(motion.y):
		return CharacterSprite.Direction.RIGHT if motion.x > 0.0 else CharacterSprite.Direction.LEFT
	return CharacterSprite.Direction.DOWN if motion.y > 0.0 else CharacterSprite.Direction.UP


func face_target_shelf() -> void:
	if npc._target_shelf == null or not is_instance_valid(npc._target_shelf):
		return

	npc.velocity = Vector2.ZERO
	npc._move_direction = CharacterSprite.Direction.UP if npc.global_position.y >= npc._target_shelf.global_position.y else CharacterSprite.Direction.DOWN
	update_character_sprite()


func show_dialog(text: String) -> void:
	NPCDialogController.show_dialog(npc, npc.npc_data, text)
	npc._dialog_timer = npc.DIALOG_DURATION


func update_dialog(delta: float) -> void:
	if npc._dialog_timer <= 0.0:
		return

	npc._dialog_timer -= delta

	if npc._dialog_timer > 0.0:
		return

	hide_dialog()


func hide_dialog() -> void:
	NPCDialogController.hide_dialog(npc)


func set_dialog_mouse_filter() -> void:
	NPCDialogController.set_mouse_filter(npc)


func skip_dialog() -> bool:
	if npc._dialog_timer <= 0.0:
		return false

	npc._dialog_timer = 0.0
	hide_dialog()
	return true
