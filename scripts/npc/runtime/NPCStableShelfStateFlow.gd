extends "res://scripts/npc/runtime/NPCStateFlow.gd"

const SOLO_CHECKOUT_EXIT_META: StringName = &"solo_checkout_exit"
const EXIT_ORIGIN_SHELF_META: StringName = &"exit_origin_shelf"


func finish_checkout_and_exit() -> void:
	# Snapshot queue occupancy before process_exit removes this NPC from the
	# shared queue. This preserves the distinction between a true solo checkout
	# and a checkout that still has customers waiting behind it.
	npc.set_meta(
		SOLO_CHECKOUT_EXIT_META,
		NPC.current_queue.size() <= 1
	)

	if npc.has_meta(EXIT_ORIGIN_SHELF_META):
		npc.remove_meta(EXIT_ORIGIN_SHELF_META)

	super.finish_checkout_and_exit()


func process_search_item(delta: float) -> void:
	var shelf_before_exit := npc._target_shelf as Shelf
	var previous_state: int = npc.current_state

	super.process_search_item(delta)

	# The base flow clears _target_shelf when the out-of-stock timeout changes
	# the state to EXIT. Keep a separate reference so route building can use the
	# shelf-aware egress and avoid being rejected by the shelf's own body.
	if (
		previous_state == NPC.State.SEARCH_ITEM
		and npc.current_state == NPC.State.EXIT
		and not npc._exit_after_checkout
		and shelf_before_exit != null
		and is_instance_valid(shelf_before_exit)
	):
		npc.set_meta(EXIT_ORIGIN_SHELF_META, shelf_before_exit)
		npc.set_meta(SOLO_CHECKOUT_EXIT_META, false)


func complete_exit() -> void:
	if npc.has_meta(SOLO_CHECKOUT_EXIT_META):
		npc.remove_meta(SOLO_CHECKOUT_EXIT_META)
	if npc.has_meta(EXIT_ORIGIN_SHELF_META):
		npc.remove_meta(EXIT_ORIGIN_SHELF_META)

	super.complete_exit()


func _find_reachable_stocked_shelf() -> Shelf:
	var requested_items: Array[String] = npc._get_requested_items()
	var current_shelf := npc._target_shelf as Shelf
	var interaction_tolerance := maxf(
		npc.SHELF_ACTION_DISTANCE,
		npc.ARRIVAL_THRESHOLD + 2.0
	)

	# Once the NPC is already standing at its assigned shelf, do not make item
	# pickup depend on another route/access lookup. Placement metadata can be
	# refreshed after a shelf drop and briefly invalidate that lookup even
	# though the NPC and stocked shelf are already correctly aligned.
	if (
		current_shelf != null
		and is_instance_valid(current_shelf)
		and current_shelf.is_in_group("shelves")
		and npc.global_position.distance_to(npc.target_position)
		<= interaction_tolerance
		and _shelf_has_requested_stock(current_shelf, requested_items)
	):
		return current_shelf

	for shelf in npc._get_matching_shelf_candidates():
		if shelf == null or not is_instance_valid(shelf):
			continue
		if not _shelf_has_requested_stock(shelf, requested_items):
			continue

		var visit_position: Vector2 = npc._get_shelf_visit_position(shelf)
		if visit_position.is_finite():
			return shelf

	return null


func _shelf_has_requested_stock(
	shelf: Shelf,
	requested_items: Array[String]
) -> bool:
	for item_id in requested_items:
		if shelf.has_item(item_id):
			return true

	return false
