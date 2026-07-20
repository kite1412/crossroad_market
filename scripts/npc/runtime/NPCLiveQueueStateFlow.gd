extends "res://scripts/npc/runtime/NPCStableShelfStateFlow.gd"

const SHELF_WAIT_WARNING_SECONDS: float = 5.0
const SHELF_WAIT_ABANDON_SECONDS: float = 20.0

@warning_ignore("unused_private_class_variable")
var _shelf_wait_announced: bool = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func finish_checkout_and_exit() -> void:
	# The exit lane must reflect the queue at checkout completion, not the
	# snapshot taken when this NPC first started moving toward the cashier.
	# A customer may join while the checkout dialog is still running.
	_capture_solo_checkout_fallback()
	super.finish_checkout_and_exit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _begin_wait_for_shelf(_reason: String) -> void:
	# Shelf pickup is recoverable. Keep the customer in a dedicated wait state
	# instead of converting the missing shelf directly into an EXIT request.
	npc._waiting_for_shelf_return = true
	npc._shelf_wait_timer = 0.0
	_shelf_wait_announced = false
	npc.target_position = npc.global_position
	npc.velocity = Vector2.ZERO
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	set_state(NPC.State.WAIT_FOR_SHELF)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_wait_for_shelf(delta: float) -> void:
	npc.velocity = Vector2.ZERO
	npc.move_and_slide()
	npc._shelf_wait_timer += delta

	# A generic customer whose previous choice is no longer stocked may choose
	# again from the items available after the player replaces the shelf.
	if not npc._has_any_requested_item_available():
		npc._choose_available_item_to_buy()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var replacement_shelf: Shelf = npc._find_reachable_matching_shelf()
	if replacement_shelf != null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visit_position: Vector2 = npc._get_shelf_visit_position(
			replacement_shelf
		)

		if visit_position.is_finite():
			npc.skip_dialog()
			npc._target_shelf = replacement_shelf
			npc.target_position = visit_position
			npc._waiting_for_shelf_return = false
			npc._shelf_wait_timer = 0.0
			_shelf_wait_announced = false
			set_state(NPC.State.WALK_TO_SHELF)
			return

	if (
		npc._shelf_wait_timer >= SHELF_WAIT_WARNING_SECONDS
		and not _shelf_wait_announced
	):
		_shelf_wait_announced = true
		npc._show_dialog("Where'd the shelf go?")

	# The first dialog is only a warning. Give the player enough time to place
	# the shelf back before the customer actually abandons the visit.
	if npc._shelf_wait_timer < SHELF_WAIT_ABANDON_SECONDS:
		npc._reset_stuck_watchdog()
		return

	npc._waiting_for_shelf_return = false
	npc._shelf_wait_timer = 0.0
	_shelf_wait_announced = false
	npc._show_dialog("I can't keep waiting. I'll come back another time.")
	npc._exit_after_checkout = false
	npc.target_position = npc._get_exit_position()
	set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_exit() -> void:
	# Show departure feedback before checking whether the NPC already overlaps
	# the shared entry/exit marker. Without this guard, an NPC waiting near the
	# door can be deleted on the same frame the exit dialog is requested.
	if npc._dialog_timer > 0.0:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		npc._reset_stuck_watchdog()
		return

	super.process_exit()
