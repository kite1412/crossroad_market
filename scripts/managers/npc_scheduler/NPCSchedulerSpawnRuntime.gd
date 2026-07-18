class_name NPCSchedulerSpawnRuntime
extends RefCounted

var scheduler: Node = null


func setup(scheduler_node: Node) -> void:
	scheduler = scheduler_node


func process(delta: float) -> void:
	if not scheduler._is_spawning or scheduler._spawn_queue.is_empty():
		return

	scheduler._spawn_timer -= delta
	if scheduler._spawn_timer <= 0.0:
		spawn_next_npc()
		scheduler._spawn_timer = scheduler._spawn_interval


func stop_normal_customer_spawning() -> void:
	if scheduler._is_spawning and scheduler._spawn_queue.size() > 0:
		var filtered_queue: Array = []

		for npc_data in scheduler._spawn_queue:
			if not scheduler._is_normal_day_customer(npc_data):
				filtered_queue.append(npc_data)

		scheduler._spawn_queue = filtered_queue
		scheduler._is_spawning = not scheduler._spawn_queue.is_empty()


func start_spawning(phase) -> void:
	if not can_spawn_phase_now(phase):
		stop_spawning()
		return

	scheduler._spawn_queue.clear()
	for npc in scheduler._day_schedule:
		if npc.visit_phase == phase:
			scheduler._spawn_queue.append(npc)
	scheduler._is_spawning = true
	scheduler._spawn_interval = scheduler.SPAWN_INTERVAL
	scheduler._spawn_timer = 5.0


func start_day_one_spawning(phase) -> void:
	if phase == NPCData.VisitPhase.DAY:
		return
	elif phase == NPCData.VisitPhase.NIGHT:
		if not can_spawn_phase_now(phase):
			stop_spawning()
			return

		scheduler._spawn_queue.clear()
		scheduler._spawn_interval = scheduler.DAY_ONE_NIGHT_SPAWN_INTERVAL

	scheduler._is_spawning = false
	scheduler._spawn_timer = minf(2.0, scheduler._spawn_interval) if phase == NPCData.VisitPhase.NIGHT else scheduler._spawn_interval


func process_day_one_night_monster_follow_up(_delta: float) -> void:
	pass


func stop_spawning() -> void:
	scheduler._is_spawning = false
	scheduler._spawn_queue.clear()


func spawn_next_npc() -> void:
	if scheduler._spawn_queue.is_empty():
		scheduler._is_spawning = false
		return
	var npc_data = scheduler._spawn_queue[0]

	if not can_spawn_npc_now(npc_data.visit_phase):
		scheduler._is_spawning = false
		scheduler._spawn_queue.clear()
		return

	scheduler._spawn_queue.pop_front()
	scheduler.npc_spawn_requested.emit(npc_data)


func can_spawn_phase_now(visit_phase: NPCData.VisitPhase) -> bool:
	match visit_phase:
		NPCData.VisitPhase.MORNING:
			return TimeManager.current_phase == TimeManager.Phase.MORNING
		NPCData.VisitPhase.DAY:
			return TimeManager.current_phase == TimeManager.Phase.DAY
		NPCData.VisitPhase.NIGHT:
			return TimeManager.current_phase == TimeManager.Phase.NIGHT

	return false


func can_spawn_npc_now(visit_phase: NPCData.VisitPhase) -> bool:
	return can_spawn_phase_now(visit_phase)


func is_normal_day_customer(npc_data: NPCData) -> bool:
	return npc_data != null and npc_data.visit_phase == NPCData.VisitPhase.DAY
