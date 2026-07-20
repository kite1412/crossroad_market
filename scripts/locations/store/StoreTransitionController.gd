class_name StoreTransitionController
extends RefCounted


static func prepare_player_for_location(
	player: Node2D,
	new_parent: Node,
	spawn_position: Vector2,
	z_index_value: int = 0
) -> void:
	if player == null or new_parent == null:
		return

	player.reparent(new_parent, true)
	player.visible = true
	player.set_process(true)
	player.set_physics_process(true)
	player.set_process_input(true)
	player.set_process_unhandled_input(true)
	player.z_index = z_index_value
	player.global_position = spawn_position
	_reset_player_camera(player)


static func _reset_player_camera(player: Node2D) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		return

	if camera.has_method("reset_smoothing"):
		camera.call("reset_smoothing")

	if camera.has_method("force_update_scroll"):
		camera.call("force_update_scroll")


static func create_fade_layer(owner: Node) -> Dictionary:
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "FadeLayer"
	fade_layer.layer = 1000
	owner.add_child(fade_layer)

	var fade_rect := ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)

	return {
		"layer": fade_layer,
		"rect": fade_rect
	}


static func fade_to(owner: Node, fade_rect: ColorRect, target_alpha: float, duration: float = 0.35) -> void:
	if owner == null or fade_rect == null:
		return

	var tween := owner.create_tween()
	tween.tween_property(fade_rect, "modulate:a", target_alpha, duration)
	await tween.finished


static func set_node_active_recursive(node: Node, is_active: bool) -> void:
	if node == null:
		return

	if node is CanvasItem:
		var canvas_item := node as CanvasItem

		if is_active:
			# Only restore CanvasItems that were actually suspended. A node may be
			# created while the Store world is inactive, and forcing that node visible
			# would reveal intentionally hidden controls such as NPC placeholders and
			# dialog bubbles.
			if canvas_item.has_meta("_world_active_was_visible"):
				canvas_item.visible = bool(canvas_item.get_meta("_world_active_was_visible"))
				canvas_item.remove_meta("_world_active_was_visible")
		else:
			canvas_item.set_meta("_world_active_was_visible", canvas_item.visible)
			canvas_item.visible = false

	if node is Area2D:
		var area := node as Area2D
		area.monitoring = is_active
		area.monitorable = is_active

	if node is CollisionShape2D:
		var collision_shape := node as CollisionShape2D

		if is_active:
			if collision_shape.has_meta("_world_active_was_disabled"):
				collision_shape.disabled = bool(collision_shape.get_meta("_world_active_was_disabled"))
				collision_shape.remove_meta("_world_active_was_disabled")
			else:
				collision_shape.disabled = false
		else:
			collision_shape.set_meta("_world_active_was_disabled", collision_shape.disabled)
			collision_shape.disabled = true

	if node is CollisionPolygon2D:
		var collision_polygon := node as CollisionPolygon2D

		if is_active:
			if collision_polygon.has_meta("_world_active_was_disabled"):
				collision_polygon.disabled = bool(collision_polygon.get_meta("_world_active_was_disabled"))
				collision_polygon.remove_meta("_world_active_was_disabled")
			else:
				collision_polygon.disabled = false
		else:
			collision_polygon.set_meta("_world_active_was_disabled", collision_polygon.disabled)
			collision_polygon.disabled = true

	node.set_process(is_active)
	node.set_physics_process(is_active)
	node.set_process_input(is_active)
	node.set_process_unhandled_input(is_active)

	for child in node.get_children():
		set_node_active_recursive(child, is_active)


static func set_node_enabled_recursive(node: Node, enabled: bool) -> void:
	if node == null:
		return

	if node is CollisionShape2D:
		(node as CollisionShape2D).disabled = not enabled

	if node is CollisionPolygon2D:
		(node as CollisionPolygon2D).disabled = not enabled

	if node is Area2D:
		var area := node as Area2D
		area.monitoring = enabled
		area.monitorable = enabled

	for child in node.get_children():
		set_node_enabled_recursive(child, enabled)
