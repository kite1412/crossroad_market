class_name NPCPresentationRuntime
extends RefCounted

const DEBUG_SHELF_FLOW: bool = true

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

	var previous_direction: CharacterSprite.Direction = npc._move_direction
	npc.velocity = Vector2.ZERO
	npc._move_direction = CharacterSprite.Direction.UP if npc.global_position.y >= npc._target_shelf.global_position.y else CharacterSprite.Direction.DOWN
	update_character_sprite()
	print_face_target_shelf_debug(previous_direction)


func print_face_target_shelf_debug(previous_direction: CharacterSprite.Direction) -> void:
	if not DEBUG_SHELF_FLOW:
		return

	print(
		"[DEBUG][SHELF_FLOW] stage=face_target_shelf npc=%s shelf=%s npc_pos=%s shelf_pos=%s previous_direction=%s new_direction=%s access_side=%s target_pos=%s" % [
			_get_debug_npc_label(),
			npc._target_shelf.name if npc._target_shelf != null else "<null>",
			str(npc.global_position),
			str(npc._target_shelf.global_position if npc._target_shelf != null else Vector2.INF),
			str(previous_direction),
			str(npc._move_direction),
			str(npc._target_shelf.get_meta(&"npc_access_side") if npc._target_shelf != null and npc._target_shelf.has_meta(&"npc_access_side") else ""),
			str(npc.target_position)
		]
	)


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


func request_npc_interaction(partner: NPC, dialog_text: String, pause_duration: float, target_face_position: Vector2) -> bool:
	if not can_start_npc_interaction():
		return false

	npc._interaction_partner = partner
	npc._interaction_pause_timer = maxf(0.1, pause_duration)
	npc.velocity = Vector2.ZERO
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	apply_face_position(target_face_position)
	show_dialog(dialog_text)
	return true


func process_npc_interaction_pause(delta: float) -> bool:
	if npc._interaction_pause_timer <= 0.0:
		return false

	npc.velocity = Vector2.ZERO
	npc.move_and_slide()
	npc._interaction_pause_timer -= delta

	if npc._interaction_partner != null and is_instance_valid(npc._interaction_partner):
		apply_face_position(npc._interaction_partner.global_position)

	update_dialog(delta)
	update_character_sprite()

	if npc._interaction_pause_timer <= 0.0:
		npc._interaction_partner = null

	return true


func can_start_npc_interaction() -> bool:
	if npc.npc_data == null:
		return false

	if npc.npc_data.npc_category != NPCData.NPCCategory.GENERIC:
		return false

	if npc._dialog_timer > 0.0 or npc._interaction_pause_timer > 0.0:
		return false

	return npc.current_state in [
		NPC.State.ENTER,
		NPC.State.WALK_TO_SHELF,
		NPC.State.SEARCH_ITEM,
		NPC.State.BROWSE_ITEM,
		NPC.State.TAKE_ITEM
	]


func apply_face_position(target_face_position: Vector2) -> void:
	var direction: Vector2 = target_face_position - npc.global_position

	if direction.length() <= 0.1:
		return

	npc._move_direction = get_direction(direction)
	update_character_sprite()


func _get_debug_npc_label() -> String:
	if npc != null and npc.npc_data != null and npc.npc_data.npc_id != "":
		return npc.npc_data.npc_id

	return npc.name if npc != null else "<null>"
