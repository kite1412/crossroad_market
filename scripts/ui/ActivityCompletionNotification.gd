extends Control

@onready var message: Label = $Panel/Message


func _ready() -> void:
	var store: Store = get_parent().get_parent() as Store # must be the exact position -> Store/CanvasLayer
	
	store.activity_completion.connect(_show_message)


func _show_message(msg: String):
	message.text = msg
	visible = true
	scale = Vector2.ZERO

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
		
	await get_tree().create_timer(2.0).timeout
	_hide()
	
func _hide():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.finished.connect(func():
		visible = false
	)
