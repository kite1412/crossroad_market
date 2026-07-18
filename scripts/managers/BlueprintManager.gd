extends Node

const BlueprintDialogResolver = preload("res://scripts/managers/blueprint/BlueprintDialogResolver.gd")
const BlueprintActionResolver = preload("res://scripts/managers/blueprint/BlueprintActionResolver.gd")

enum Action {
	LEAVE,
	QUEUE,
	BROWSE_BUY
}

static var _bp_cache_initialized: bool = false
static var _bp_immediate: BlueprintData
static var _bp_queue: BlueprintData
static var _bp_browse: BlueprintData


static func _ensure_init() -> void:
	BlueprintDialogResolver.ensure_init()
	_bp_cache_initialized = BlueprintDialogResolver._bp_cache_initialized
	_bp_immediate = BlueprintDialogResolver._bp_immediate
	_bp_queue = BlueprintDialogResolver._bp_queue
	_bp_browse = BlueprintDialogResolver._bp_browse


static func get_dialog(bp_type: int, mood: int, key: String) -> String:
	return BlueprintDialogResolver.get_dialog(bp_type, mood, key)


static func evaluate_no_item_action(npc) -> Action:
	return Action.values()[int(BlueprintActionResolver.evaluate_no_item_action(npc))]


static func get_item_found_dialog(npc) -> String:
	return BlueprintDialogResolver.get_item_found_dialog(npc)


static func get_item_not_found_dialog(npc) -> String:
	return BlueprintDialogResolver.get_item_not_found_dialog(npc)


static func get_checkout_dialog(npc) -> String:
	return BlueprintDialogResolver.get_checkout_dialog(npc)


static func get_done_dialog(npc) -> String:
	return BlueprintDialogResolver.get_done_dialog(npc)


static func get_queue_too_long_dialog(npc) -> String:
	return BlueprintDialogResolver.get_queue_too_long_dialog(npc)


static func get_checkout_wait_dialog(npc) -> String:
	return BlueprintDialogResolver.get_checkout_wait_dialog(npc)


static func _get_bp_type(npc) -> int:
	return BlueprintActionResolver.get_bp_type(npc)


static func _item_name(item_id: String) -> String:
	return BlueprintActionResolver.item_name(item_id)
