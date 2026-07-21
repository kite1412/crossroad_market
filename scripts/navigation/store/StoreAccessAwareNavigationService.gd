class_name StoreAccessAwareNavigationService
extends "res://scripts/navigation/store/StoreNavigationRuntimeService.gd"

## Movement planner variant that consumes prepared shelf access metadata.
##
## StoreShelfAccessCoordinator owns metadata construction. A shelf route request
## returns no route while access is pending/unreachable instead of starting a
## synchronous metadata search inside the movement planner.


func _resolve_request_goal(request: StoreNavigationRequest) -> bool:
	if request.goal_type != StoreNavigationRequest.GOAL_SHELF:
		return super._resolve_request_goal(request)

	if (
		request.target_shelf == null
		or not is_instance_valid(request.target_shelf)
		or _legacy_graph == null
		or not _legacy_graph.has_cached_shelf_access_metadata(
			request.target_shelf
		)
	):
		return false

	request.goal_position = _legacy_graph.get_shelf_access_position(
		request.target_shelf
	)
	request.goal_id = StringName()
	return request.goal_position.is_finite()
