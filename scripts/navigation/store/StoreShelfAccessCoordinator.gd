class_name StoreShelfAccessCoordinator
extends RefCounted

## Resolves shelf interaction points outside NPC getters and route requests.
##
## Access metadata is intentionally computed through a small per-frame queue.
## Callers receive an explicit state and may wait/retry without performing a
## synchronous path search inside a getter.

const READY: StringName = &"ready"
const PENDING: StringName = &"pending"
const UNREACHABLE: StringName = &"unreachable"
const INVALID: StringName = &"invalid"

const MAX_JOBS_PER_FRAME: int = 1
const FRAME_BUDGET_USEC: int = 4000
const FAILED_RETRY_MSEC: int = 1000
const POSITION_EPSILON: float = 0.5

var _store: Node2D = null
var _graph: StorePathGraph = null
var _jobs: Array[Dictionary] = []
var _records: Dictionary = {}
var _next_token: int = 0


func setup(store: Node2D, graph: StorePathGraph) -> void:
	var graph_changed := _graph != graph
	_store = store
	_graph = graph
	if graph_changed:
		_jobs.clear()
		_records.clear()


func request_access(
	shelf: Shelf,
	high_priority: bool = false
) -> StringName:
	if not _is_valid_store_shelf(shelf):
		return INVALID
	if _graph == null:
		return INVALID

	var shelf_id := shelf.get_instance_id()
	var shelf_position := shelf.global_position
	if _graph.has_cached_shelf_access_metadata(shelf):
		_store_record(
			shelf,
			READY,
			shelf_position,
			0,
			int(_records.get(shelf_id, {}).get("token", 0))
		)
		return READY

	var record: Dictionary = _records.get(shelf_id, {})
	if not record.is_empty() and not _record_matches_shelf(record, shelf):
		_records.erase(shelf_id)
		record = {}

	var now_msec := Time.get_ticks_msec()
	if not record.is_empty():
		var state := StringName(record.get("state", INVALID))
		if state == PENDING:
			return PENDING
		if (
			state == UNREACHABLE
			and now_msec < int(record.get("retry_after_msec", 0))
		):
			return UNREACHABLE

	_next_token += 1
	var token := _next_token
	_store_record(shelf, PENDING, shelf_position, 0, token)
	var job := {
		"shelf": shelf,
		"shelf_id": shelf_id,
		"position": shelf_position,
		"token": token
	}
	if high_priority:
		_jobs.push_front(job)
	else:
		_jobs.append(job)
	return PENDING


func get_state(shelf: Shelf) -> StringName:
	if not _is_valid_store_shelf(shelf):
		return INVALID
	if _graph != null and _graph.has_cached_shelf_access_metadata(shelf):
		return READY

	var record: Dictionary = _records.get(shelf.get_instance_id(), {})
	if record.is_empty() or not _record_matches_shelf(record, shelf):
		return INVALID
	return StringName(record.get("state", INVALID))


func get_ready_position(shelf: Shelf) -> Vector2:
	if get_state(shelf) != READY or _graph == null:
		return Vector2.INF
	return _graph.get_shelf_access_position(shelf)


func process_pending_jobs(
	max_jobs: int = MAX_JOBS_PER_FRAME,
	budget_usec: int = FRAME_BUDGET_USEC
) -> void:
	if _graph == null or _jobs.is_empty():
		return

	var started_usec := Time.get_ticks_usec()
	var completed_jobs := 0
	while not _jobs.is_empty() and completed_jobs < maxi(1, max_jobs):
		if (
			completed_jobs > 0
			and Time.get_ticks_usec() - started_usec >= maxi(1, budget_usec)
		):
			break

		var job: Dictionary = _jobs.pop_front()
		if not _is_current_job(job):
			continue

		var shelf := job.get("shelf", null) as Shelf
		var position := job.get("position", Vector2.INF) as Vector2
		var token := int(job.get("token", 0))
		_graph.store_shelf_access_metadata(shelf, position)
		completed_jobs += 1

		if not _is_current_job(job):
			continue
		if _graph.has_cached_shelf_access_metadata(shelf):
			_store_record(shelf, READY, position, 0, token)
		else:
			_store_record(
				shelf,
				UNREACHABLE,
				position,
				Time.get_ticks_msec() + FAILED_RETRY_MSEC,
				token
			)


func invalidate_shelf(shelf: Shelf, clear_graph_metadata: bool = true) -> void:
	if shelf == null or not is_instance_valid(shelf):
		return
	_records.erase(shelf.get_instance_id())
	if clear_graph_metadata and _graph != null:
		_graph.clear_shelf_access_metadata(shelf)


func invalidate_all(clear_graph_metadata: bool = false) -> void:
	_jobs.clear()
	_records.clear()
	if not clear_graph_metadata or _graph == null or _store == null:
		return
	for shelf_variant in _store.get_tree().get_nodes_in_group("shelves"):
		if shelf_variant is Shelf and is_instance_valid(shelf_variant):
			_graph.clear_shelf_access_metadata(shelf_variant as Shelf)


func _store_record(
	shelf: Shelf,
	state: StringName,
	position: Vector2,
	retry_after_msec: int,
	token: int
) -> void:
	_records[shelf.get_instance_id()] = {
		"shelf": shelf,
		"state": state,
		"position": position,
		"retry_after_msec": retry_after_msec,
		"token": token
	}


func _record_matches_shelf(record: Dictionary, shelf: Shelf) -> bool:
	var stored_shelf: Variant = record.get("shelf", null)
	if not is_instance_valid(stored_shelf) or stored_shelf != shelf:
		return false
	var stored_position := record.get("position", Vector2.INF) as Vector2
	return (
		stored_position.is_finite()
		and stored_position.distance_to(shelf.global_position) <= POSITION_EPSILON
	)


func _is_current_job(job: Dictionary) -> bool:
	var shelf_variant: Variant = job.get("shelf", null)
	if not is_instance_valid(shelf_variant) or not (shelf_variant is Shelf):
		return false
	var shelf := shelf_variant as Shelf
	if not _is_valid_store_shelf(shelf):
		return false

	var shelf_id := int(job.get("shelf_id", 0))
	var record: Dictionary = _records.get(shelf_id, {})
	if record.is_empty():
		return false
	if int(record.get("token", -1)) != int(job.get("token", 0)):
		return false
	if StringName(record.get("state", INVALID)) != PENDING:
		return false
	return _record_matches_shelf(record, shelf)


func _is_valid_store_shelf(shelf: Shelf) -> bool:
	if shelf == null or not is_instance_valid(shelf):
		return false
	if _store == null or not _is_descendant_of(shelf, _store):
		return false
	if not shelf.is_in_group("shelves"):
		return false
	if bool(shelf.get_meta("is_carried_storage_object", false)):
		return false
	if shelf.has_meta("is_installed_in_store") and not bool(
		shelf.get_meta("is_installed_in_store", false)
	):
		return false
	return true


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
