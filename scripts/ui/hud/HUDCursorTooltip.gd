class_name HUDCursorTooltip
extends RefCounted

var hud: CanvasLayer = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(hud_node: CanvasLayer) -> void:
	hud = hud_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_cursor_tooltip(text: String) -> void:
	if text == "" or hud._has_interactive_overlay_open():
		return

	if hud._cursor_tooltip == null or hud._cursor_tooltip_label == null:
		create_cursor_tooltip()

	if hud._cursor_tooltip_tween != null and hud._cursor_tooltip_tween.is_valid():
		hud._cursor_tooltip_tween.kill()
	hud._cursor_tooltip_tween = null

	if hud._cursor_tooltip_text != text:
		hud._cursor_tooltip_text = text
		hud._cursor_tooltip_label.text = text
		hud._cursor_tooltip_label.reset_size()
		hud._cursor_tooltip.size = hud._cursor_tooltip_label.get_minimum_size() + hud.CURSOR_TOOLTIP_PADDING
		hud._cursor_tooltip_label.position = hud.CURSOR_TOOLTIP_PADDING * 0.5

	update_cursor_tooltip_position()

	hud._cursor_tooltip.visible = true
	hud._cursor_tooltip_visible = true
	hud._cursor_tooltip.modulate.a = 1.0
	hud._cursor_tooltip.scale = Vector2.ONE


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_cursor_tooltip() -> void:
	if hud._cursor_tooltip == null:
		return

	if hud._cursor_tooltip_tween != null and hud._cursor_tooltip_tween.is_valid():
		hud._cursor_tooltip_tween.kill()
	hud._cursor_tooltip_tween = null

	hud._cursor_tooltip_visible = false
	hud._cursor_tooltip_text = ""
	hud._cursor_tooltip.visible = false
	hud._cursor_tooltip.modulate.a = 0.0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_cursor_hover_tooltip() -> void:
	if hud._has_interactive_overlay_open():
		hide_cursor_tooltip()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hover_text := get_cursor_world_hover_text()

	if hover_text != "":
		show_cursor_tooltip(hover_text)
	elif hud._cursor_tooltip_visible:
		hide_cursor_tooltip()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cursor_world_hover_text() -> String:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var viewport := hud.get_viewport()

	if viewport == null:
		return ""

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var world_2d := viewport.world_2d

	if world_2d == null:
		return ""

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
	query.collide_with_areas = true
	query.collide_with_bodies = false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hits := world_2d.direct_space_state.intersect_point(query, hud.CURSOR_HOVER_QUERY_LIMIT)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_text := ""
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_priority := 999

	for hit in hits:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var collider: Variant = hit.get("collider", null)

		if not (collider is Area2D):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var area := collider as Area2D
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var candidate := get_hover_candidate_from_area(area)

		if candidate.is_empty():
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var priority := int(candidate.get("priority", 999))

		if priority < best_priority:
			best_priority = priority
			best_text = str(candidate.get("text", ""))

	return best_text


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_hover_candidate_from_area(area: Area2D) -> Dictionary:
	if area == null:
		return {}

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shelf_slot_candidate := get_shelf_slot_hover_candidate(area)

	if not shelf_slot_candidate.is_empty():
		return shelf_slot_candidate

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var door_text := get_door_hover_text(area)

	if door_text != "":
		return {
			"text": door_text,
			"priority": 10
		}

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var current: Node = area

	while current != null and current != hud and current != hud.get_tree().root:
		if current.has_method("get_hover_display_name"):
			return {
				"text": str(current.call("get_hover_display_name")),
				"priority": get_hover_target_priority(current)
			}

		if current is Cashier:
			return {
				"text": "Cashier",
				"priority": 20
			}

		if current is ActivityBoard:
			return {
				"text": "Activity Board",
				"priority": 30
			}

		current = current.get_parent()

	return {}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_slot_hover_candidate(area: Area2D) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var slot_node := area.get_parent()

	if slot_node == null:
		return {}

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var slot_name := String(slot_node.name)

	if not slot_name.begins_with("Slot"):
		return {}

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var slot_index := int(slot_name.trim_prefix("Slot"))
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var current := slot_node.get_parent()

	while current != null and current != hud.get_tree().root:
		if current is Shelf:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var shelf := current as Shelf
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var text := ""

			if shelf.has_method("_get_slot_hover_name"):
				text = str(shelf.call("_get_slot_hover_name", slot_index))
			elif shelf.has_method("get_hover_display_name"):
				text = str(shelf.call("get_hover_display_name"))

			if text == "":
				return {}

			return {
				"text": text,
				"priority": 4
			}

		current = current.get_parent()

	return {}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_door_hover_text(area: Area2D) -> String:
	if not area.has_meta("door_type"):
		return ""

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var door_type := str(area.get_meta("door_type"))

	if door_type == "storage":
		return "Storage Door"

	if door_type == "yard":
		return "Yard Door"

	if door_type.ends_with("_return") or door_type == "return":
		return "Store Door"

	return ""


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_hover_target_priority(target: Node) -> int:
	if target is Shelf:
		return 5

	if target is SupplyBox:
		return 15

	return 50


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_cursor_tooltip() -> void:
	if hud._cursor_tooltip != null:
		return

	hud._cursor_tooltip = ColorRect.new()
	hud._cursor_tooltip.name = "CursorNameTooltip"
	hud._cursor_tooltip.color = Color(0.05, 0.045, 0.035, 0.94)
	hud._cursor_tooltip.visible = false
	hud._cursor_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud._cursor_tooltip)

	hud._cursor_tooltip_label = Label.new()
	hud._cursor_tooltip_label.name = "TooltipLabel"
	hud._cursor_tooltip_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.82, 1.0))
	hud._cursor_tooltip_label.add_theme_font_size_override("font_size", 9)
	hud._cursor_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._cursor_tooltip.add_child(hud._cursor_tooltip_label)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_cursor_tooltip_position() -> void:
	if hud._cursor_tooltip == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var viewport_size := hud.get_viewport().get_visible_rect().size
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tooltip_position: Vector2 = hud.get_viewport().get_mouse_position() + hud.CURSOR_TOOLTIP_OFFSET
	tooltip_position.x = min(tooltip_position.x, viewport_size.x - hud._cursor_tooltip.size.x - 4.0)
	tooltip_position.y = min(tooltip_position.y, viewport_size.y - hud._cursor_tooltip.size.y - 4.0)
	tooltip_position.x = max(4.0, tooltip_position.x)
	tooltip_position.y = max(4.0, tooltip_position.y)
	hud._cursor_tooltip.position = tooltip_position
