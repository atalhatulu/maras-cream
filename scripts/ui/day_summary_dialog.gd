class_name DaySummaryDialog
extends Control

@onready var title_label: Label = $Card/VBox/TitleLabel
@onready var customer_stats_label: Label = $Card/VBox/StatsSection/CustomerStatsLabel
@onready var revenue_breakdown_label: Label = $Card/VBox/StatsSection/RevenueBreakdownLabel
@onready var total_money_label: Label = $Card/VBox/StatsSection/TotalMoneyLabel
@onready var reputation_label: Label = $Card/VBox/StatsSection/ReputationLabel
@onready var continue_button: Button = $Card/VBox/ContinueButton

func _ready() -> void:
	visible = false
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	EventBus.day_completed.connect(_on_day_completed)

func _on_day_completed(summary_data: Dictionary) -> void:
	var day_num = summary_data.get("day_number", 1)
	var served = summary_data.get("customers_served", 0)
	var success = summary_data.get("successful_orders", 0)
	var failed = summary_data.get("failed_orders", 0)
	var base_rev = summary_data.get("base_revenue", 0.0)
	var tips = summary_data.get("tips", 0.0)
	var bonus = summary_data.get("bonus", 0.0)
	var total_earned = summary_data.get("total_earned", 0.0)
	var final_money = summary_data.get("final_money", 0.0)
	var final_rep = summary_data.get("final_reputation", 100.0)
	
	if title_label:
		title_label.text = "GÜN %d TAMAMLANDI" % day_num
		
	if customer_stats_label:
		customer_stats_label.text = "Toplam Müşteri: %d\n✓ Başarılı: %d\n✗ Kaçan/Zaman Aşımı: %d" % [served, success, failed]
		
	if revenue_breakdown_label:
		revenue_breakdown_label.text = "Dondurma Geliri: $%.2f\nBahşiş Geliri: $%.2f\nİkram Bonusu: $%.2f" % [base_rev, tips, bonus]
		
	if total_money_label:
		total_money_label.text = "Günün Kazancı: +$%.2f\nToplam Kasa: $%.2f" % [total_earned, final_money]
		
	if reputation_label:
		reputation_label.text = "İtibar: %%%d" % int(final_rep)
		
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_continue_pressed() -> void:
	visible = false
	var parent_hud = get_parent()
	if parent_hud and parent_hud.has_node("ShopDialog"):
		var shop = parent_hud.get_node("ShopDialog") as ShopDialog
		if shop:
			shop.open_shop()
			return
			
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.advance_to_next_day()
