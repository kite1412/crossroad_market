class_name MysterySupplyBox
extends SupplyBox

signal discovered()

@export var trigger_area_path: NodePath = NodePath("Area2D")
@export var auto_place_on_ghost_shelf: bool = false

const REQUIRED: int = 4

var _discovered: bool = false
var _unlocked: bool = false
var _items_taken: int = 0
var _items_placed: int = 0
var _discovery_running: bool = false
var _player_inside_trigger: bool = false

@onready var trigger_area: Area2D = get_node_or_null(trigger_area_path) as Area2D


func _ready() -> void:
	super._ready()
	add_to_group("mystery_supply_boxes")

	_apply_glow(false)

	if trigger_area == null:
		push_error("MysterySupplyBox: Area2D trigger tidak ditemukan.")
		return

	trigger_area.monitoring = true
	trigger_area.monitorable = true

	if not trigger_area.body_entered.is_connected(_on_trigger_body_entered):
		trigger_area.body_entered.connect(_on_trigger_body_entered)

	if not trigger_area.body_exited.is_connected(_on_trigger_body_exited):
		trigger_area.body_exited.connect(_on_trigger_body_exited)

	if not trigger_area.area_entered.is_connected(_on_trigger_area_entered):
		trigger_area.area_entered.connect(_on_trigger_area_entered)

	if not trigger_area.area_exited.is_connected(_on_trigger_area_exited):
		trigger_area.area_exited.connect(_on_trigger_area_exited)

	call_deferred("_refresh_player_inside_trigger")
	call_deferred("_try_trigger_discovery")


func _process(_delta: float) -> void:
	if _discovered:
		return

	if _discovery_running:
		return

	if not _is_unlocked():
		return

	_refresh_player_inside_trigger()

	if _player_inside_trigger:
		_try_trigger_discovery()


func unlock_mystery() -> void:
	_unlocked = true
	_try_trigger_discovery()


func mark_discovered() -> void:
	_unlocked = true
	_discovered = true
	_discovery_running = false
	_apply_glow(true)


func on_normal_item_taken() -> void:
	_items_taken += 1
	_try_trigger_discovery()


func on_human_item_placed() -> void:
	_items_placed += 1
	_try_trigger_discovery()


func _is_unlocked() -> bool:
	return _unlocked or (_items_taken >= REQUIRED and _items_placed >= REQUIRED)


func _on_trigger_body_entered(body: Node) -> void:
	if _is_player_node(body):
		_player_inside_trigger = true
		_try_trigger_discovery()


func _on_trigger_body_exited(body: Node) -> void:
	if _is_player_node(body):
		call_deferred("_refresh_player_inside_trigger")


func _on_trigger_area_entered(area: Area2D) -> void:
	if _is_player_area(area):
		_player_inside_trigger = true
		_try_trigger_discovery()


func _on_trigger_area_exited(area: Area2D) -> void:
	if _is_player_area(area):
		call_deferred("_refresh_player_inside_trigger")


func _is_player_node(node: Node) -> bool:
	return node != null and node.is_in_group("player")


func _is_player_area(area: Area2D) -> bool:
	if area == null:
		return false

	if area.is_in_group("player"):
		return true

	var parent: Node = area.get_parent()

	if parent != null and parent.is_in_group("player"):
		return true

	return false


func _refresh_player_inside_trigger() -> void:
	_player_inside_trigger = false

	if trigger_area == null:
		return

	if not trigger_area.monitoring:
		return

	for body in trigger_area.get_overlapping_bodies():
		if _is_player_node(body):
			_player_inside_trigger = true
			return

	for area in trigger_area.get_overlapping_areas():
		if _is_player_area(area):
			_player_inside_trigger = true
			return


func _try_trigger_discovery() -> void:
	if _discovered:
		return

	if _discovery_running:
		return

	if not _is_unlocked():
		return

	_refresh_player_inside_trigger()

	if not _player_inside_trigger:
		return

	_trigger_discovery()


func _trigger_discovery() -> void:
	_discovery_running = true
	_discovered = true

	_apply_glow(true)

	await _show_discovery_dialog()

	_discovery_running = false
	discovered.emit()

	if auto_place_on_ghost_shelf:
		_auto_collect_to_shelf()


func _show_discovery_dialog() -> void:
	var hud: Node = _get_hud()

	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")

	await _show_dialog_line("What is this...?", 2.3)
	await _show_dialog_line("This box wasn’t in Grandma’s inventory list.", 2.9)
	await _show_dialog_line("Why is it glowing... and why does it feel ice cold?", 3.3)

	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")


func _show_dialog_line(text: String, duration: float) -> void:
	var hud: Node = _get_hud()

	if hud == null:
		return

	if not hud.has_method("show_notification"):
		return

	hud.call("show_notification", text, duration)

	if hud.has_method("wait_for_notification_finished"):
		await hud.call("wait_for_notification_finished")
	else:
		await get_tree().create_timer(duration + 0.15).timeout


func _get_hud() -> Node:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		return hud

	return _find_node_with_method(get_tree().root, "show_notification")


func _find_node_with_method(node: Node, method_name: String) -> Node:
	if node == null:
		return null

	if node.has_method(method_name):
		return node

	for child in node.get_children():
		var found: Node = _find_node_with_method(child, method_name)

		if found != null:
			return found

	return null


func get_available_items() -> Array[String]:
	if not _discovered:
		return []

	if _discovery_running:
		return []

	return super.get_available_items()


func collect_one(item_id: String) -> bool:
	if not _discovered:
		return false

	if _discovery_running:
		return false

	if is_empty():
		return false

	return super.collect_one(item_id)


func _auto_collect_to_shelf() -> void:
	if is_empty():
		return

	if items_to_give.is_empty():
		return

	var item_id: String = items_to_give[0]
	var ghost_shelf: Shelf = _get_ghost_shelf()

	if ghost_shelf == null:
		return

	var result: int = ghost_shelf.place_item(item_id)

	if result >= 0:
		_mark_item_as_taken_without_inventory(item_id)
		item_taken.emit(item_id)
		items_collected.emit([item_id])


func _mark_item_as_taken_without_inventory(item_id: String) -> void:
	_collected_items[item_id] = _collected_items.get(item_id, 0) + 1

	var all_done: bool = true

	for it in items_to_give:
		if not _collected_items.has(it):
			all_done = false
			break

	if all_done:
		_already_collected = true
		_all_items_taken = true


func _get_ghost_shelf() -> Shelf:
	for shelf in get_tree().get_nodes_in_group("shelves"):
		if shelf is Shelf and shelf.shelf_type == ItemData.ShelfType.GHOST:
			return shelf

	return null


func _apply_glow(enabled: bool) -> void:
	if enabled:
		_apply_visual_tint(Color(0.4, 0.3, 0.8, 1.0))
	else:
		_apply_visual_tint(Color(0.2, 0.2, 0.2, 0.3))


func _apply_visual_tint(color: Color) -> void:
	var color_rect := get_node_or_null("VisualRoot/PlaceholderRect") as ColorRect

	if color_rect != null:
		color_rect.color = color
		return

	var visual := get_node_or_null("VisualRoot/AssetSprite") as CanvasItem

	if visual != null:
		visual.modulate = color


func is_empty() -> bool:
	if not _discovered:
		return true

	return super.is_empty()


func is_discovered() -> bool:
	return _discovered


func is_discovery_running() -> bool:
	return _discovery_running
