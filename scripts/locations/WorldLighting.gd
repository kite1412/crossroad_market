extends CanvasLayer

@export var morning_color: Color = Color(0.12, 0.09, 0.04, 0.18)
@export var day_color: Color = Color(1.0, 0.92, 0.62, 0.06)
@export var night_color: Color = Color(0.03, 0.07, 0.18, 0.42)
@export var transition_time: float = 0.45

@onready var overlay: ColorRect = $Overlay

@warning_ignore("unused_private_class_variable")
var _tween: Tween = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	layer = 1

	if overlay != null:
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if TimeManager.phase_changed.is_connected(_on_phase_changed):
		TimeManager.phase_changed.disconnect(_on_phase_changed)

	TimeManager.phase_changed.connect(_on_phase_changed)
	_apply_phase(TimeManager.current_phase, false)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_phase_changed(phase) -> void:
	_apply_phase(phase, true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_phase(phase, animated: bool) -> void:
	if overlay == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var target_color := _get_phase_color(phase)

	if _tween != null and _tween.is_valid():
		_tween.kill()

	if animated:
		_tween = create_tween()
		_tween.tween_property(overlay, "color", target_color, transition_time)
	else:
		overlay.color = target_color


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_phase_color(phase) -> Color:
	match phase:
		TimeManager.Phase.MORNING:
			return morning_color
		TimeManager.Phase.DAY:
			return day_color
		TimeManager.Phase.NIGHT:
			return night_color

	return day_color
