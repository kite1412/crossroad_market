class_name StoreNavigationCostPolicy
extends Resource

@export var distance_weight: float = 1.0
@export var turn_penalty: float = 1.5
@export var queue_lane_penalty: float = 120.0
@export var queue_front_avoid_penalty: float = 10000.0
@export var occupied_area_penalty: float = 24.0
@export var near_obstacle_penalty: float = 8.0
@export var preferred_role_bonus: float = 4.0
@export var dynamic_block_cost: float = INF


func calculate_edge_cost(
	from_position: Vector2,
	to_position: Vector2,
	context: Dictionary = {}
) -> float:
	if not from_position.is_finite() or not to_position.is_finite():
		return INF
	if bool(context.get("dynamic_blocked", false)):
		return dynamic_block_cost

	var cost := from_position.distance_to(to_position) * distance_weight
	if bool(context.get("requires_turn", false)):
		cost += turn_penalty
	if bool(context.get("wrong_queue_lane", false)):
		cost += queue_lane_penalty
	if bool(context.get("temporarily_occupied", false)):
		cost += occupied_area_penalty
	if bool(context.get("near_obstacle", false)):
		cost += near_obstacle_penalty
	if bool(context.get("preferred_role", false)):
		cost = maxf(0.0, cost - preferred_role_bonus)
	if (
		bool(context.get("avoid_queue_front", false))
		and StringName(context.get("to_role", StringName())) == &"queue_front"
		and not bool(context.get("is_goal", false))
	):
		cost += queue_front_avoid_penalty
	return cost


func heuristic(from_position: Vector2, to_position: Vector2) -> float:
	if not from_position.is_finite() or not to_position.is_finite():
		return INF
	return from_position.distance_to(to_position) * distance_weight


func calculate_route_cost(
	start_position: Vector2,
	route: Array[Vector2]
) -> float:
	if not start_position.is_finite():
		return INF
	var total := 0.0
	var previous := start_position
	var previous_direction := Vector2.ZERO

	for point in route:
		if not point.is_finite():
			return INF
		var direction := previous.direction_to(point)
		var edge_context := {
			"requires_turn": (
				not previous_direction.is_zero_approx()
				and absf(previous_direction.dot(direction)) < 0.985
			)
		}
		total += calculate_edge_cost(previous, point, edge_context)
		previous = point
		previous_direction = direction
	return total


func get_signature() -> String:
	return "%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f" % [
		distance_weight,
		turn_penalty,
		queue_lane_penalty,
		queue_front_avoid_penalty,
		occupied_area_penalty,
		near_obstacle_penalty,
		preferred_role_bonus
	]
