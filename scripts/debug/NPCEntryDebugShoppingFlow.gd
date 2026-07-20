extends "res://scripts/npc/runtime/NPCReachableShelfShoppingFlow.gd"

const DEBUG_SHOPPING_PROFILE: bool = true
const SLOW_STAGE_THRESHOLD_MSEC: float = 2.0


func choose_available_item_to_buy() -> void:
	var started_usec := Time.get_ticks_usec()
	super.choose_available_item_to_buy()
	_log_stage(
		"choose_available_item",
		started_usec,
		"item=%s" % npc.item_to_buy
	)


func get_matching_shelf_candidates() -> Array[Shelf]:
	var started_usec := Time.get_ticks_usec()
	var result := super.get_matching_shelf_candidates()
	_log_stage(
		"matching_shelf_candidates",
		started_usec,
		"count=%d item=%s" % [result.size(), npc.item_to_buy]
	)
	return result


func _get_available_generic_item_ids() -> Array[String]:
	var started_usec := Time.get_ticks_usec()
	var result := super._get_available_generic_item_ids()
	_log_stage(
		"available_generic_items",
		started_usec,
		"count=%d items=%s" % [result.size(), str(result)]
	)
	return result


func _ensure_shelf_path_ready(shelf: Shelf) -> bool:
	var was_ready := false
	var shelf_label := "<invalid>"
	if is_instance_valid(shelf):
		was_ready = bool(shelf.get_meta("npc_path_ready", false))
		shelf_label = "%s@%s" % [shelf.name, str(shelf.global_position)]

	var started_usec := Time.get_ticks_usec()
	var result := super._ensure_shelf_path_ready(shelf)
	var elapsed_msec := float(Time.get_ticks_usec() - started_usec) / 1000.0

	if (
		DEBUG_SHOPPING_PROFILE
		and (
			not was_ready
			or not result
			or elapsed_msec >= SLOW_STAGE_THRESHOLD_MSEC
		)
	):
		var message := (
			"[NPC_SHELF_PROFILE] npc=%s shelf=%s was_ready=%s "
			+ "ready_after=%s elapsed_ms=%.3f"
		) % [
			_get_npc_label(),
			shelf_label,
			str(was_ready),
			str(result),
			elapsed_msec
		]
		print(message)

	return result


func _log_stage(stage: String, started_usec: int, details: String) -> void:
	if not DEBUG_SHOPPING_PROFILE:
		return

	var elapsed_msec := float(Time.get_ticks_usec() - started_usec) / 1000.0
	if elapsed_msec < SLOW_STAGE_THRESHOLD_MSEC:
		return

	print(
		"[NPC_SHOP_PROFILE] npc=%s stage=%s elapsed_ms=%.3f %s"
		% [_get_npc_label(), stage, elapsed_msec, details]
	)


func _get_npc_label() -> String:
	if npc == null:
		return "<null>"
	if npc.npc_data != null and npc.npc_data.npc_id != "":
		return npc.npc_data.npc_id
	return str(npc.name)
