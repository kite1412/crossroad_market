class_name NpcFeedbackBoard
extends StaticBody2D


const PANEL_SIZE := Vector2(320, 200)
const MOCK_FEEDBACKS: Array = [
	{"npc": "Gooby", "text": "Love the selection! Always find something fun here.", "mood": "Happy"},
	{"npc": "Irene", "text": "The prices are fair for the quality. I'll be back tomorrow.", "mood": "Satisfied"},
	{"npc": "Herbalist", "text": "Wish you carried more rare herbs. The common ones are okay though.", "mood": "Neutral"},
	{"npc": "Blacksmith", "text": "Your stock is improving. Keep bringing in better materials.", "mood": "Neutral"},
	{"npc": "Mayor", "text": "A fine establishment. The town is lucky to have this shop.", "mood": "Happy"},
	{"npc": "Random Customer", "text": "I couldn't find what I needed today. Maybe next time!", "mood": "Disappointed"},
	{"npc": "Random Customer", "text": "Great variety! Bought exactly what I came for.", "mood": "Happy"},
	{"npc": "Gooby", "text": "The ghost shelf had some neat stuff. Spooky but cool!", "mood": "Happy"},
	{"npc": "Irene", "text": "Service was quick today. Much better than yesterday.", "mood": "Satisfied"},
	{"npc": "Random Customer", "text": "The store feels cozy. I like browsing here.", "mood": "Happy"},
	{"npc": "Herbalist", "text": "Found a rare blossom today! Excellent find.", "mood": "Happy"},
	{"npc": "Blacksmith", "text": "Ore quality was top-notch this morning.", "mood": "Satisfied"},
]


@warning_ignore("unused_private_class_variable")
var _board_layer: CanvasLayer = null
@warning_ignore("unused_private_class_variable")
var _board_panel: ColorRect = null
@warning_ignore("unused_private_class_variable")
var _is_open: bool = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	pass


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _exit_tree() -> void:
	_hide_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_hover_display_name() -> String:
	return "Feedback Board"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_interaction() -> void:
	if _board_panel != null and _board_panel.visible:
		_hide_panel()
		return

	_show_feedback_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _unhandled_input(event: InputEvent) -> void:
	if _board_panel == null or not _board_panel.visible:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_hide_panel()
			get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
		_hide_panel()
		get_viewport().set_input_as_handled()


func _show_feedback_panel() -> void:
	_ensure_panel()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var content := _board_panel.get_node("Content") as VBoxContainer
	_clear_container(content)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var title_label := Label.new()
	title_label.text = "Customer Feedback Board"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 13)
	content.add_child(title_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var separator := HSeparator.new()
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(separator)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var scroll := ScrollContainer.new()
	scroll.name = "FeedbackScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var feedback_container := VBoxContainer.new()
	feedback_container.name = "Feedbacks"
	feedback_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_container.add_theme_constant_override("separation", 8)
	scroll.add_child(feedback_container)

	for feedback in MOCK_FEEDBACKS:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var entry := VBoxContainer.new()
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		feedback_container.add_child(entry)

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var header := HBoxContainer.new()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_child(header)

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var npc_label := Label.new()
		npc_label.text = feedback["npc"]
		npc_label.add_theme_font_size_override("font_size", 10)
		npc_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		header.add_child(npc_label)

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var mood_label := Label.new()
		mood_label.text = "  [%s]" % feedback["mood"]
		mood_label.add_theme_font_size_override("font_size", 9)
		mood_label.modulate = _get_mood_color(feedback["mood"])
		header.add_child(mood_label)

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var text_label := Label.new()
		text_label.text = '"%s"' % feedback["text"]
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_label.add_theme_font_size_override("font_size", 9)
		text_label.modulate = Color(1.0, 0.95, 0.88, 0.9)
		entry.add_child(text_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hint_label := Label.new()
	hint_label.text = "Esc / Right Click to close"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 8)
	hint_label.modulate = Color(1.0, 0.92, 0.72, 0.6)
	content.add_child(hint_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_hide_panel)
	content.add_child(close_button)

	_lock_player_actions()
	_board_panel.visible = true
	_is_open = true


func _ensure_panel() -> void:
	if _board_layer != null and is_instance_valid(_board_layer):
		return

	_board_layer = CanvasLayer.new()
	_board_layer.name = "NpcFeedbackBoardLayer"
	_board_layer.layer = 18
	add_child(_board_layer)

	_board_panel = ColorRect.new()
	_board_panel.name = "NpcFeedbackBoardPanel"
	_board_panel.color = Color(0.12, 0.09, 0.06, 0.95)
	_board_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_board_panel.custom_minimum_size = PANEL_SIZE
	_board_panel.offset_left = -PANEL_SIZE.x * 0.5
	_board_panel.offset_top = -PANEL_SIZE.y * 0.5
	_board_panel.offset_right = PANEL_SIZE.x * 0.5
	_board_panel.offset_bottom = PANEL_SIZE.y * 0.5
	_board_panel.visible = false
	_board_layer.add_child(_board_panel)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 12.0
	content.offset_top = 10.0
	content.offset_right = -12.0
	content.offset_bottom = -10.0
	content.add_theme_constant_override("separation", 5)
	_board_panel.add_child(content)


func _hide_panel() -> void:
	if _board_panel != null:
		_board_panel.visible = false

	_is_open = false
	_unlock_player_actions()


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _lock_player_actions() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("lock_actions"):
		hud.call("lock_actions")


func _unlock_player_actions() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("unlock_actions"):
		hud.call("unlock_actions")


func _get_mood_color(mood: String) -> Color:
	match mood:
		"Happy":
			return Color(0.55, 1.0, 0.55, 1.0)
		"Satisfied":
			return Color(0.6, 0.85, 1.0, 1.0)
		"Neutral":
			return Color(1.0, 1.0, 0.7, 1.0)
		"Disappointed":
			return Color(1.0, 0.6, 0.5, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 0.8)
