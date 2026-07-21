class_name NPCLayeredNavigationRouteController
extends "res://scripts/npc/runtime/NPCResolvedExitRouteController.gd"

const ROUTE_REVISION_META: StringName = &"store_navigation_route_revision"


func move_to(
	target: Vector2,
	arrival_threshold: float = -1.0
) -> bool:
	var threshold: float = (
		npc.ARRIVAL_THRESHOLD
		if arrival_threshold < 0.0
		else arrival_threshold
	)

	if should_rebuild_movement_route(target):
		npc._movement_route = build_movement_route(target)
		npc._movement_route_destination = target
		_store_current_navigation_revision()

	_trim_arrived_route_points(threshold)
	if npc._movement_route.is_empty():
		if uses_store_navigation_state():
			npc.velocity = Vector2.ZERO
			npc.move_and_slide()
			return false
		return NPCMovement.move_to(
			npc,
			target,
			npc.SPEED,
			threshold
		)

	var next_target: Vector2 = npc._movement_route[0]
	var adjustment := _get_local_avoidance_adjustment(next_target)
	if bool(adjustment.get("wait", false)):
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		return false

	var movement_target := next_target
	var adjusted_variant: Variant = adjustment.get("target", next_target)
	if adjusted_variant is Vector2:
		movement_target = adjusted_variant as Vector2

	var using_sidestep := movement_target.distance_to(next_target) > 1.0
	var reached_movement_target := NPCMovement.move_to(
		npc,
		movement_target,
		npc.SPEED,
		threshold
	)
	if not reached_movement_target:
		return false

	if using_sidestep:
		return false

	npc._movement_route.remove_at(0)
	_trim_arrived_route_points(threshold)
	return npc._movement_route.is_empty()


func should_rebuild_movement_route(target: Vector2) -> bool:
	if super.should_rebuild_movement_route(target):
		return true

	var navigation_service := _get_navigation_service()
	if navigation_service == null or not navigation_service.has_method("get_revision"):
		return false

	var current_revision := int(navigation_service.call("get_revision"))
	var built_revision := int(npc.get_meta(ROUTE_REVISION_META, -1))
	if built_revision == current_revision:
		return false
	if built_revision < 0:
		return true

	if navigation_service.has_method("should_repair_route"):
		var should_repair := bool(
			navigation_service.call(
				"should_repair_route",
				npc.global_position,
				npc._movement_route,
				built_revision
			)
		)
		if not should_repair:
			npc.set_meta(ROUTE_REVISION_META, current_revision)
		return should_repair

	return true


func get_shelf_egress_queue_route(
	store: Node,
	queue_index: int,
	destination: Vector2
) -> Array[Vector2]:
	var route_provider := _get_nested_route_provider(store)
	if (
		route_provider != null
		and npc._queue_entry_shelf != null
		and is_instance_valid(npc._queue_entry_shelf)
		and route_provider.has_method(
			"get_npc_route_from_shelf_to_queue_target"
		)
	):
		var layered_route := call_store_route(
			route_provider,
			&"get_npc_route_from_shelf_to_queue_target",
			[
				npc._queue_entry_shelf,
				npc.global_position,
				queue_index,
				npc
			]
		)
		if not layered_route.is_empty():
			return _finish_queue_route(layered_route, destination)
	return super.get_shelf_egress_queue_route(
		store,
		queue_index,
		destination
	)


func _get_local_avoidance_adjustment(
	desired_target: Vector2
) -> Dictionary:
	var navigation_service := _get_navigation_service()
	if (
		navigation_service == null
		or not navigation_service.has_method(
			"get_local_avoidance_adjustment"
		)
	):
		return {"target": desired_target, "wait": false}

	var result: Variant = navigation_service.call(
		"get_local_avoidance_adjustment",
		npc,
		desired_target
	)
	if result is Dictionary:
		return result as Dictionary
	return {"target": desired_target, "wait": false}


func _store_current_navigation_revision() -> void:
	var navigation_service := _get_navigation_service()
	if navigation_service == null or not navigation_service.has_method("get_revision"):
		return
	npc.set_meta(
		ROUTE_REVISION_META,
		int(navigation_service.call("get_revision"))
	)


func _get_navigation_service():
	var store := get_store_route_provider()
	var route_provider := _get_nested_route_provider(store)
	if route_provider == null:
		return null

	# StoreNpcRoutes creates the service during Store setup. Reading the cached
	# instance avoids running compatibility graph synchronization every frame.
	var cached_variant: Variant = route_provider.get("_navigation_service")
	if is_instance_valid(cached_variant):
		return cached_variant

	if not route_provider.has_method("get_navigation_service"):
		return null
	var service_variant: Variant = route_provider.call("get_navigation_service")
	if not is_instance_valid(service_variant):
		return null
	return service_variant
