class_name StoreTransitionController
extends RefCounted

const META_VISIBLE: StringName = &"_world_active_was_visible"
const META_MONITORING: StringName = &"_world_active_was_monitoring"
const META_MONITORABLE: StringName = &"_world_active_was_monitorable"
const META_COLLISION_DISABLED: StringName = &"_world_active_was_disabled"
const META_PROCESS: StringName = &"_world_active_was_processing"
const META_PHYSICS_PROCESS: StringName = &"_world_active_was_physics_processing"
const META_INPUT_PROCESS: StringName = &"_world_active_was_input_processing"
const META_UNHANDLED_INPUT_PROCESS: StringName = &"_world_active_was_unhandled_input_processing"


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
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var camera := player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		return

	if camera.has_method("reset_smoothing"):
		camera.call("reset_smoothing")

	if camera.has_method("force_update_scroll"):
		camera.call("force_update_scroll")


static func create_fade_layer(owner: Node) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "FadeLayer"
	fade_layer.layer = 1000
	owner.add_child(fade_layer)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
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

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tween := owner.create_tween()
	tween.tween_property(fade_rect, "modulate:a", target_alpha, duration)
	await tween.finished


static func set_node_active_recursive(node: Node, is_active: bool) -> void:
	if node == null:
		return

	_restore_or_suspend_canvas_item(node, is_active)
	_restore_or_suspend_area(node, is_active)
	_restore_or_suspend_collision(node, is_active)
	_restore_or_suspend_processing(node, is_active)

	for child in node.get_children():
		set_node_active_recursive(child, is_active)


static func _restore_or_suspend_canvas_item(node: Node, is_active: bool) -> void:
	if not node is CanvasItem:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var canvas_item := node as CanvasItem
	if is_active:
		if canvas_item.has_meta(META_VISIBLE):
			canvas_item.visible = bool(canvas_item.get_meta(META_VISIBLE))
			canvas_item.remove_meta(META_VISIBLE)
		return

	canvas_item.set_meta(META_VISIBLE, canvas_item.visible)
	canvas_item.visible = false


static func _restore_or_suspend_area(node: Node, is_active: bool) -> void:
	if not node is Area2D:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var area := node as Area2D
	if is_active:
		if area.has_meta(META_MONITORING):
			area.monitoring = bool(area.get_meta(META_MONITORING))
			area.remove_meta(META_MONITORING)
		if area.has_meta(META_MONITORABLE):
			area.monitorable = bool(area.get_meta(META_MONITORABLE))
			area.remove_meta(META_MONITORABLE)
		return

	area.set_meta(META_MONITORING, area.monitoring)
	area.set_meta(META_MONITORABLE, area.monitorable)
	area.monitoring = false
	area.monitorable = false


static func _restore_or_suspend_collision(node: Node, is_active: bool) -> void:
	if node is CollisionShape2D:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var collision_shape := node as CollisionShape2D
		if is_active:
			if collision_shape.has_meta(META_COLLISION_DISABLED):
				collision_shape.disabled = bool(collision_shape.get_meta(META_COLLISION_DISABLED))
				collision_shape.remove_meta(META_COLLISION_DISABLED)
		else:
			collision_shape.set_meta(META_COLLISION_DISABLED, collision_shape.disabled)
			collision_shape.disabled = true
		return

	if node is CollisionPolygon2D:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var collision_polygon := node as CollisionPolygon2D
		if is_active:
			if collision_polygon.has_meta(META_COLLISION_DISABLED):
				collision_polygon.disabled = bool(collision_polygon.get_meta(META_COLLISION_DISABLED))
				collision_polygon.remove_meta(META_COLLISION_DISABLED)
		else:
			collision_polygon.set_meta(META_COLLISION_DISABLED, collision_polygon.disabled)
			collision_polygon.disabled = true


static func _restore_or_suspend_processing(node: Node, is_active: bool) -> void:
	if is_active:
		if node.has_meta(META_PROCESS):
			node.set_process(bool(node.get_meta(META_PROCESS)))
			node.remove_meta(META_PROCESS)
		if node.has_meta(META_PHYSICS_PROCESS):
			node.set_physics_process(bool(node.get_meta(META_PHYSICS_PROCESS)))
			node.remove_meta(META_PHYSICS_PROCESS)
		if node.has_meta(META_INPUT_PROCESS):
			node.set_process_input(bool(node.get_meta(META_INPUT_PROCESS)))
			node.remove_meta(META_INPUT_PROCESS)
		if node.has_meta(META_UNHANDLED_INPUT_PROCESS):
			node.set_process_unhandled_input(bool(node.get_meta(META_UNHANDLED_INPUT_PROCESS)))
			node.remove_meta(META_UNHANDLED_INPUT_PROCESS)
		return

	node.set_meta(META_PROCESS, node.is_processing())
	node.set_meta(META_PHYSICS_PROCESS, node.is_physics_processing())
	node.set_meta(META_INPUT_PROCESS, node.is_processing_input())
	node.set_meta(META_UNHANDLED_INPUT_PROCESS, node.is_processing_unhandled_input())
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)


static func set_node_enabled_recursive(node: Node, enabled: bool) -> void:
	if node == null:
		return

	if node is CollisionShape2D:
		(node as CollisionShape2D).disabled = not enabled

	if node is CollisionPolygon2D:
		(node as CollisionPolygon2D).disabled = not enabled

	if node is Area2D:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var area := node as Area2D
		area.monitoring = enabled
		area.monitorable = enabled

	for child in node.get_children():
		set_node_enabled_recursive(child, enabled)
