class_name StoreStoryRuntime
extends Node

const GOOBY_DATA = preload("res://data/npc/story/gooby.tres")
const SLIME_DATA = preload("res://data/npc/generic/monster_1.tres")
const PLAYER_PORTRAIT: Texture2D = preload("res://assets/characters/player/portrait.png")
const PHANTOM_ICE_CREAM_ID: String = "phantom_ice_cream"
const IRENE_ID: String = "irene"
const GOOBY_ID: String = "gooby"
const GIVE_CHOICE_INDEX: int = 0
const REJECT_CHOICE_INDEX: int = 1
const GOOBY_TRUST_GAIN: int = 20
const FAST_FADE_DURATION: float = 0.13
const STORY_PHASE_FADE_DURATION: float = 0.55
const FOLLOW_UP_SHELF_READY_ATTEMPTS: int = 30
const SLIME_PAYMENT_NOTIFICATION_DURATION: float = 1.6
const SPARKLE_CANVAS_LAYER: int = 1001
const PLAYER_CASHIER_OFFSET := Vector2(-24, 42)
const GOOBY_PLAYER_OFFSET := Vector2(52, 0)

var store: Node = null
var _story_started: bool = false
var _story_active: bool = false
var _story_complete: bool = false
var _irene_trigger_pending: bool = false
var _phantom_taken_for_story: bool = false
var _rejected_slime_close_hint_pending: bool = false
var _gooby: NPC = null


func setup(store_node: Node) -> void:
	store = store_node


func _exit_tree() -> void:
	if not _story_active:
		return
	var hud := _get_hud()
	if hud != null and hud.has_method("end_story_mode"):
		hud.call("end_story_mode")
	TimeManager.resume()
	if store != null:
		store._is_transitioning = false


func _process(_delta: float) -> void:
	if store == null or _story_started or _story_complete:
		return
	if TimeManager.current_day != 1:
		return

	var night_fallback := TimeManager.current_phase == TimeManager.Phase.NIGHT
	if not _irene_trigger_pending and not night_fallback:
		return
	if not _can_begin_story_now():
		return

	_start_day_one_story()


func on_player_exit_dialog_finished(customer_id: String) -> void:
	if TimeManager.current_day != 1 or customer_id != IRENE_ID:
		return
	_irene_trigger_pending = true


func is_story_active() -> bool:
	return _story_active


func is_story_complete() -> bool:
	return _story_complete


func request_day_one_story() -> void:
	_irene_trigger_pending = true
	if _can_begin_story_now():
		_start_day_one_story()


func _can_begin_story_now() -> bool:
	if store == null or _story_started or _story_complete:
		return false
	if not bool(store._is_store_world_active) or bool(store._is_transitioning):
		return false
	if store._current_storage != null or store._current_yard != null or store._current_home != null:
		return false

	var hud := _get_hud()
	if hud != null and hud.has_method("has_interactive_overlay_open"):
		if bool(hud.call("has_interactive_overlay_open")):
			return false

	return true


func _start_day_one_story() -> void:
	if _story_started:
		return
	_story_started = true
	_irene_trigger_pending = false
	call_deferred("_run_day_one_story")


