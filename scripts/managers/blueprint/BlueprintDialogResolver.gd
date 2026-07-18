class_name BlueprintDialogResolver
extends RefCounted

const BlueprintActionResolver = preload("res://scripts/managers/blueprint/BlueprintActionResolver.gd")

static var _bp_cache_initialized: bool = false
static var _bp_immediate: BlueprintData
static var _bp_queue: BlueprintData
static var _bp_browse: BlueprintData


static func ensure_init() -> void:
	if _bp_cache_initialized:
		return
	_bp_immediate = BlueprintData.new()
	_bp_queue = BlueprintData.new()
	_bp_browse = BlueprintData.new()
	_bp_cache_initialized = true


static func get_dialog(bp_type: int, mood: int, key: String) -> String:
	ensure_init()
	var bp: BlueprintData
	match bp_type:
		0: bp = _bp_immediate
		1: bp = _bp_queue
		2: bp = _bp_browse
		_: return ""
	return bp.get_dialog(bp_type, mood, key)


static func get_item_found_dialog(npc) -> String:
	var bp_type: int = BlueprintActionResolver.get_bp_type(npc)
	var item_name: String = BlueprintActionResolver.item_name(npc.item_to_buy)
	var tmpl := get_dialog(bp_type, npc.npc_data.patience_type, "search")
	if "%s" in tmpl:
		return tmpl % item_name
	return tmpl


static func get_item_not_found_dialog(npc) -> String:
	var bp_type: int = BlueprintActionResolver.get_bp_type(npc)
	var item_name: String = BlueprintActionResolver.item_name(npc.item_to_buy)
	var tmpl := get_dialog(bp_type, npc.npc_data.patience_type, "not_found")
	if "%s" in tmpl:
		return tmpl % item_name
	return tmpl


static func get_checkout_dialog(npc) -> String:
	var bp_type: int = BlueprintActionResolver.get_bp_type(npc)
	var mood: int = npc.npc_data.patience_type
	var item_data: ItemData = ItemDatabase.get_item(npc.item_to_buy)
	var item_name: String = item_data.display_name if item_data else npc.item_to_buy
	var price: int = item_data.sell_price if item_data else 0
	var tmpl := get_dialog(bp_type, mood, "checkout")
	if "%s" in tmpl and "%d" in tmpl:
		return tmpl % [item_name, price]
	elif "%s" in tmpl:
		return tmpl % item_name
	elif "%d" in tmpl:
		return tmpl % price
	return "I'd like to buy %s. %dG." % [item_name, price]


static func get_done_dialog(npc) -> String:
	var bp_type: int = BlueprintActionResolver.get_bp_type(npc)
	return get_dialog(bp_type, npc.npc_data.patience_type, "done")


static func get_queue_too_long_dialog(npc) -> String:
	var bp_type: int = BlueprintActionResolver.get_bp_type(npc)
	return get_dialog(bp_type, npc.npc_data.patience_type, "queue_too_long")


static func get_checkout_wait_dialog(npc) -> String:
	var bp_type: int = BlueprintActionResolver.get_bp_type(npc)
	return get_dialog(bp_type, npc.npc_data.patience_type, "checkout_wait")
