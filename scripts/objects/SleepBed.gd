class_name SleepBed
extends Area2D

const SleepBedFlow = preload("res://scripts/objects/sleep/SleepBedFlow.gd")

const FADE_DURATION: float = 2.0

var _sleep_flow: SleepBedFlow = SleepBedFlow.new()


func _ready() -> void:
	_sleep_flow.setup(self)
	input_pickable = true


func get_hover_display_name() -> String:
	return "Bed"


func request_interaction() -> bool:
	return _sleep_flow.request_interaction()


func _play_sleep_transition() -> void:
	await _sleep_flow.play_sleep_transition()


func _get_fade_overlay() -> ColorRect:
	return _sleep_flow.get_fade_overlay()


func _show_notification(text: String, duration: float) -> void:
	_sleep_flow.show_notification(text, duration)
