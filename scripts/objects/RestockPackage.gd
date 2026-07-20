class_name RestockPackage
extends Area2D


@warning_ignore("unused_signal")
signal collected(delivery_id: int)

var delivery_id: int = -1
var item_id: String = ""
var quantity: int = 1
var deliveries: Array[Dictionary] = []

@warning_ignore("unused_private_class_variable")
var _label: Label = null

@warning_ignore("unused_private_class_variable")
var _data_flow: RestockPackageDataFlow = RestockPackageDataFlow.new()
@warning_ignore("unused_private_class_variable")
var _presentation: RestockPackagePresentation = RestockPackagePresentation.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_setup_restock_package_controllers()
	input_pickable = true
	monitoring = true
	monitorable = true
	_ensure_visual()
	_refresh_label()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_restock_package_controllers() -> void:
	_data_flow.setup(self)
	_presentation.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(id: int, package_item_id: String, package_quantity: int) -> void:
	_data_flow.setup_package(id, package_item_id, package_quantity)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup_deliveries(package_deliveries: Array) -> void:
	_data_flow.setup_deliveries(package_deliveries)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_hover_display_name() -> String:
	return "Restock Supply Box"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_interaction() -> bool:
	return _data_flow.request_interaction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_item_name() -> String:
	return _data_flow.get_item_name()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ensure_visual() -> void:
	_presentation.ensure_visual()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _refresh_label() -> void:
	_presentation.refresh_label()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_notification(text: String, duration: float) -> void:
	_presentation.show_notification(text, duration)
