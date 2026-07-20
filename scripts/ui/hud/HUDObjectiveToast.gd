class_name HUDObjectiveToast
extends RefCounted

var hud: CanvasLayer = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(hud_node: CanvasLayer) -> void:
	hud = hud_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_objective(text: String) -> void:
	if hud.objective_label == null:
		return

	if text == "":
		hide_objective_toast(false)
		return

	hud.objective_label.visible = true
	hud.objective_label.text = "Objective: %s" % text
	hud.objective_label.position = hud._objective_base_position + Vector2(0, 8)
	hud.objective_label.modulate.a = 0.0
	hud._objective_timer = hud.OBJECTIVE_TOAST_DURATION

	if hud._objective_tween != null and hud._objective_tween.is_valid():
		hud._objective_tween.kill()

	hud._objective_tween = hud.create_tween()
	hud._objective_tween.set_parallel(true)
	hud._objective_tween.tween_property(hud.objective_label, "modulate:a", 1.0, hud.OBJECTIVE_ANIM_DURATION)
	hud._objective_tween.tween_property(hud.objective_label, "position", hud._objective_base_position, hud.OBJECTIVE_ANIM_DURATION)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_objective_toast(delta: float) -> void:
	if hud.objective_label == null or not hud.objective_label.visible:
		return

	if hud._objective_timer <= 0.0:
		return

	hud._objective_timer = max(0.0, hud._objective_timer - delta)

	if hud._objective_timer <= 0.0:
		hide_objective_toast(true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_objective_toast(animated: bool) -> void:
	hud._objective_timer = 0.0

	if hud.objective_label == null:
		return

	if hud._objective_tween != null and hud._objective_tween.is_valid():
		hud._objective_tween.kill()
	hud._objective_tween = null

	if not animated:
		hud.objective_label.visible = false
		hud.objective_label.modulate.a = 0.0
		hud.objective_label.position = hud._objective_base_position
		return

	hud._objective_tween = hud.create_tween()
	hud._objective_tween.set_parallel(true)
	hud._objective_tween.tween_property(hud.objective_label, "modulate:a", 0.0, hud.OBJECTIVE_ANIM_DURATION)
	hud._objective_tween.tween_property(
		hud.objective_label,
		"position",
		hud._objective_base_position + Vector2(0, 8),
		hud.OBJECTIVE_ANIM_DURATION
	)
	hud._objective_tween.set_parallel(false)
	hud._objective_tween.tween_callback(func() -> void:
		if hud.objective_label != null:
			hud.objective_label.visible = false
			hud.objective_label.position = hud._objective_base_position
	)
