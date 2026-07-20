class_name NPCPresentationRuntime
extends RefCounted

const DEBUG_SHELF_FLOW: bool = true

var npc = null
@warning_ignore("unused_private_class_variable")
var _interaction_status: String = ""
@warning_ignore("unused_private_class_variable")
var _pending_dialog_text: String = ""
@warning_ignore("unused_private_class_variable")
var _interaction_target_position: Vector2 = Vector2.INF


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node) -> void:
	npc = npc_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_name_label() -> void:
	NPCVisualController.apply_name_label(npc, npc.npc_data)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_visual() -> void:
	NPCVisualController.apply_visual(npc, npc.npc_data)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup_trust_display() -> void:
	update_trust_display()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var trust_callable := Callable(npc, "_on_trust_changed")

	if should_show_trust_display():
		if not RelationshipManager.trust_changed.is_connected(trust_callable):
			RelationshipManager.trust_changed.connect(trust_callable)
	else:
		disconnect_trust_signal()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func disconnect_trust_signal() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var trust_callable := Callable(npc, "_on_trust_changed")

	if RelationshipManager.trust_changed.is_connected(trust_callable):
		RelationshipManager.trust_changed.disconnect(trust_callable)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func should_show_trust_display() -> bool:
	return (
		npc.npc_data != null
		and npc.npc_data.npc_category == NPCData.NPCCategory.STORY
		and RelationshipManager.is_main_npc(npc.npc_data.npc_id)
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_trust_display() -> void:
	if npc._trust_label == null:
		return

	if not should_show_trust_display():
		npc._trust_label.visible = false
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var trust_value := RelationshipManager.get_trust(npc.npc_data.npc_id)
	npc._trust_label.visible = true
	npc._trust_label.text = "Trust: %d/100" % trust_value


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_trust_changed(npc_id: String, _new_trust: int, _delta: int) -> void:
	if npc.npc_data == null or npc_id != npc.npc_data.npc_id:
		return

	update_trust_display()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_direction(motion: Vector2) -> CharacterSprite.Direction:
	if abs(motion.x) > abs(motion.y):
		return CharacterSprite.Direction.RIGHT if motion.x > 0.0 else CharacterSprite.Direction.LEFT
	return CharacterSprite.Direction.DOWN if motion.y > 0.0 else CharacterSprite.Direction.UP


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func face_target_shelf() -> void:
	if npc._target_shelf == null or not is_instance_valid(npc._target_shelf):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var previous_direction: CharacterSprite.Direction = npc._move_direction
	npc.velocity = Vector2.ZERO
	npc._move_direction = CharacterSprite.Direction.UP if npc.global_position.y >= npc._target_shelf.global_position.y else CharacterSprite.Direction.DOWN
	update_character_sprite()
	pass


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_dialog(text: String) -> void:
	NPCDialogController.show_dialog(npc, npc.npc_data, text)
	npc._dialog_timer = npc.DIALOG_DURATION


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_dialog(delta: float) -> void:
	if npc._dialog_timer <= 0.0:
		return

	npc._dialog_timer -= delta

	if npc._dialog_timer > 0.0:
		return

	hide_dialog()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_dialog() -> void:
	NPCDialogController.hide_dialog(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func suspend_world_presentation() -> void:
	# Dialog bubbles and placeholder controls belong only to the Store world.
	# Clear transient state before visibility snapshots are captured so it cannot
	# leak into Storage/Yard/Home or reappear after returning.
	npc._dialog_timer = 0.0
	npc._interaction_pause_timer = 0.0
	npc._interaction_partner = null
	_interaction_status = ""
	_pending_dialog_text = ""
	_interaction_target_position = Vector2.INF
	hide_dialog()
	_set_placeholder_visible(false)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func resume_world_presentation() -> void:
	# Rebuild presentation from gameplay state instead of trusting a stale
	# transient control state restored by the location transition.
	hide_dialog()
	_set_placeholder_visible(false)
	update_character_sprite()
	update_trust_display()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_placeholder_visible(is_visible: bool) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var placeholder := npc.get_node_or_null("VisualRoot/PlaceholderRect") as CanvasItem
	if placeholder != null:
		placeholder.visible = is_visible


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_dialog_mouse_filter() -> void:
	NPCDialogController.set_mouse_filter(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func skip_dialog() -> bool:
	if npc._dialog_timer <= 0.0:
		return false

	npc._dialog_timer = 0.0
	hide_dialog()
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_npc_interaction(partner: NPC, dialog_text: String, pause_duration: float, target_face_position: Vector2) -> bool:
	if not can_start_npc_interaction():
		return false

	npc._interaction_partner = partner
	npc._interaction_pause_timer = maxf(0.1, pause_duration)
	_pending_dialog_text = dialog_text
	_interaction_target_position = target_face_position
	_interaction_status = "approaching"
	npc.velocity = Vector2.ZERO
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_npc_interaction_pause(delta: float) -> bool:
	if _interaction_status == "" and npc._interaction_pause_timer <= 0.0:
		return false

	if _interaction_status == "approaching":
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var arrived = NPCMovement.move_to(npc, _interaction_target_position, npc.SPEED, npc.ARRIVAL_THRESHOLD)
		update_character_sprite()
		if arrived:
			_interaction_status = "talking"
			npc.velocity = Vector2.ZERO
			show_dialog(_pending_dialog_text)
			if npc._interaction_partner != null and is_instance_valid(npc._interaction_partner):
				apply_face_position(npc._interaction_partner.global_position)
		return true

	npc.velocity = Vector2.ZERO
	npc.move_and_slide()
	npc._interaction_pause_timer -= delta

	if npc._interaction_partner != null and is_instance_valid(npc._interaction_partner):
		apply_face_position(npc._interaction_partner.global_position)

	update_dialog(delta)
	update_character_sprite()

	if npc._interaction_pause_timer <= 0.0:
		npc._interaction_partner = null
		_interaction_status = ""

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_face_position(target_face_position: Vector2) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direction: Vector2 = target_face_position - npc.global_position

	if direction.length() <= 0.1:
		return

	npc._move_direction = get_direction(direction)
	update_character_sprite()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_debug_npc_label() -> String:
	if npc != null and npc.npc_data != null and npc.npc_data.npc_id != "":
		return npc.npc_data.npc_id

	return npc.name if npc != null else "<null>"
