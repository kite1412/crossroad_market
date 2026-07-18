extends Node

const ActivityCompletionNotifier = preload("res://scripts/managers/activity/ActivityCompletionNotifier.gd")

signal activity_completion(message: String)

var _notifier: ActivityCompletionNotifier = ActivityCompletionNotifier.new()


func _ready() -> void:
	_notifier.setup(self)


func notify(message: String) -> void:
	_notifier.notify(message)
