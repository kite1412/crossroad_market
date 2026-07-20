class_name SleepBed
extends Area2D


const FADE_DURATION: float = 2.0

@warning_ignore("unused_private_class_variable")
var _sleep_flow: SleepBedFlow = SleepBedFlow.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_sleep_flow.setup(self)
	input_pickable = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_hover_display_name() -> String:
	return "Bed"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_interaction() -> bool:
	return _sleep_flow.request_interaction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _play_sleep_transition() -> void:
	await _sleep_flow.play_sleep_transition()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_fade_overlay() -> ColorRect:
	return _sleep_flow.get_fade_overlay()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_notification(text: String, duration: float) -> void:
	_sleep_flow.show_notification(text, duration)
