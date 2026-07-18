class_name NPCSchedulerDayFlow
extends RefCounted

var scheduler: Node = null


func setup(scheduler_node: Node) -> void:
	scheduler = scheduler_node


func on_day_started(day: int) -> void:
	scheduler._day_one_night_monster_spawned = false
	scheduler._day_one_night_monster_follow_up_requested = false
	scheduler._normal_spawning_unlocked = false
	scheduler._store_open = false
	scheduler._generate_schedule(day)
	scheduler._generate_customer_sessions_for_day(day)
	scheduler._start_customer_session(scheduler.SESSION_HUMAN)


func on_phase_changed(phase) -> void:
	if phase == TimeManager.Phase.MORNING:
		if TimeManager.current_day > 1 and scheduler._normal_spawning_unlocked:
			scheduler._start_spawning(NPCData.VisitPhase.MORNING)
		else:
			scheduler._stop_spawning()
	elif phase == TimeManager.Phase.DAY:
		scheduler._stop_spawning()
	elif phase == TimeManager.Phase.NIGHT:
		scheduler.start_night_customer_session()

		if not scheduler._spawning_unlocked:
			scheduler._stop_spawning()
			return

		scheduler._stop_spawning()


func lock_spawning_until_ready() -> void:
	scheduler._spawning_unlocked = false
	scheduler._normal_spawning_unlocked = false
	scheduler._store_open = false
	scheduler._reset_customer_sessions()
	scheduler._stop_spawning()


func unlock_spawning_now(start_day_one_customers_now: bool = false) -> void:
	var was_unlocked: bool = scheduler._spawning_unlocked
	if not scheduler._spawning_unlocked:
		scheduler._spawning_unlocked = true

	if was_unlocked and not start_day_one_customers_now:
		return

	if start_day_one_customers_now:
		scheduler._start_day_one_spawning(NPCData.VisitPhase.DAY)
	else:
		scheduler._on_phase_changed(TimeManager.current_phase)


func unlock_normal_day_spawning_now() -> void:
	scheduler._normal_spawning_unlocked = true


func set_store_open(is_open: bool) -> void:
	scheduler._store_open = is_open
