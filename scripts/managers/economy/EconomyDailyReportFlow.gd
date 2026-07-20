class_name EconomyDailyReportFlow
extends RefCounted

var economy: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(economy_node: Node) -> void:
	economy = economy_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_daily_tax() -> int:
	return mini(
		economy.BASE_DAILY_TAX + maxi(0, TimeManager.current_day - 1) * economy.DAILY_TAX_INCREASE,
		economy.MAX_DAILY_TAX
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_daily_report() -> Dictionary:
	return {
		"day": TimeManager.current_day,
		"revenue": economy.daily_revenue,
		"expenses": economy.daily_expenses,
		"tax": get_daily_tax(),
		"net_profit": economy.daily_revenue - economy.daily_expenses - get_daily_tax(),
		"total_gold": economy.gold,
		"target": economy.daily_target,
		"target_reached": economy.daily_revenue >= economy.daily_target
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_day_started(day: int) -> void:
	economy.daily_revenue = 0
	economy.daily_expenses = 0
	economy._daily_target_reached = false
	economy.daily_target = economy.get_daily_target_for_day(day)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_day_ended(_day: int) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var report := get_daily_report()
	economy.daily_report_ready.emit(report)
