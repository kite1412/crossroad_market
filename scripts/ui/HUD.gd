extends CanvasLayer

signal notification_finished()

@onready var gold_label: Label = $GoldLabel
@onready var target_label: Label = $TargetLabel
@onready var time_label: Label = $TimeLabel
@onready var phase_label: Label = $PhaseLabel
@onready var day_label: Label = $DayLabel
@onready var notification_label: Label = $NotificationLabel

const NOTIFY_DURATION: float = 2.0
const GOOBY_ID: String = "gooby"

var _notify_timer: float = 0.0
var _notify_duration: float = NOTIFY_DURATION
var _notify_full_chars: int = 0
var _action_lock_timer: float = 0.0
var _action_lock_sessions: int = 0
var _notification_finished_emitted: bool = true
var _trust_label: Label = null


func _ready() -> void:
	add_to_group("hud")
	notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_trust_label()

	EconomyManager.gold_changed.connect(_on_gold_changed)
	EconomyManager.daily_target_reached.connect(_on_target_reached)
	TimeManager.time_updated.connect(_on_time_updated)
	TimeManager.phase_changed.connect(_on_phase_changed)
	TimeManager.day_started.connect(_on_day_started)
	RelationshipManager.trust_changed.connect(_on_trust_changed)

	_update_all()

	notification_label.visible = false
	notification_label.modulate.a = 0.0
	notification_label.visible_characters = 0


func _process(delta: float) -> void:
	if _action_lock_timer > 0.0:
		_action_lock_timer = max(0.0, _action_lock_timer - delta)

	if _notify_timer <= 0.0:
		return

	_notify_timer -= delta

	var elapsed: float = _notify_duration - _notify_timer
	var progress: float = clamp(elapsed / _notify_duration, 0.0, 1.0)

	var reveal_progress: float = clamp(progress / 0.35, 0.0, 1.0)
	notification_label.visible_characters = int(reveal_progress * _notify_full_chars)

	if progress < 0.75:
		notification_label.modulate.a = 1.0
	else:
		var fade_progress: float = clamp((progress - 0.75) / 0.25, 0.0, 1.0)
		notification_label.modulate.a = 1.0 - fade_progress

	if _notify_timer <= 0.0:
		_finish_notification()


func _input(event: InputEvent) -> void:
	_handle_dialog_skip_input(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle_dialog_skip_input(event)


func _handle_dialog_skip_input(event: InputEvent) -> void:
	if not _is_dialog_skip_event(event):
		return

	var skipped := false

	if notification_label.visible:
		_finish_notification()
		skipped = true

	if _skip_world_dialogs():
		skipped = true

	if skipped:
		get_viewport().set_input_as_handled()


func _is_dialog_skip_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index in [
			MOUSE_BUTTON_LEFT,
			MOUSE_BUTTON_RIGHT,
			MOUSE_BUTTON_MIDDLE
		]

	if event is InputEventScreenTouch:
		return event.pressed

	return false


func _skip_world_dialogs() -> bool:
	var skipped := false

	for node in get_tree().get_nodes_in_group("dialog_skip_target"):
		if node != null and node.has_method("skip_dialog"):
			skipped = bool(node.call("skip_dialog")) or skipped

	return skipped


func show_notification(text: String, duration: float = NOTIFY_DURATION, blocks_actions: bool = true) -> void:
	notification_label.visible = true
	notification_label.text = text
	_notify_full_chars = text.length()
	_notify_duration = max(duration, 0.1)
	_notify_timer = _notify_duration
	notification_label.visible_characters = 0
	notification_label.modulate.a = 1.0
	_notification_finished_emitted = false

	if blocks_actions:
		_action_lock_timer = _notify_duration


func wait_for_notification_finished() -> void:
	if _notify_timer <= 0.0:
		return

	await notification_finished


func begin_action_lock() -> void:
	_action_lock_sessions += 1


func end_action_lock() -> void:
	_action_lock_sessions = max(0, _action_lock_sessions - 1)


func is_action_locked() -> bool:
	return _action_lock_sessions > 0 or _action_lock_timer > 0.0


func _finish_notification() -> void:
	_notify_timer = 0.0
	_action_lock_timer = 0.0
	notification_label.modulate.a = 0.0
	notification_label.visible_characters = 0
	notification_label.visible = false

	if not _notification_finished_emitted:
		_notification_finished_emitted = true
		notification_finished.emit()


func _update_all() -> void:
	_on_gold_changed(EconomyManager.gold)
	_on_day_started(TimeManager.current_day)
	_on_phase_changed(TimeManager.current_phase)
	_on_time_updated(TimeManager.time_remaining)
	_on_trust_changed(GOOBY_ID, RelationshipManager.get_trust(GOOBY_ID), 0)

	target_label.text = "Target: %dG" % EconomyManager.daily_target


func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Wallet: %dG" % amount
	target_label.text = "%dG / %dG" % [
		EconomyManager.daily_revenue,
		EconomyManager.daily_target
	]


func _on_target_reached() -> void:
	target_label.text = "%dG / %dG  TARGET ACHIEVED" % [
		EconomyManager.daily_revenue,
		EconomyManager.daily_target
	]


func _on_time_updated(_seconds: float) -> void:
	time_label.text = TimeManager.get_time_display()


func _on_phase_changed(_phase) -> void:
	phase_label.text = TimeManager.get_phase_name()


func _on_day_started(day: int) -> void:
	day_label.text = "Day %d" % day


func _on_trust_changed(npc_id: String, new_trust: int, _delta: int) -> void:
	if npc_id != GOOBY_ID:
		return

	if _trust_label != null:
		_trust_label.text = "Gooby Trust: %d/100" % new_trust


func _create_trust_label() -> void:
	if _trust_label != null:
		return

	_trust_label = Label.new()
	_trust_label.name = "TrustLabel"
	_trust_label.position = Vector2(328, 4)
	_trust_label.text = "Gooby Trust: 0/100"
	_trust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_trust_label)
