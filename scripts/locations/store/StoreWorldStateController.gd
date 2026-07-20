class_name StoreWorldStateController
extends Node

const PUT_ACTION: StringName = &"put"

var store: Node = null


func setup(store_node: Node) -> void:
	store = store_node


func process_store_world(_delta: float) -> void:
	if (
		store._current_storage != null
		or store._current_yard != null
		or store._current_home != null
		or store._is_transitioning
	):
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
		var carried_object: Node2D = store._get_carried_object_from_player()
		if carried_object != null:
			store._drop_carried_shelf_in_store(carried_object)


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


func suspend_store_npc_presentations() -> void:
	for store_npc in get_store_npcs():
		store_npc._ensure_npc_controllers()
		if (
			store_npc._presentation_runtime != null
			and store_npc._presentation_runtime.has_method(
				"suspend_world_presentation"
			)
		):
			store_npc._presentation_runtime.suspend_world_presentation()


func resume_store_npc_presentations() -> void:
	for store_npc in get_store_npcs():
		store_npc._ensure_npc_controllers()
		if (
			store_npc._presentation_runtime != null
			and store_npc._presentation_runtime.has_method(
				"resume_world_presentation"
			)
		):
			store_npc._presentation_runtime.resume_world_presentation()


func get_store_npcs() -> Array[NPC]:
	var result: Array[NPC] = []
	if store == null or store.get_tree() == null:
		return result

	for node in store.get_tree().get_nodes_in_group("npcs"):
		var store_npc := node as NPC
		if store_npc == null or not is_instance_valid(store_npc):
			continue
		if not is_descendant_of_store(store_npc):
			continue
		result.append(store_npc)

	return result


func is_descendant_of_store(candidate_node: Node) -> bool:
	var current_node := candidate_node
	while current_node != null:
		if current_node == store:
			return true
		current_node = current_node.get_parent()
	return false


func set_node_active_recursive(node: Node, is_active: bool) -> void:
	StoreTransitionController.set_node_active_recursive(node, is_active)


func set_node_enabled_recursive(node: Node, enabled: bool) -> void:
	StoreTransitionController.set_node_enabled_recursive(node, enabled)


func is_put_pressed() -> bool:
	return (
		InputMap.has_action(PUT_ACTION)
		and Input.is_action_just_pressed(PUT_ACTION)
	)


func is_action_locked() -> bool:
	var hud_node: Node = store.get_tree().get_first_node_in_group("hud")
	if hud_node == null or not hud_node.has_method("is_action_locked"):
		return false
	return bool(hud_node.call("is_action_locked"))


func close_cashier_runtime_ui() -> void:
	if store.cashier == null:
		store.cashier = store.get_node_or_null("Cashier") as Node2D

	if store.cashier != null and store.cashier.has_method("reset_runtime_ui"):
		store.cashier.call("reset_runtime_ui")
