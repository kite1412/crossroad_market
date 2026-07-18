extends Node

const EconomyWalletFlow = preload("res://scripts/managers/economy/EconomyWalletFlow.gd")
const EconomyDailyReportFlow = preload("res://scripts/managers/economy/EconomyDailyReportFlow.gd")

signal gold_changed(new_amount: int)
signal daily_target_reached()
signal daily_report_ready(report: Dictionary)

var gold: int = 0
var daily_revenue: int = 0
var daily_expenses: int = 0
var daily_target: int = 50
var _daily_target_reached: bool = false

const BASE_DAILY_TAX: int = 20
const DAILY_TAX_INCREASE: int = 5

var _wallet_flow: EconomyWalletFlow = EconomyWalletFlow.new()
var _daily_report_flow: EconomyDailyReportFlow = EconomyDailyReportFlow.new()


func _ready() -> void:
	_wallet_flow.setup(self)
	_daily_report_flow.setup(self)
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.day_ended.connect(_on_day_ended)


func add_gold(amount: int) -> void:
	_wallet_flow.add_gold(amount)


func spend_gold(amount: int) -> bool:
	return _wallet_flow.spend_gold(amount)


func get_daily_tax() -> int:
	return _daily_report_flow.get_daily_tax()


func pay_tax() -> bool:
	return _wallet_flow.pay_tax()


func get_daily_report() -> Dictionary:
	return _daily_report_flow.get_daily_report()


func _on_day_started(day: int) -> void:
	_daily_report_flow.on_day_started(day)


func _on_day_ended(day: int) -> void:
	_daily_report_flow.on_day_ended(day)
