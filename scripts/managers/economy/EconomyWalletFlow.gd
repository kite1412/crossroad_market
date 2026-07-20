class_name EconomyWalletFlow
extends RefCounted

var economy: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(economy_node: Node) -> void:
	economy = economy_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_gold(amount: int) -> void:
	economy.gold += amount
	economy.daily_revenue += amount
	economy.gold_changed.emit(economy.gold)

	if not economy._daily_target_reached and economy.daily_revenue >= economy.daily_target:
		economy._daily_target_reached = true
		economy.daily_target_reached.emit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func spend_gold(amount: int) -> bool:
	if economy.gold < amount:
		return false
	economy.gold -= amount
	economy.daily_expenses += amount
	economy.gold_changed.emit(economy.gold)
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func pay_tax() -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tax: int = economy.get_daily_tax()
	if economy.gold < tax:
		return false

	economy.gold -= tax
	economy.gold_changed.emit(economy.gold)
	return true
