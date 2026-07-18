class_name HUDStatusLabels
extends RefCounted

var hud: CanvasLayer = null


func setup(hud_node: CanvasLayer) -> void:
	hud = hud_node


func update_all() -> void:
	on_gold_changed(EconomyManager.gold)
	on_day_started(TimeManager.current_day)
	on_phase_changed(TimeManager.current_phase)
	on_time_updated(TimeManager.time_remaining)


func on_gold_changed(amount: int) -> void:
	hud.gold_label.text = "Wallet: %dG" % amount
	update_target_label()


func on_target_reached() -> void:
	update_target_label()


func on_time_updated(_seconds: float) -> void:
	hud.time_label.text = TimeManager.get_time_display()


func on_phase_changed(_phase) -> void:
	hud.phase_label.text = TimeManager.get_phase_name()


func on_day_started(day: int) -> void:
	hud.day_label.text = "Day %d" % day
	update_target_label()


func update_target_label() -> void:
	var target_text := "%dG / %dG" % [
		EconomyManager.daily_revenue,
		EconomyManager.daily_target
	]

	if EconomyManager.daily_revenue >= EconomyManager.daily_target:
		target_text += " TARGET"

	hud.target_label.text = target_text
