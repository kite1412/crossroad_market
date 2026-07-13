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

	return ghost_shelf.has_stock()


static func should_start_day_one_customers_now() -> bool:
	return (
		TimeManager.current_day == 1
		and TimeManager.current_phase != TimeManager.Phase.NIGHT
	)
