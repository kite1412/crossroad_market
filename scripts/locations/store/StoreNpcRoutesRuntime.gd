class_name StoreNpcRoutesRuntime
extends "res://scripts/locations/store/StoreNpcRoutes.gd"

const StrictPathGraphScript = preload(
	"res://scripts/locations/store/StoreShelfAccessRuntimeGraph.gd"
)
const StrictNavigationServiceScript = preload(
	"res://scripts/navigation/store/StoreAccessAwareNavigationService.gd"
)


func get_store_path_graph() -> StorePathGraph:
	if store == null:
		return null

	var needs_runtime_graph := (
		store._store_path_graph == null
		or store._store_path_graph.get_script() != StrictPathGraphScript
	)
	if needs_runtime_graph:
		store._store_path_graph = StrictPathGraphScript.new(
			store,
			store.store_path_markers
		)
	else:
		store._store_path_graph.setup(
			store,
			store.store_path_markers
		)

	if not _anchors_initialized:
		_navigation_anchors = store._get_shelf_placement_grid_positions()
		_anchors_initialized = true
	store._store_path_graph.set_shelf_access_points(_navigation_anchors)

	var layout_signature := _get_shelf_layout_signature()
	var layout_changed := (
		_has_shelf_layout_signature
		and layout_signature != _last_shelf_layout_signature
	)
	if (
		layout_changed
		and not needs_runtime_graph
		and store._store_path_graph.has_method("invalidate_dynamic_navigation")
	):
		store._store_path_graph.call("invalidate_dynamic_navigation")

	_last_shelf_layout_signature = layout_signature
	_has_shelf_layout_signature = true
	_ensure_shelf_access_coordinator(store._store_path_graph)
	if layout_changed and _shelf_access_coordinator != null:
		_shelf_access_coordinator.invalidate_all(false)
	_ensure_navigation_service(store._store_path_graph, _navigation_anchors)
	return store._store_path_graph


func _ensure_navigation_service(
	graph: StorePathGraph,
	anchors: Array[Vector2]
) -> void:
	if store == null or graph == null:
		return
	if (
		_navigation_service == null
		or _navigation_service.get_script() != StrictNavigationServiceScript
	):
		_navigation_service = StrictNavigationServiceScript.new()
	_navigation_service.setup(
		store,
		store.store_path_markers,
		graph,
		anchors
	)
