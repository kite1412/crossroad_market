class_name NPCShoppingFlow
extends RefCounted

const ShelfItemIndexScript = preload("res://scripts/objects/shelf/ShelfItemIndex.gd")
const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")

const SHELF_ROUTE_FAILURE_COOLDOWN_MSEC: int = 8000
const SHELF_CANDIDATE_PROBE_COOLDOWN_MSEC: int = 900
const SHELF_CANDIDATE_PROBE_LIMIT: int = 8

var npc = null
var _shelf_route_retry_after_msec: Dictionary = {}
var _next_shelf_candidate_probe_msec: int = 0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node) -> void:
	npc = npc_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func choose_item_to_buy() -> void:
	if not npc.shopping_list.is_empty():
		npc.item_to_buy = npc.shopping_list[0]
		return

	if npc.npc_data == null or npc.npc_data.favorite_items.is_empty():
		npc.item_to_buy = ""
		return

	npc.item_to_buy = npc.npc_data.favorite_items[randi() % npc.npc_data.favorite_items.size()]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func choose_available_item_to_buy() -> void:
	if npc.npc_data == null:
		return

	for shopping_item_id in npc.shopping_list:
		if find_shelf_with_item(shopping_item_id) != null:
			set_requested_item(shopping_item_id)
			return

	for favorite_item_id in npc.npc_data.favorite_items:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item_id := str(favorite_item_id)

		if find_shelf_with_item(item_id) != null:
			set_requested_item(item_id)
			return

	if can_substitute_available_stock():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var fallback_item_id := find_available_stock_substitute()

		if fallback_item_id != "":
			set_requested_item(fallback_item_id)
			return

	if npc.item_to_buy == "":
		choose_item_to_buy()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_alternative_item() -> String:
	return NPCShoppingBehavior.find_alternative_item(npc.get_tree(), npc.item_to_buy, npc.item_to_buy_original)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_requested_item(item_id: String) -> void:
	npc.item_to_buy = item_id
	npc.item_to_buy_original = item_id
	npc.shopping_list.clear()
	npc.shopping_list.append(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func can_substitute_available_stock() -> bool:
	return (
		npc.npc_data != null
		and npc.npc_data.npc_category == NPCData.NPCCategory.GENERIC
		and npc.npc_data.visit_phase != NPCData.VisitPhase.NIGHT
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_available_stock_substitute() -> String:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shelf_type := ItemData.ShelfType.HUMAN
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var requested_items := get_requested_items()

	for requested_item_id in requested_items:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item := ItemDatabase.get_item(requested_item_id)

		if item != null:
			shelf_type = item.shelf_type
			break

	return NPCShoppingBehavior.find_first_stocked_item_for_shelf_type(npc.get_tree(), shelf_type)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func return_item_to_shelf() -> void:
	if not npc._cart_items.is_empty():
		return_cart_items_to_shelf()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(npc.item_to_buy)

	if item == null:
		return

	for shelf in npc.get_tree().get_nodes_in_group("shelves"):
		if shelf is Shelf and shelf.shelf_type == item.shelf_type:
			Inventory.add_item(npc.item_to_buy)
			shelf.place_item(npc.item_to_buy)
			return


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_matching_shelf() -> Shelf:
	return NPCShoppingBehavior.find_matching_shelf(npc.get_tree(), npc.item_to_buy)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_reachable_matching_shelf() -> Shelf:
	var selected_shelf: Shelf = null
	for shelf in get_matching_shelf_candidates():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visit_position: Vector2 = get_shelf_visit_position(shelf)
		pass

		if visit_position.is_finite():
			pass
			selected_shelf = shelf
			break

	_record_shelf_candidate_probe(selected_shelf)
	return selected_shelf


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_matching_shelf_candidates() -> Array[Shelf]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var stocked_shelves: Array[Shelf] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fallback_shelves: Array[Shelf] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(npc.item_to_buy)

	if item == null:
		return []

	for indexed_shelf in ShelfItemIndexScript.get_shelves_with_item(npc.item_to_buy):
		if _is_matching_shelf_candidate(indexed_shelf, item):
			stocked_shelves.append(indexed_shelf)

	if not stocked_shelves.is_empty():
		return stocked_shelves

	for shelf_node in npc.get_tree().get_nodes_in_group("shelves"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shelf := shelf_node as Shelf

		if not _is_matching_shelf_candidate(shelf, item):
			continue

		if shelf.has_item(npc.item_to_buy):
			stocked_shelves.append(shelf)
		else:
			fallback_shelves.append(shelf)

	stocked_shelves.append_array(fallback_shelves)
	return stocked_shelves


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_shelf_with_item(item_id: String) -> Shelf:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item != null:
		for shelf in ShelfItemIndexScript.get_shelves_with_item(item_id):
			if _is_matching_shelf_candidate(shelf, item):
				return shelf

	return NPCShoppingBehavior.find_shelf_with_item(npc.get_tree(), item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_visit_position(shelf: Shelf) -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()

	if store != null and store.has_method("get_npc_shelf_visit_position"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var result: Variant = store.call("get_npc_shelf_visit_position", shelf, npc)

		if result is Vector2:
			return result as Vector2

	return NPCShoppingBehavior.get_shelf_visit_position(shelf, npc.SHELF_VISIT_OFFSET)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_matching_shelf_candidate(shelf: Shelf, item: ItemData) -> bool:
	if shelf == null:
		return false

	if _is_shelf_route_temporarily_failed(shelf):
		return false

	if shelf.get_lifecycle() != Shelf.LIFECYCLE_PLACED:
		return false

	if shelf.shelf_type != item.shelf_type:
		return false

	if not shelf.has_meta("npc_path_ready") or not bool(shelf.get_meta("npc_path_ready")):
		return false

	return true


func _record_shelf_candidate_probe(selected_shelf: Shelf) -> void:
	if npc == null:
		return

	var now_msec := Time.get_ticks_msec()
	if now_msec < _next_shelf_candidate_probe_msec:
		return
	_next_shelf_candidate_probe_msec = now_msec + SHELF_CANDIDATE_PROBE_COOLDOWN_MSEC

	var item: ItemData = ItemDatabase.get_item(npc.item_to_buy)
	var indexed_count := 0
	var group_count := 0
	var accepted_count := 0
	var rejected_count := 0
	var rejected_samples: Array[String] = []
	if item != null:
		for indexed_shelf in ShelfItemIndexScript.get_shelves_with_item(npc.item_to_buy):
			indexed_count += 1
			var reject_reason := _get_shelf_candidate_reject_reason(
				indexed_shelf,
				item
			)
			if reject_reason == "":
				accepted_count += 1
			else:
				rejected_count += 1
				if rejected_samples.size() < SHELF_CANDIDATE_PROBE_LIMIT:
					rejected_samples.append(
						_get_shelf_candidate_debug_text(
							indexed_shelf,
							reject_reason
						)
					)

		for shelf_node in npc.get_tree().get_nodes_in_group("shelves"):
			var shelf := shelf_node as Shelf
			if shelf == null:
				continue
			group_count += 1
			var reject_reason := _get_shelf_candidate_reject_reason(
				shelf,
				item
			)
			if reject_reason == "":
				accepted_count += 1
			else:
				rejected_count += 1
				if rejected_samples.size() < SHELF_CANDIDATE_PROBE_LIMIT:
					rejected_samples.append(
						_get_shelf_candidate_debug_text(shelf, reject_reason)
					)

	var context: Dictionary = {
		"npc_id": npc.get_instance_id(),
		"state": int(npc.current_state),
		"item": npc.item_to_buy,
		"position": _format_vector(npc.global_position),
		"indexed_count": indexed_count,
		"group_count": group_count,
		"accepted_count": accepted_count,
		"rejected_count": rejected_count,
		"rejected_samples": " | ".join(rejected_samples),
		"selected": selected_shelf != null
	}
	if selected_shelf != null and is_instance_valid(selected_shelf):
		context["selected_shelf_id"] = String(selected_shelf.get_shelf_id())
		context["selected_shelf_position"] = _format_vector(selected_shelf.global_position)
		context["selected_shelf_revision"] = selected_shelf.get_revision()
		context["selected_npc_path_ready"] = bool(
			selected_shelf.get_meta("npc_path_ready", false)
		)

	StoreRuntimeDebugProbeScript.record(
		&"npc_shelf_candidate_summary",
		0.0,
		context,
		0.0
	)


func _get_shelf_candidate_reject_reason(shelf: Shelf, item: ItemData) -> String:
	if shelf == null:
		return "null"
	if _is_shelf_route_temporarily_failed(shelf):
		return "route_cooldown"
	if shelf.get_lifecycle() != Shelf.LIFECYCLE_PLACED:
		return "lifecycle_%s" % String(shelf.get_lifecycle())
	if shelf.shelf_type != item.shelf_type:
		return "shelf_type"
	if not shelf.has_item(npc.item_to_buy):
		return "missing_item"
	if not shelf.has_meta("npc_path_ready"):
		return "missing_path_meta"
	if not bool(shelf.get_meta("npc_path_ready")):
		return "path_not_ready"
	return ""


func _get_shelf_candidate_debug_text(shelf: Shelf, reason: String) -> String:
	if shelf == null:
		return "null:%s" % reason
	return "%s@%s rev=%d ready=%s reason=%s" % [
		String(shelf.get_shelf_id()),
		_format_vector(shelf.global_position),
		shelf.get_revision(),
		str(bool(shelf.get_meta("npc_path_ready", false))),
		reason
	]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_shelf_route_failed(shelf: Shelf) -> void:
	var failure_key := _get_shelf_route_failure_key(shelf)
	if failure_key == StringName():
		return

	_shelf_route_retry_after_msec[failure_key] = (
		Time.get_ticks_msec() + SHELF_ROUTE_FAILURE_COOLDOWN_MSEC
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func clear_shelf_route_failure(shelf: Shelf) -> void:
	var failure_key := _get_shelf_route_failure_key(shelf)
	if failure_key == StringName():
		return

	_shelf_route_retry_after_msec.erase(failure_key)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_shelf_route_temporarily_failed(shelf: Shelf) -> bool:
	var failure_key := _get_shelf_route_failure_key(shelf)
	if failure_key == StringName():
		return false

	var retry_after_msec := int(_shelf_route_retry_after_msec.get(
		failure_key,
		0
	))
	if retry_after_msec <= 0:
		return false

	if Time.get_ticks_msec() >= retry_after_msec:
		_shelf_route_retry_after_msec.erase(failure_key)
		return false

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_shelf_route_failure_key(shelf: Shelf) -> StringName:
	if shelf == null or not is_instance_valid(shelf):
		return StringName()

	return StringName("%s:%d" % [
		String(shelf.get_shelf_id()),
		shelf.get_revision()
	])


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func refresh_shelf_visit_target() -> bool:
	if npc._target_shelf == null or not is_instance_valid(npc._target_shelf):
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var refreshed_position := get_shelf_visit_position(npc._target_shelf)

	if not refreshed_position.is_finite():
		return false

	if refreshed_position.distance_to(npc.target_position) <= 2.0:
		return false

	npc.target_position = refreshed_position
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_any_requested_item_available() -> bool:
	for requested_item_id in get_requested_items():
		if find_shelf_with_item(requested_item_id) != null:
			return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func take_requested_items_from_shelves() -> bool:
	npc._cart_items.clear()

	for requested_item_id in get_requested_items():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shelf: Shelf = npc._target_shelf if npc._target_shelf is Shelf else null

		if shelf == null:
			_record_take_probe(
				requested_item_id,
				null,
				&"target_shelf_missing",
				&""
			)
			continue

		var reserve_result: Dictionary = shelf.reserve_item_for_npc(
			requested_item_id,
			npc
		)
		if not bool(reserve_result.get("ok", false)):
			_record_take_probe(
				requested_item_id,
				shelf,
				StringName(str(reserve_result.get("reason", &"reserve_failed"))),
				&"reserve"
			)
			continue

		var commit_result: Dictionary = shelf.commit_npc_item_reservation(
			reserve_result.get("token", {}),
			npc
		)
		if bool(commit_result.get("ok", false)):
			npc._cart_items.append(requested_item_id)
			_record_take_probe(
				requested_item_id,
				shelf,
				StringName(str(commit_result.get("reason", &"committed"))),
				&"commit_ok"
			)
		else:
			_record_take_probe(
				requested_item_id,
				shelf,
				StringName(str(commit_result.get("reason", &"commit_failed"))),
				&"commit"
			)
			shelf.cancel_npc_item_reservation(
				reserve_result.get("token", {})
			)

	if not npc._cart_items.is_empty():
		npc.item_to_buy = npc._cart_items[0]
		# The checkout order is created at the exact successful shelf pickup,
		# before the take-item pause or route-to-queue travel can reorder NPCs.
		NPCQueueSystem.mark_item_taken(npc)
		return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _record_take_probe(
	item_id: String,
	shelf: Shelf,
	reason: StringName,
	stage: StringName
) -> void:
	if npc == null:
		return

	var context: Dictionary = {
		"npc_id": npc.get_instance_id(),
		"state": int(npc.current_state),
		"item": item_id,
		"stage": String(stage),
		"reason": String(reason),
		"position": _format_vector(npc.global_position),
		"target": _format_vector(npc.target_position),
		"target_distance": snappedf(
			npc.global_position.distance_to(npc.target_position),
			0.01
		)
	}

	if shelf != null and is_instance_valid(shelf):
		context["shelf_id"] = String(shelf.get_shelf_id())
		context["shelf_revision"] = shelf.get_revision()
		context["shelf_position"] = _format_vector(shelf.global_position)
		context["shelf_distance"] = snappedf(
			npc.global_position.distance_to(shelf.global_position),
			0.01
		)
		context["has_item"] = shelf.has_item(item_id)
		context["npc_path_ready"] = bool(
			shelf.get_meta("npc_path_ready", false)
		)
		var access_variant: Variant = shelf.get_meta(
			&"npc_access_point",
			Vector2.INF
		)
		if access_variant is Vector2:
			var access_position := access_variant as Vector2
			context["npc_access_point"] = _format_vector(access_position)
			context["distance_to_access"] = snappedf(
				npc.global_position.distance_to(access_position),
				0.01
			)
		var access_port_id := StringName(str(
			shelf.get_meta(&"npc_access_port_id", "")
		))
		context["npc_access_port_id"] = String(access_port_id)
		context["npc_access_side"] = str(
			shelf.get_meta(&"npc_access_side", "")
		)
		if access_port_id != StringName() and shelf.has_method("get_interaction_port"):
			var port: Dictionary = shelf.get_interaction_port(access_port_id)
			var port_position := port.get("position", Vector2.INF) as Vector2
			var raw_marker_position := (
				port.get("raw_marker_position", Vector2.INF) as Vector2
			)
			if port_position.is_finite():
				context["selected_port_position"] = _format_vector(port_position)
				context["distance_to_selected_port"] = snappedf(
					npc.global_position.distance_to(port_position),
					0.01
				)
				context["selected_port_body_distance"] = snappedf(
					float(port.get("port_body_distance", INF)),
					0.01
				)
			if raw_marker_position.is_finite():
				context["selected_raw_marker_position"] = _format_vector(
					raw_marker_position
				)
				context["selected_raw_marker_body_distance"] = snappedf(
					float(port.get("raw_marker_body_distance", INF)),
					0.01
				)
				context["selected_marker_fit_distance"] = snappedf(
					float(port.get("marker_fit_distance", 0.0)),
					0.01
				)
			context["selected_port_facing"] = int(port.get("facing", 0))
		if shelf.has_method("get_interaction_ports"):
			context["port_distance_summary"] = _get_port_distance_summary(shelf)

	StoreRuntimeDebugProbeScript.record(
		&"npc_shelf_take_attempt",
		0.0,
		context,
		0.0
	)


func _get_port_distance_summary(shelf: Shelf) -> String:
	var parts: Array[String] = []
	for port in shelf.get_interaction_ports():
		var port_id := str(port.get("port_id", ""))
		var port_position := port.get("position", Vector2.INF) as Vector2
		if not port_position.is_finite():
			continue
		parts.append("%s:%s/%.1f/body%.1f" % [
			port_id,
			_format_vector(port_position),
			npc.global_position.distance_to(port_position),
			float(port.get("port_body_distance", INF))
		])
	return ",".join(parts)


func _format_vector(value: Vector2) -> String:
	return "%.1f,%.1f" % [value.x, value.y]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_requested_items() -> Array[String]:
	return NPCShoppingBehavior.get_requested_items(npc.shopping_list, npc.item_to_buy)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func return_cart_items_to_shelf() -> void:
	for cart_item_id in npc._cart_items:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item: ItemData = ItemDatabase.get_item(cart_item_id)

		if item == null:
			continue

		for shelf in npc.get_tree().get_nodes_in_group("shelves"):
			if shelf is Shelf and shelf.shelf_type == item.shelf_type:
				shelf.stock_item_direct(cart_item_id)
				break

	npc._cart_items.clear()
