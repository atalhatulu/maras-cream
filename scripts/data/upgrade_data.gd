class_name UpgradeData
extends Resource

enum Category {
	SCOOP,     # Kepçe geliştirmeleri
	CONE,      # Külah ve denge geliştirmeleri
	CUSTOMER,  # Müşteri ve bahşiş geliştirmeleri
	FLAVOR,    # Yeni dondurma tatları
	TOPPING    # Yeni sos ve süslemeler
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: Category = Category.SCOOP
@export var max_level: int = 5
@export var current_level: int = 0

@export var base_cost: float = 25.0
@export var cost_multiplier: float = 1.6 # Her levelde maliyet artış çarpanı
@export var unlock_day: int = 1

# Etki değerleri: level başına artış (Örn: {"balance_angle": 3.0, "torque_boost": 5.0})
@export var effects_per_level: Dictionary = {}

# Kilidi açılacak kaynak ID'si (Örn: "muz", "antep_fistigi")
@export var unlock_resource_id: String = ""

func get_cost_for_next_level() -> float:
	if current_level >= max_level:
		return 0.0
	return base_cost * pow(cost_multiplier, current_level)

func get_total_effect(effect_key: String) -> float:
	if effects_per_level.has(effect_key):
		return float(effects_per_level[effect_key]) * float(current_level)
	return 0.0

func is_maxed() -> bool:
	return current_level >= max_level

func can_unlock_on_day(day: int) -> bool:
	return day >= unlock_day
