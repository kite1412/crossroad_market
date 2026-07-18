class_name RestockPackage
extends Area2D

const RestockPackageDataFlow = preload("res://scripts/objects/restock/RestockPackageDataFlow.gd")
const RestockPackagePresentation = preload("res://scripts/objects/restock/RestockPackagePresentation.gd")

signal collected(delivery_id: int)

var delivery_id: int = -1
var item_id: String = ""
var quantity: int = 1
var deliveries: Array[Dictionary] = []

var _label: Label = null

var _data_flow: RestockPackageDataFlow = RestockPackageDataFlow.new()
var _presentation: RestockPackagePresentation = RestockPackagePresentation.new()


func _ready() -> void:
	_setup_restock_package_controllers()
	input_pickable = true
	monitoring = true
	monitorable = true
	_ensure_visual()
	_refresh_label()


func _setup_restock_package_controllers() -> void:
	_data_flow.setup(self)
	_presentation.setup(self)


func setup(id: int, package_item_id: String, package_quantity: int) -> void:
	_data_flow.setup_package(id, package_item_id, package_quantity)


func setup_deliveries(package_deliveries: Array) -> void:
	_data_flow.setup_deliveries(package_deliveries)


func get_hover_display_name() -> String:
	return "Restock Supply Box"


func request_interaction() -> bool:
	return _data_flow.request_interaction()


func _get_item_name() -> String:
	return _data_flow.get_item_name()


func _ensure_visual() -> void:
	_presentation.ensure_visual()


func _refresh_label() -> void:
	_presentation.refresh_label()


func _show_notification(text: String, duration: float) -> void:
	_presentation.show_notification(text, duration)
