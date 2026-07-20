class_name StorePresentation
extends Node


const LOCATION_TITLE_DURATION: float = 1.25

var store: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store_node: Node) -> void:
	store = store_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_fade_layer() -> void:
	if store == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fade_nodes := StoreTransitionController.create_fade_layer(store)
	store._fade_layer = fade_nodes["layer"] as CanvasLayer
	store._fade_rect = fade_nodes["rect"] as ColorRect


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_location_title_layer() -> void:
	if store == null:
		return

	store._location_title_layer = CanvasLayer.new()
	store._location_title_layer.name = "LocationTitleLayer"
	store._location_title_layer.layer = 24
	store.add_child(store._location_title_layer)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var panel := ColorRect.new()
	panel.name = "LocationTitlePanel"
	panel.color = Color(0.06, 0.05, 0.05, 0.72)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -88.0
	panel.offset_top = -18.0
	panel.offset_right = 88.0
	panel.offset_bottom = 18.0
	panel.modulate.a = 0.0
	store._location_title_layer.add_child(panel)

	store._location_title_label = Label.new()
	store._location_title_label.name = "LocationTitleLabel"
	store._location_title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	store._location_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	store._location_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	store._location_title_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(store._location_title_label)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_location_title_once(location_key: String, title: String) -> void:
	if store == null:
		return

	if store._shown_location_titles.has(location_key):
		return

	store._shown_location_titles[location_key] = true
	show_location_title(title)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_location_title(title: String) -> void:
	if store == null:
		return

	if store._location_title_layer == null or store._location_title_label == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var panel := store._location_title_label.get_parent() as Control

	if panel == null:
		return

	if store._location_title_tween != null and store._location_title_tween.is_valid():
		store._location_title_tween.kill()

	store._location_title_label.text = title
	panel.visible = true
	panel.modulate.a = 0.0
	panel.position.y = 8.0

	store._location_title_tween = store.create_tween()
	store._location_title_tween.set_parallel(true)
	store._location_title_tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	store._location_title_tween.tween_property(panel, "position:y", 0.0, 0.18)
	store._location_title_tween.set_parallel(false)
	store._location_title_tween.tween_interval(LOCATION_TITLE_DURATION)
	store._location_title_tween.tween_property(panel, "modulate:a", 0.0, 0.28)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func fade_to_black() -> void:
	if store == null:
		return

	await StoreTransitionController.fade_to(store, store._fade_rect, 1.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func fade_from_black() -> void:
	if store == null:
		return

	await StoreTransitionController.fade_to(store, store._fade_rect, 0.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func connect_cursor_tooltip(area: Area2D, tooltip_text: String) -> void:
	if area == null:
		return

	area.input_pickable = true
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var entered := Callable(self, "_on_cursor_tooltip_entered").bind(tooltip_text)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var exited := Callable(self, "_on_cursor_tooltip_exited")

	if not area.mouse_entered.is_connected(entered):
		area.mouse_entered.connect(entered)

	if not area.mouse_exited.is_connected(exited):
		area.mouse_exited.connect(exited)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_notification(text: String, duration: float = 2.0) -> void:
	if store != null:
		StoreNotificationBridge.show(store.get_tree(), text, duration)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_passive_notification(text: String, duration: float = 2.0, instant_text: bool = false) -> void:
	if store != null:
		StoreNotificationBridge.show(store.get_tree(), text, duration, false, instant_text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_status_notification(text: String, duration: float = 1.0) -> void:
	if store != null:
		StoreNotificationBridge.show(store.get_tree(), text, duration, false)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_notification_sequence(messages: Array[String]) -> void:
	if store != null:
		await StoreNotificationBridge.show_sequence(store, messages)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cursor_tooltip_entered(tooltip_text: String) -> void:
	if store == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := store.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_cursor_tooltip"):
		hud.call("show_cursor_tooltip", tooltip_text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cursor_tooltip_exited() -> void:
	if store == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := store.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_cursor_tooltip"):
		hud.call("hide_cursor_tooltip")
