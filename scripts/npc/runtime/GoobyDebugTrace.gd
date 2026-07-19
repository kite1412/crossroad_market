class_name GoobyDebugTrace
extends RefCounted

const GOOBY_ID: String = "gooby"
const PREFIX: String = "[GOOBY-DIAG]"


static func is_gooby_data(data: NPCData) -> bool:
	return data != null and data.npc_id == GOOBY_ID


static func is_gooby(npc: NPC) -> bool:
	return (
		npc != null
		and is_instance_valid(npc)
		and is_gooby_data(npc.npc_data)
	)


static func emit_data(event_name: String, data: Dictionary = {}) -> void:
	var payload := data.duplicate(true)
	payload["event"] = event_name
	payload["time_msec"] = Time.get_ticks_msec()
	print("%s %s" % [PREFIX, JSON.stringify(payload)])


static func emit_npc(
	npc: NPC,
	event_name: String,
	data: Dictionary = {}
) -> void:
	if not is_gooby(npc):
		return

	var payload := data.duplicate(true)
	payload["event"] = event_name
	payload["time_msec"] = Time.get_ticks_msec()
	payload["instance_id"] = npc.get_instance_id()
	payload["state"] = state_name(int(npc.current_state))
	payload["position"] = vector(npc.global_position)
	print("%s %s" % [PREFIX, JSON.stringify(payload)])


static func data_snapshot(data: NPCData) -> Dictionary:
	if data == null:
		return {"valid": false}

	return {
		"valid": true,
		"npc_id": data.npc_id,
		"display_name": data.display_name,
		"category": int(data.npc_category),
		"visit_phase": int(data.visit_phase),
		"favorite_items": _string_values(data.favorite_items),
		"shopping_list_meta": _variant_string_values(
			data.get_meta("shopping_list", [])
		),
		"checkout_total_meta": int(
			data.get_meta("checkout_total", -1)
		),
		"checkout_outcome_meta": str(
			data.get_meta("checkout_outcome", "<missing>")
		),
		"assets_path": data.assets_path
	}


static func npc_snapshot(npc: NPC) -> Dictionary:
	if not is_gooby(npc):
		return {"valid": false}

	var target_shelf_name: String = "<none>"
	var target_shelf_path: String = "<none>"
	if npc._target_shelf != null and is_instance_valid(npc._target_shelf):
		target_shelf_name = str(npc._target_shelf.name)
		target_shelf_path = str(npc._target_shelf.get_path())

	return {
		"valid": true,
		"item_to_buy": npc.item_to_buy,
		"item_to_buy_original": npc.item_to_buy_original,
		"shopping_list": _string_values(npc.shopping_list),
		"requested_items": _string_values(npc._get_requested_items()),
		"checkout_total_override": npc.checkout_total_override,
		"checkout_outcome": npc.checkout_outcome,
		"target": vector(npc.target_position),
		"target_shelf": target_shelf_name,
		"target_shelf_path": target_shelf_path,
		"movement_route": route_points(npc._movement_route),
		"movement_route_destination": vector(
			npc._movement_route_destination
		),
		"waiting_for_shelf": npc._waiting_for_shelf_return,
		"shelf_wait_timer": npc._shelf_wait_timer,
		"exit_after_checkout": npc._exit_after_checkout,
		"exit_completed": npc._exit_completed
	}


static func shelf_snapshot(npc: NPC) -> Dictionary:
	if not is_gooby(npc) or npc.get_tree() == null:
		return {"valid": false}

	var requested_items: Array[String] = npc._get_requested_items()
	var shelves: Array[Dictionary] = []

	for shelf_node in npc.get_tree().get_nodes_in_group("shelves"):
		var shelf := shelf_node as Shelf
		if shelf == null or not is_instance_valid(shelf):
			continue

		var requested_stock: Dictionary = {}
		for item_id in requested_items:
			requested_stock[item_id] = shelf.has_item(item_id)

		shelves.append({
			"name": str(shelf.name),
			"path": str(shelf.get_path()),
			"shelf_type": int(shelf.shelf_type),
			"path_meta_present": shelf.has_meta("npc_path_ready"),
			"path_ready": bool(
				shelf.get_meta("npc_path_ready", false)
			),
			"requested_stock": requested_stock
		})

	var matching_candidates: Array[String] = []
	for candidate in npc._get_matching_shelf_candidates():
		if candidate != null and is_instance_valid(candidate):
			matching_candidates.append(str(candidate.name))

	return {
		"valid": true,
		"requested_items": _string_values(requested_items),
		"matching_candidates": matching_candidates,
		"shelves": shelves
	}


static func route_points(route: Array[Vector2]) -> Array[String]:
	var result: Array[String] = []
	for point in route:
		result.append(vector(point))
	return result


static func vector(value: Vector2) -> String:
	if not value.is_finite():
		return "(INF, INF)"
	return "(%.2f, %.2f)" % [value.x, value.y]


static func state_name(state: int) -> String:
	match state:
		NPC.State.ENTER:
			return "ENTER"
		NPC.State.WALK_TO_SHELF:
			return "WALK_TO_SHELF"
		NPC.State.SEARCH_ITEM:
			return "SEARCH_ITEM"
		NPC.State.BROWSE_ITEM:
			return "BROWSE_ITEM"
		NPC.State.TAKE_ITEM:
			return "TAKE_ITEM"
		NPC.State.WAIT_IN_QUEUE:
			return "WAIT_IN_QUEUE"
		NPC.State.CHECKOUT:
			return "CHECKOUT"
		NPC.State.EXIT:
			return "EXIT"
		NPC.State.WAIT_FOR_SHELF:
			return "WAIT_FOR_SHELF"

	return "UNKNOWN_%d" % state


static func _string_values(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


static func _variant_string_values(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result

	for entry in value:
		result.append(str(entry))
	return result
