extends Node


@warning_ignore("unused_signal")
signal gold_changed(new_amount: int)
@warning_ignore("unused_signal")
signal daily_target_reached()
@warning_ignore("unused_signal")
signal daily_report_ready(report: Dictionary)

var gold: int = 0
var daily_revenue: int = 0
var daily_expenses: int = 0
const BASE_DAILY_TARGET: int = 150
const DAILY_TARGET_INCREASE: int = 10
const MAX_DAILY_TARGET: int = 200

const BASE_DAILY_TAX: int = 50
const DAILY_TAX_INCREASE: int = 20
const MAX_DAILY_TAX: int = 150

var daily_target: int = BASE_DAILY_TARGET
@warning_ignore("unused_private_class_variable")
var _daily_target_reached: bool = false

@warning_ignore("unused_private_class_variable")
var _wallet_flow: EconomyWalletFlow = EconomyWalletFlow.new()
@warning_ignore("unused_private_class_variable")
var _daily_report_flow: EconomyDailyReportFlow = EconomyDailyReportFlow.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_wallet_flow.setup(self)
	_daily_report_flow.setup(self)
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.day_ended.connect(_on_day_ended)

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_daily_target_for_day(day: int) -> int:
	return mini(
		BASE_DAILY_TARGET + maxi(0, day - 1) * DAILY_TARGET_INCREASE,
		MAX_DAILY_TARGET
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_gold(amount: int) -> void:
	_wallet_flow.add_gold(amount)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func spend_gold(amount: int) -> bool:
	return _wallet_flow.spend_gold(amount)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_daily_tax() -> int:
	return _daily_report_flow.get_daily_tax()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func pay_tax() -> bool:
	return _wallet_flow.pay_tax()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_daily_report() -> Dictionary:
	return _daily_report_flow.get_daily_report()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_day_started(day: int) -> void:
	_daily_report_flow.on_day_started(day)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_day_ended(day: int) -> void:
	_daily_report_flow.on_day_ended(day)
