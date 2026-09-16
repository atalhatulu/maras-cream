class_name OrderReward
extends RefCounted

const DailyEvents = preload("res://scripts/data/daily_event_rules.gd")

## A side-effect-free quote, shared by the HUD and settlement.
static func calculate(order: OrderData, archetype: CustomerArchetype,
		scoop_price: float, tip_upgrade: float, extra_toppings: Array,
		show_bonus: float, event_id: String = "NORMAL",
		recipe_complete: bool = false, clean_service: bool = true) -> Dictionary:
	var base := float(order.flavors.size()) * scoop_price
	for topping in order.toppings:
		base += topping.extra_price
	base = snappedf(base, 0.01)
	var multiplier := (archetype.tip_multiplier if archetype else 1.0) + tip_upgrade
	multiplier *= DailyEvents.tip_multiplier(event_id, archetype)
	var tip := snappedf(clampf(order.current_score / 5.0, 0.0, 1.0) * base * 0.4 * multiplier, 0.01)
	var gift := 0.0
	if not extra_toppings.is_empty():
		gift = snappedf((archetype.topping_bonus if archetype else 2.0) * DailyEvents.gift_multiplier(event_id, archetype), 0.01)
	var show := snappedf(show_bonus, 0.01)
	var inspection := DailyEvents.inspection_reward(event_id, archetype, order.current_score, recipe_complete, clean_service)
	return {"base": base, "tip": tip, "gift": gift, "show": show,
		"event_bonus": inspection.money, "event_reputation": inspection.reputation, "event_note": inspection.note,
		"total": snappedf(base + tip + gift + show + float(inspection.money), 0.01)}