func _run_day_one_story() -> void:
	if store == null or not is_instance_valid(store):
		return

	_story_active = true
	store._is_transitioning = true
	TimeManager.pause()

	var hud := _get_hud()
	if hud != null and hud.has_method("begin_story_mode"):
		hud.call("begin_story_mode")

	_clear_cashier_runtime()
	await StoreTransitionController.fade_to(
		store,
		store._fade_rect,
		1.0,
		STORY_PHASE_FADE_DURATION
	)
	TimeManager.transition_to_night()
	TimeManager.pause()
	_clear_remaining_day_customers()
	await get_tree().process_frame
	_place_player_at_cashier()
	_take_phantom_ice_cream()
	await StoreTransitionController.fade_to(
		store,
		store._fade_rect,
		0.0,
		STORY_PHASE_FADE_DURATION
	)

	await _show_night_notification()
	await StoreTransitionController.fade_to(store, store._fade_rect, 1.0, FAST_FADE_DURATION)
	await _play_purple_sparkles()
	_spawn_cinematic_gooby()
	await StoreTransitionController.fade_to(store, store._fade_rect, 0.0, FAST_FADE_DURATION)

	await _show_opening_dialogue()
	var choice := await _show_gooby_choice()
	var rejected := choice == REJECT_CHOICE_INDEX

	if rejected:
		_return_phantom_ice_cream_to_shelf()
		await _show_dialogue_sequence([
			_make_dialogue("Gooby", ".....", _get_gooby_portrait(), 0),
		])
	else:
		RelationshipManager.add_trust(GOOBY_ID, GOOBY_TRUST_GAIN)
		await _show_dialogue_sequence([
			_make_dialogue("Gooby", "Boo!", _get_gooby_portrait(), 0),
		])

	await _animate_gooby_exit()
	_finish_story(rejected)


func _show_opening_dialogue() -> void:
	var gooby_portrait := _get_gooby_portrait()
	await _show_dialogue_sequence([
		_make_dialogue("Gooby", "Boo...", gooby_portrait, 0),
		_make_dialogue("Gooby", "*Brings the Phantom Ice Cream with him.*", gooby_portrait, 0),
		_make_dialogue("Player", "That'll be 10G", PLAYER_PORTRAIT, 0),
		_make_dialogue("Gooby", "*Hands over a glowing, ancient-looking banknote.*", gooby_portrait, 0),
		_make_dialogue("Player", "(He's trying to pay me with this strange piece of paper?)", PLAYER_PORTRAIT, 0),
		_make_dialogue("Player", "(What is this thing?)", PLAYER_PORTRAIT, 0),
	])


func _show_gooby_choice() -> int:
	var hud := _get_hud()
	if hud == null or not hud.has_method("show_story_choice"):
		return GIVE_CHOICE_INDEX

	var options: Array[String] = [
		"Give it to Gooby for free (+20 Trust)",
		"Reject it",
	]
	return int(await hud.call("show_story_choice", "What will you do?", options))


func _show_dialogue_sequence(dialogues: Array[Dictionary]) -> void:
	var hud := _get_hud()
	if hud == null or not hud.has_method("show_dialog_sequence"):
		return
	await hud.call("show_dialog_sequence", dialogues)


func _show_night_notification() -> void:
	var hud := _get_hud()
	if hud == null or not hud.has_method("show_story_notification"):
		return
	await hud.call("show_story_notification", "The night has come.")


func _make_dialogue(
	speaker: String,
	content: String,
	portrait: Texture2D,
	frame: int
) -> Dictionary:
	return {
		"name": speaker,
		"content": content,
		"portrait": portrait,
		"frame": frame,
	}


func _place_player_at_cashier() -> void:
	if store.player == null or store.cashier == null:
		return

	store.player.global_position = store.cashier.global_position + PLAYER_CASHIER_OFFSET
	store.player.velocity = Vector2.ZERO
	store.player.facing_direction = Vector2.RIGHT
	store.player._move_direction = CharacterSprite.Direction.RIGHT
	store.player._update_interaction_area_position()
	store.player._update_character_sprite(Vector2.ZERO)


func _get_gooby_spawn_position() -> Vector2:
	if store.player != null:
		return store.player.global_position + GOOBY_PLAYER_OFFSET
	if store.npc_queue_marker != null:
		return store.npc_queue_marker.global_position
	return Vector2(258, 114)


func _play_purple_sparkles() -> void:
	var sparkle_layer := CanvasLayer.new()
	sparkle_layer.name = "GoobySparkleLayer"
	sparkle_layer.layer = SPARKLE_CANVAS_LAYER
	store.add_child(sparkle_layer)

	var sparkles := PurpleSparkleBlink.new()
	sparkle_layer.add_child(sparkles)
	await sparkles.play(store.get_viewport_rect().size)
	if is_instance_valid(sparkle_layer):
		sparkle_layer.queue_free()


