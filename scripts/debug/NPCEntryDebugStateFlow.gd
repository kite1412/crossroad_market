extends "res://scripts/npc/runtime/NPCLiveQueueStateFlow.gd"

const DEBUG_ENTER_PROFILE: bool = true
const SLOW_ENTER_THRESHOLD_MSEC: float = 2.0


func process_enter() -> void:
	var state_before: int = npc.current_state
	var pause_before: float = npc._enter_pause_timer
	var started_usec = Time.get_ticks_usec()

	super.process_enter()

	var elapsed_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0
	var crossed_enter_pause = (
		pause_before < npc.ENTER_PAUSE
		and npc._enter_pause_timer >= npc.ENTER_PAUSE
	)
	var state_changed = npc.current_state != state_before

	if (
		DEBUG_ENTER_PROFILE
		and (
			crossed_enter_pause
			or state_changed
			or elapsed_msec >= SLOW_ENTER_THRESHOLD_MSEC
		)
	):
		var message = (
			"[NPC_ENTER_PROFILE] npc=%s elapsed_ms=%.3f state=%d->%d "
			+ "item=%s target_shelf=%s target=%s"
		) % [
			_get_npc_label(),
			elapsed_msec,
			state_before,
			npc.current_state,
			npc.item_to_buy,
			_get_target_shelf_label(),
			str(npc.target_position)
		]
		print(message)


func _get_npc_label() -> String:
	if npc == null:
		return "<null>"
	if npc.npc_data != null and npc.npc_data.npc_id != "":
		return npc.npc_data.npc_id
	return str(npc.name)


func _get_target_shelf_label() -> String:
	if npc == null or not is_instance_valid(npc._target_shelf):
		return "<none>"
	return "%s@%s" % [
		npc._target_shelf.name,
		str(npc._target_shelf.global_position)
	]
