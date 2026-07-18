class_name EconomyDailyReportFlow
extends RefCounted

var economy: Node = null


func setup(economy_node: Node) -> void:
	economy = economy_node


func get_daily_tax() -> int:
	return economy.BASE_DAILY_TAX + max(0, TimeManager.current_day - 1) * economy.DAILY_TAX_INCREASE


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


func on_day_started(_day: int) -> void:
	economy.daily_revenue = 0
	economy.daily_expenses = 0
	economy._daily_target_reached = false


func on_day_ended(_day: int) -> void:
	var report := get_daily_report()
	economy.daily_report_ready.emit(report)
