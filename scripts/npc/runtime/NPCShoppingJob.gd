class_name NPCShoppingJob
extends RefCounted


const STATE_IDLE: StringName = &"idle"
const STATE_CHOOSING_ITEM: StringName = &"choosing_item"
const STATE_RESOLVING_SHELF: StringName = &"resolving_shelf"
const STATE_MOVING_TO_SHELF: StringName = &"moving_to_shelf"
const STATE_PICKING_UP_ITEM: StringName = &"picking_up_item"
const STATE_RESOLVING_CHECKOUT: StringName = &"resolving_checkout"
const STATE_WAITING_IN_QUEUE: StringName = &"waiting_in_queue"
const STATE_CHECKING_OUT: StringName = &"checking_out"
const STATE_LEAVING_STORE: StringName = &"leaving_store"
const STATE_RECOVERING: StringName = &"recovering"

var job_id: StringName = StringName()
var state: StringName = STATE_IDLE
var wanted_item: String = ""
var target_shelf_id: StringName = StringName()
var target_port_id: StringName = StringName()
var expected_shelf_revision: int = -1
var item_reservation: Dictionary = {}
var port_reservation: Dictionary = {}
var checkout_reservation: Dictionary = {}
var current_path: Array[Vector2] = []
var planned_grid_revision: int = -1
var retry_count: int = 0
var last_progress_msec: int = 0


func reset(new_job_id: StringName = StringName()) -> void:
	job_id = new_job_id if new_job_id != StringName() else _make_job_id()
	state = STATE_IDLE
	wanted_item = ""
	target_shelf_id = StringName()
	target_port_id = StringName()
	expected_shelf_revision = -1
	item_reservation.clear()
	port_reservation.clear()
	checkout_reservation.clear()
	current_path.clear()
	planned_grid_revision = -1
	retry_count = 0
	mark_progress()


func mark_progress() -> void:
	last_progress_msec = Time.get_ticks_msec()


func set_state(new_state: StringName) -> void:
	if state == new_state:
		return
	state = new_state
	mark_progress()


func set_target_shelf(shelf: Shelf) -> void:
	if shelf == null:
		target_shelf_id = StringName()
		expected_shelf_revision = -1
		target_port_id = StringName()
		return

	target_shelf_id = shelf.get_shelf_id()
	expected_shelf_revision = shelf.get_revision()
	mark_progress()


func clear_target_shelf() -> void:
	target_shelf_id = StringName()
	target_port_id = StringName()
	expected_shelf_revision = -1
	current_path.clear()
	mark_progress()


func _make_job_id() -> StringName:
	return StringName("job_%d" % Time.get_ticks_usec())
