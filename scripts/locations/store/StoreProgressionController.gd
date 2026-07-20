class_name StoreProgressionController
extends RefCounted


static func can_unlock_mystery_phase(
	human_stock_count: int,
	required_stock: int,
	human_shelf_installed: bool,
	already_unlocked: bool
) -> bool:
	return (
		human_stock_count >= required_stock
		and human_shelf_installed
		and not already_unlocked
	)


static func can_unlock_customer_spawning(
	already_unlocked: bool,
	ghost_shelf_installed: bool,
	ghost_shelf: Shelf
) -> bool:
	if already_unlocked:
		return true

	if not ghost_shelf_installed:
		return false

	if ghost_shelf == null or not is_instance_valid(ghost_shelf):
		return false

	_refresh_ghost_shelf_access(ghost_shelf)

	# Night customers must not start until the installed ghost shelf has both
	# stock and a valid NPC access point. Otherwise they enter WAIT_FOR_SHELF at
	# the store exit and appear to skip the shopping sequence.
	return (
		ghost_shelf.has_stock()
		and bool(ghost_shelf.get_meta("npc_path_ready", false))
	)


static func _refresh_ghost_shelf_access(ghost_shelf: Shelf) -> void:
	if bool(ghost_shelf.get_meta("npc_path_ready", false)):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tree := ghost_shelf.get_tree()
	if tree == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store := tree.get_first_node_in_group("store")
	if store == null or not store.has_method("_get_store_path_graph"):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph_variant: Variant = store.call("_get_store_path_graph")
	if not (graph_variant is StorePathGraph):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph := graph_variant as StorePathGraph
	graph.store_shelf_access_metadata(
		ghost_shelf,
		ghost_shelf.global_position
	)


static func should_start_day_one_customers_now() -> bool:
	return (
		TimeManager.current_day == 1
		and TimeManager.current_phase != TimeManager.Phase.NIGHT
	)
