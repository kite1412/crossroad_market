extends Node

signal activity_completion(message: String)


func _ready() -> void:
	pass # Replace with function body.


func notify(message: String):
	activity_completion.emit(message)
