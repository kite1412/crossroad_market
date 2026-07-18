class_name MysterySupplyTriggerFlow
extends RefCounted

var box: MysterySupplyBox = null


func setup(box_node: MysterySupplyBox) -> void:
	box = box_node


func setup_trigger() -> void:
	box.add_to_group("mystery_supply_boxes")

	if box.trigger_area == null:
		push_error("MysterySupplyBox: Area2D trigger tidak ditemukan.")
		return

	box.trigger_area.monitoring = true
	box.trigger_area.monitorable = true

	if not box.trigger_area.body_entered.is_connected(box._on_trigger_body_entered):
		box.trigger_area.body_entered.connect(box._on_trigger_body_entered)

	if not box.trigger_area.body_exited.is_connected(box._on_trigger_body_exited):
		box.trigger_area.body_exited.connect(box._on_trigger_body_exited)

	if not box.trigger_area.area_entered.is_connected(box._on_trigger_area_entered):
		box.trigger_area.area_entered.connect(box._on_trigger_area_entered)

	if not box.trigger_area.area_exited.is_connected(box._on_trigger_area_exited):
		box.trigger_area.area_exited.connect(box._on_trigger_area_exited)

	box.call_deferred("_refresh_player_inside_trigger")
	box.call_deferred("_try_trigger_discovery")


func process() -> void:
	if box._discovered:
		return

	if box._discovery_running:
		return

	if not is_unlocked():
		return

	refresh_player_inside_trigger()

	if box._player_inside_trigger:
		try_trigger_discovery()


func unlock_mystery() -> void:
	box._unlocked = true
	try_trigger_discovery()


func mark_discovered() -> void:
	box._unlocked = true
	box._discovered = true
	box._discovery_running = false
	box._apply_glow(true)


func on_normal_item_taken() -> void:
	box._items_taken += 1
	try_trigger_discovery()


func on_human_item_placed() -> void:
	box._items_placed += 1
	try_trigger_discovery()


func is_unlocked() -> bool:
	return box._unlocked or (box._items_taken >= box.REQUIRED and box._items_placed >= box.REQUIRED)


func on_trigger_body_entered(body: Node) -> void:
	if is_player_node(body):
		box._player_inside_trigger = true
		try_trigger_discovery()


func on_trigger_body_exited(body: Node) -> void:
	if is_player_node(body):
		box.call_deferred("_refresh_player_inside_trigger")


func on_trigger_area_entered(area: Area2D) -> void:
	if is_player_area(area):
		box._player_inside_trigger = true
		try_trigger_discovery()


func on_trigger_area_exited(area: Area2D) -> void:
	if is_player_area(area):
		box.call_deferred("_refresh_player_inside_trigger")


func is_player_node(node: Node) -> bool:
	return node != null and node.is_in_group("player")


func is_player_area(area: Area2D) -> bool:
	if area == null:
		return false

	if area.is_in_group("player"):
		return true

	var parent: Node = area.get_parent()

	if parent != null and parent.is_in_group("player"):
		return true

	return false


func refresh_player_inside_trigger() -> void:
	box._player_inside_trigger = false

	if box.trigger_area == null:
		return

	if not box.trigger_area.monitoring:
		return

	for body in box.trigger_area.get_overlapping_bodies():
		if is_player_node(body):
			box._player_inside_trigger = true
			return

	for area in box.trigger_area.get_overlapping_areas():
		if is_player_area(area):
			box._player_inside_trigger = true
			return


func try_trigger_discovery() -> void:
	if box._discovered:
		return

	if box._discovery_running:
		return

	if not is_unlocked():
		return

	refresh_player_inside_trigger()

	if not box._player_inside_trigger:
		return

	trigger_discovery()


func trigger_discovery() -> void:
	box._discovery_running = true
	box._discovered = true

	box._apply_glow(true)

	await box._show_discovery_dialog()

	box._discovery_running = false
	box.discovered.emit()

	if box.auto_place_on_ghost_shelf:
		box._auto_collect_to_shelf()
