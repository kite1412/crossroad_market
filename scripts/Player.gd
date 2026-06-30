extends CharacterBody2D

const SPEED = 150.0

func _physics_process(_delta: float) -> void:
	# get_vector() sudah otomatis melakukan normalization
	# sehingga gerak diagonal tidak lebih cepat dari cardinal
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	move_and_slide()
