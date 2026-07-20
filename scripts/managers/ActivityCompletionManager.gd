extends Node


@warning_ignore("unused_signal")
signal activity_completion(message: String)

@warning_ignore("unused_private_class_variable")
var _notifier: ActivityCompletionNotifier = ActivityCompletionNotifier.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_notifier.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func notify(message: String) -> void:
	_notifier.notify(message)
