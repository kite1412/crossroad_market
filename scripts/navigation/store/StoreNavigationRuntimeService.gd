class_name StoreNavigationRuntimeService
extends "res://scripts/navigation/store/StoreNavigationService.gd"

const RuntimeThetaScript = preload(
	"res://scripts/navigation/store/StoreThetaStarRuntimePlanner.gd"
)
const DefaultCostPolicy = preload(
	"res://data/navigation/store_navigation_cost_policy.tres"
)


func _init() -> void:
	_theta = RuntimeThetaScript.new()
	var policy_copy := DefaultCostPolicy.duplicate(true)
	if policy_copy is StoreNavigationCostPolicy:
		_policy = policy_copy as StoreNavigationCostPolicy


func set_cost_policy(policy: StoreNavigationCostPolicy) -> void:
	if policy == null or _policy == policy:
		return
	_policy = policy
	if _initialized:
		_semantic.setup(
			_marker_root,
			_anchors,
			_obstacles,
			_policy
		)
		_reverse.clear()
		_dstar_by_goal.clear()
		_route_cache.invalidate_all()
		_theta.clear_dynamic_cache()


func should_repair_route(
	start_position: Vector2,
	route: Array[Vector2],
	built_revision: int
) -> bool:
	refresh_dynamic_state()
	if built_revision < 0:
		return true
	if built_revision == get_revision():
		return false
	var dirty_regions := _obstacles.get_dirty_regions_since(built_revision)
	return _obstacles.route_intersects_regions(
		start_position,
		route,
		dirty_regions
	)


func get_dirty_regions_since(revision: int) -> Array[Rect2]:
	refresh_dynamic_state()
	return _obstacles.get_dirty_regions_since(revision)
