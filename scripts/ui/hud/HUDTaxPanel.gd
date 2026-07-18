class_name HUDTaxPanel
extends RefCounted

var hud: CanvasLayer = null


func setup(hud_node: CanvasLayer) -> void:
	hud = hud_node


func show_tax_report(report: Dictionary) -> void:
	ensure_tax_panel()
	render_tax_report(report, "")
	hud._tax_layer.visible = true
	hud._tax_panel.visible = true
	hud.begin_action_lock()


func show_tax_warning(message: String, report: Dictionary = {}) -> void:
	ensure_tax_panel()

	if not report.is_empty():
		render_tax_report(report, message)
	elif hud._tax_warning_label != null:
		hud._tax_warning_label.text = message

	hud._tax_layer.visible = true
	hud._tax_panel.visible = true


func hide_tax_report() -> void:
	if hud._tax_panel != null:
		hud._tax_panel.visible = false

	if hud._tax_layer != null:
		hud._tax_layer.visible = false

	hud.end_action_lock()


func ensure_tax_panel() -> void:
	if hud._tax_layer != null and is_instance_valid(hud._tax_layer):
		return

	hud._tax_layer = CanvasLayer.new()
	hud._tax_layer.name = "TaxReportLayer"
	hud._tax_layer.layer = 30
	hud._tax_layer.visible = false
	hud.add_child(hud._tax_layer)

	hud._tax_panel = ColorRect.new()
	hud._tax_panel.name = "TaxReportPanel"
	hud._tax_panel.color = Color(0.08, 0.065, 0.045, 0.96)
	hud._tax_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud._tax_panel.offset_left = 84.0
	hud._tax_panel.offset_top = 54.0
	hud._tax_panel.offset_right = -84.0
	hud._tax_panel.offset_bottom = -42.0
	hud._tax_panel.clip_contents = true
	hud._tax_layer.add_child(hud._tax_panel)

	var root := VBoxContainer.new()
	root.name = "Content"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12.0
	root.offset_top = 10.0
	root.offset_right = -12.0
	root.offset_bottom = -10.0
	root.add_theme_constant_override("separation", 5)
	hud._tax_panel.add_child(root)

	hud._tax_title_label = Label.new()
	hud._tax_title_label.text = "DAY REPORT"
	hud._tax_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._tax_title_label.add_theme_font_size_override("font_size", 11)
	root.add_child(hud._tax_title_label)

	hud._tax_report_label = Label.new()
	hud._tax_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._tax_report_label.add_theme_font_size_override("font_size", 9)
	root.add_child(hud._tax_report_label)

	hud._tax_warning_label = Label.new()
	hud._tax_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._tax_warning_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45, 1.0))
	hud._tax_warning_label.add_theme_font_size_override("font_size", 8)
	root.add_child(hud._tax_warning_label)

	var pay_button := Button.new()
	pay_button.text = "Pay Tax"
	pay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pay_button.pressed.connect(func() -> void:
		hud.tax_payment_requested.emit()
	)
	root.add_child(pay_button)


func render_tax_report(report: Dictionary, warning: String) -> void:
	ensure_tax_panel()

	var day := int(report.get("day", TimeManager.current_day))
	var revenue := int(report.get("revenue", EconomyManager.daily_revenue))
	var expenses := int(report.get("expenses", EconomyManager.daily_expenses))
	var tax := int(report.get("tax", EconomyManager.get_daily_tax()))
	var net_profit := int(report.get("net_profit", revenue - expenses - tax))
	var total_gold := int(report.get("total_gold", EconomyManager.gold))
	var target_reached := bool(report.get("target_reached", revenue >= EconomyManager.daily_target))

	hud._tax_title_label.text = "DAY %d REPORT" % day
	hud._tax_report_label.text = "Revenue: %dG\nExpenses: %dG\nTax: %dG\nNet Profit: %dG\nWallet: %dG\nTarget: %s" % [
		revenue,
		expenses,
		tax,
		net_profit,
		total_gold,
		"REACHED" if target_reached else "MISSED"
	]
	hud._tax_warning_label.text = warning
