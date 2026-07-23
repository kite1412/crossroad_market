class_name Dialog
extends Control

const PORTRAIT_PANEL_OVERLAP: float = 2.0

## Reusable story dialog overlay.
##
## Assign `character_name`, `content`, and `portrait` in the inspector, or use
## `show_dialog()` when creating the scene from code. Portraits can be a
## single image or a horizontal six-frame animation strip.

@warning_ignore("unused_signal")
signal next_requested
@warning_ignore("unused_signal")
signal dialog_finished

@export_category("Dialog")
@export var character_name: String = "Gooby"
@export_multiline var content: String = "I want Phantom Ice Cream Boo..."
@export var next_text: String = "Next..."

@export_category("Portrait")
@export var portrait: Texture2D
@export_range(0, 32, 1) var portrait_frame: int = 0

@export_category("Behavior")
@export var close_on_next: bool = false
@export var close_on_escape: bool = false

@onready var portrait_view: PortraitAnimation = $Portrait
@onready var dialog_panel: Panel = $DialogPanel
@onready var name_label: Label = $DialogPanel/NameLabel
@onready var content_label: RichTextLabel = $DialogPanel/ContentLabel
@onready var next_button: Button = $DialogPanel/NextButton


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_button.pressed.connect(_on_next_pressed)
	resized.connect(_layout_portrait)
	_apply_dialog()
	call_deferred("_layout_portrait")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return

	if event is InputEventKey:
		if event.is_echo():
			return
		if event.keycode == KEY_ESCAPE and close_on_escape:
			hide_dialog()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_on_next_pressed()
			get_viewport().set_input_as_handled()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
@warning_ignore("unused_parameter")
func show_dialog(
		dialogue_name: String,
		dialogue_content: String,
		dialogue_portrait: Texture2D = null,
		frame: int = 0
	) -> void:
	character_name = dialogue_name
	content = dialogue_content
	portrait = dialogue_portrait
	portrait_frame = frame
	_apply_dialog()
	show()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_dialog() -> void:
	hide()
	dialog_finished.emit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_portrait_frame(frame: int) -> void:
	portrait_frame = max(frame, 0)
	_update_portrait()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_dialog() -> void:
	if not is_node_ready():
		return

	name_label.text = character_name
	content_label.text = content
	content_label.scroll_to_line(0)
	content_label.add_theme_font_size_override("normal_font_size", 9)
	next_button.text = next_text
	_update_portrait()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_portrait() -> void:
	if portrait == null:
		portrait_view.set_portrait(null)
		portrait_view.visible = false
		return

	portrait_view.visible = true
	portrait_view.set_portrait(portrait, portrait_frame)
	_layout_portrait()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _layout_portrait() -> void:
	if portrait_view == null or dialog_panel == null:
		return

	portrait_view.anchor_left = 0.0
	portrait_view.anchor_top = 0.0
	portrait_view.anchor_right = 0.0
	portrait_view.anchor_bottom = 0.0
	portrait_view.position = Vector2(
		dialog_panel.position.x + dialog_panel.size.x - portrait_view.size.x,
		dialog_panel.position.y - portrait_view.size.y + PORTRAIT_PANEL_OVERLAP
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_next_pressed() -> void:
	next_requested.emit()
	if close_on_next:
		hide_dialog()