func _spawn_cinematic_gooby() -> void:
	if store.npc_scene == null:
		return

	_gooby = store.npc_scene.instantiate() as NPC
	if _gooby == null:
		return

	store.add_child(_gooby)
	_gooby.global_position = _get_gooby_spawn_position()
	var gooby_data := GOOBY_DATA.duplicate(true) as NPCData
	_gooby.setup(gooby_data)
	_gooby.set_meta("cinematic_story_npc", true)
	_gooby.set_physics_process(false)
	_gooby.set_process_input(false)
	_gooby.set_process_unhandled_input(false)
	_gooby.collision_layer = 0
	_gooby.collision_mask = 0
	_gooby.velocity = Vector2.ZERO
	_gooby._move_direction = CharacterSprite.Direction.LEFT
	_gooby._update_character_sprite()
	_gooby._disconnect_trust_signal()

	var trust_label := _gooby.get_node_or_null("TrustLabel") as CanvasItem
	if trust_label != null:
		trust_label.visible = false
	var name_label := _gooby.get_node_or_null("NameLabel") as CanvasItem
	if name_label != null:
		name_label.visible = false


func _animate_gooby_exit() -> void:
	if _gooby == null or not is_instance_valid(_gooby):
		return

	var route: Array[Vector2] = []
	if store.has_method("get_npc_exit_route_from_cashier"):
		route = store.get_npc_exit_route_from_cashier(_gooby.global_position)
	if route.is_empty() and store.npc_exit_marker != null:
		route.append(store.npc_exit_marker.global_position)
	if route.is_empty():
		route.append(_gooby.global_position + Vector2(0, 120))

	for point in route:
		var motion := point - _gooby.global_position
		if motion.length_squared() <= 0.01:
			continue

		# Checkout exits have multiple orthogonal legs. Refresh the walking
		# direction at every turn instead of keeping the first leg's facing.
		_gooby.velocity = motion.normalized() * 80.0
		_gooby._update_character_sprite()
		var tween := store.create_tween()
		tween.set_trans(Tween.TRANS_LINEAR)
		var duration := maxf(motion.length() / 85.0, 0.08)
		tween.tween_property(_gooby, "global_position", point, duration)
		await tween.finished

	if _gooby != null and is_instance_valid(_gooby):
		_gooby.queue_free()
	_gooby = null
	await get_tree().process_frame


func _take_phantom_ice_cream() -> void:
	_phantom_taken_for_story = false
	if store.ghost_shelf == null or not is_instance_valid(store.ghost_shelf):
		return
	_phantom_taken_for_story = store.ghost_shelf.take_item_for_npc(PHANTOM_ICE_CREAM_ID)


func _return_phantom_ice_cream_to_shelf() -> void:
	if store.ghost_shelf == null or not is_instance_valid(store.ghost_shelf):
		return
	if not store.ghost_shelf.has_item(PHANTOM_ICE_CREAM_ID):
		store.ghost_shelf.stock_item_direct(PHANTOM_ICE_CREAM_ID)
	_phantom_taken_for_story = false


func _clear_cashier_runtime() -> void:
	if store.cashier == null:
		return
	if store.cashier.has_method("_clear_scan"):
		store.cashier.call("_clear_scan")
	elif store.cashier.has_method("reset_runtime_ui"):
		store.cashier.call("reset_runtime_ui")


func _clear_remaining_day_customers() -> void:
	for node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as NPC
		if npc == null or not is_instance_valid(npc):
			continue
		if not store.is_ancestor_of(npc):
			continue
		if bool(npc.get_meta("cinematic_story_npc", false)):
			continue
		if npc.npc_data != null and npc.npc_data.visit_phase == NPCData.VisitPhase.NIGHT:
			continue
		npc._return_cart_items_to_shelf()
		npc.queue_free()

	NPC.current_queue.clear()


