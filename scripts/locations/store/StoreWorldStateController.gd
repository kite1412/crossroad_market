class_name StoreWorldStateController
extends Node

const PUT_ACTION: StringName = &"put"

var store: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store_node: Node) -> void:
	store = store_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_store_world(_delta: float) -> void:
	if store._current_storage != null or store._current_yard != null or store._current_home != null or store._is_transitioning:
		store._set_carry_shelf_blocker_enabled(false)
		store._set_customer_path_visual_visible(false)
		store._hide_restricted_placement_warning()
		return

	store._update_carry_shelf_blocker()
	store._update_customer_path_visual()
	store._update_player_depth_override()

	if is_action_locked():
		return

	if is_put_pressed():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var carried_object: Node2D = store._get_carried_object_from_player()

		if carried_object != null:
			store._drop_carried_shelf_in_store(carried_object)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_store_world_active(is_active: bool) -> void:
	if store._is_store_world_active == is_active:
		return

	store._is_store_world_active = is_active

	if not is_active:
		store._cancel_restricted_drop_feedback()
		close_cashier_runtime_ui()
		suspend_store_npc_presentations()

	for child in store.get_children():
		if (
			child == store._current_storage
			or child == store._current_yard
			or child == store._current_home
			or child == store._fade_layer
			or child == store._location_title_layer
			or child == store._carry_shelf_blocker
			or child == store.player
		):
			continue

		if child.name == "HUD":
			continue

		set_node_active_recursive(child, is_active)

	if is_active:
		resume_store_npc_presentations()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func suspend_store_npc_presentations() -> void:
	for npc in get_store_npcs():
		npc._ensure_npc_controllers()
		if (
			npc._presentation_runtime != null
			and npc._presentation_runtime.has_method("suspend_world_presentation")
		):
			npc._presentation_runtime.suspend_world_presentation()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func resume_store_npc_presentations() -> void:
	for npc in get_store_npcs():
		npc._ensure_npc_controllers()
		if (
			npc._presentation_runtime != null
			and npc._presentation_runtime.has_method("resume_world_presentation")
		):
			npc._presentation_runtime.resume_world_presentation()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_store_npcs() -> Array[NPC]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result: Array[NPC] = []
	if store == null or store.get_tree() == null:
		return result

	for node in store.get_tree().get_nodes_in_group("npcs"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var npc := node as NPC
		if npc == null or not is_instance_valid(npc):
			continue
		if not is_descendant_of_store(npc):
			continue
		result.append(npc)

	return result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_descendant_of_store(node: Node) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var current := node
	while current != null:
		if current == store:
			return true
		current = current.get_parent()
	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_node_active_recursive(node: Node, is_active: bool) -> void:
	StoreTransitionController.set_node_active_recursive(node, is_active)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_node_enabled_recursive(node: Node, enabled: bool) -> void:
	StoreTransitionController.set_node_enabled_recursive(node, enabled)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_put_pressed() -> bool:
	return InputMap.has_action(PUT_ACTION) and Input.is_action_just_pressed(PUT_ACTION)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_action_locked() -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = store.get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func close_cashier_runtime_ui() -> void:
	if store.cashier == null:
		store.cashier = store.get_node_or_null("Cashier") as Node2D

	if store.cashier != null and store.cashier.has_method("reset_runtime_ui"):
		store.cashier.call("reset_runtime_ui")
