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

	# Night customers must not start until the installed ghost shelf has both
	# stock and a valid NPC access point. Otherwise they enter WAIT_FOR_SHELF at
	# the store exit and appear to skip the shopping sequence.
	return (
		ghost_shelf.has_stock()
		and bool(ghost_shelf.get_meta("npc_path_ready", false))
	)


static func should_start_day_one_customers_now() -> bool:
	return (
		TimeManager.current_day == 1
		and TimeManager.current_phase != TimeManager.Phase.NIGHT
	)