func _finish_story(rejected: bool) -> void:
	_story_active = false
	_story_complete = true
	store._is_transitioning = false

	var hud := _get_hud()
	if hud != null and hud.has_method("end_story_mode"):
		hud.call("end_story_mode")

	TimeManager.resume()
	store.on_gooby_resolved()
	store._last_objective_text = ""
	store._update_objective()

	if rejected:
		# Slime's purchase is the final beat of the rejection branch.
		_rejected_slime_close_hint_pending = true
		call_deferred("_spawn_rejected_slime_follow_up")
	else:
		store._show_notification("Gooby Trust +20.", 1.8)
		if store.day_runtime != null and store.day_runtime.has_method("show_day_one_close_store_hint"):
			store.day_runtime.call("show_day_one_close_store_hint")


func _spawn_rejected_slime_follow_up() -> void:
	await get_tree().create_timer(0.25).timeout
	if store == null or not is_instance_valid(store) or store.npc_runtime == null:
		return
	if not await _prepare_rejected_slime_shelf():
		return

	var slime_data := SLIME_DATA.duplicate(true) as NPCData
	slime_data.favorite_items = [PHANTOM_ICE_CREAM_ID]
	slime_data.set_meta("shopping_list", [PHANTOM_ICE_CREAM_ID])
	slime_data.set_meta("checkout_total", 10)
	slime_data.set_meta("checkout_outcome", "paid")
	if store.npc_runtime.has_method("spawn_story_customer"):
		var slime := store.npc_runtime.call("spawn_story_customer", slime_data) as NPC
		if slime != null:
			var purchase_callable := Callable(self, "_on_rejected_slime_purchase")
			if not slime.purchase_completed.is_connected(purchase_callable):
				slime.purchase_completed.connect(purchase_callable)


func _on_rejected_slime_purchase(_npc: NPC, _item_id: String, _price: int) -> void:
	if not _rejected_slime_close_hint_pending:
		return

	_rejected_slime_close_hint_pending = false
	# This signal is emitted before CashierCheckoutFlow posts its PAID toast.
	# Wait until that toast has finished instead of letting it overwrite the
	# close-store instruction in the same frame.
	await get_tree().create_timer(SLIME_PAYMENT_NOTIFICATION_DURATION).timeout
	if store != null and store.day_runtime != null and store.day_runtime.has_method("show_day_one_close_store_hint"):
		store.day_runtime.call("show_day_one_close_store_hint")


func _prepare_rejected_slime_shelf() -> bool:
	if store.ghost_shelf == null or not is_instance_valid(store.ghost_shelf):
		return false
	if not store.ghost_shelf.has_item(PHANTOM_ICE_CREAM_ID):
		store.ghost_shelf.stock_item_direct(PHANTOM_ICE_CREAM_ID)

	for _attempt in FOLLOW_UP_SHELF_READY_ATTEMPTS:
		_refresh_ghost_shelf_access()
		if (
			store.ghost_shelf.has_item(PHANTOM_ICE_CREAM_ID)
			and bool(store.ghost_shelf.get_meta("npc_path_ready", false))
		):
			store._setup_npc_static_data()
			return true
		await get_tree().physics_frame

	return false


func _refresh_ghost_shelf_access() -> void:
	if store == null or store.ghost_shelf == null:
		return
	if not store.has_method("_get_store_path_graph"):
		return

	var graph_variant: Variant = store.call("_get_store_path_graph")
	if not (graph_variant is StorePathGraph):
		return
	var graph := graph_variant as StorePathGraph
	graph.store_shelf_access_metadata(
		store.ghost_shelf,
		store.ghost_shelf.global_position
	)


func _get_gooby_portrait() -> Texture2D:
	if GOOBY_DATA.portrait != null:
		return GOOBY_DATA.portrait
	return NPCAssetRuntime.load_portrait_texture(GOOBY_DATA.assets_path)


func _get_hud() -> Node:
	if store == null or store.get_tree() == null:
		return null
	return store.get_tree().get_first_node_in_group("hud")
