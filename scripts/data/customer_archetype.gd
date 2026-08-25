class_name CustomerArchetype
extends Resource

enum ArchetypeType {
	BUSINESS,   # Aceleci İş İnsanı
	TOURIST,    # Meraklı Turist
	CHILD,      # Tatlı Düşkünü Çocuk
	GOURMET,    # Titiz Gurme
	INFLUENCER  # Sosyal Medya Fenomeni / Kule Avcısı
}

@export var type: ArchetypeType = ArchetypeType.TOURIST
@export var title_name: String = "Turist"
@export var badge_tag: String = "Meraklı Turist"
@export var body_color: Color = Color(0.2, 0.4, 0.8, 1.0)
@export var hat_color: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var scale_factor: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var walk_speed: float = 2.2

# --- OYNANIŞ VE SİPARİŞ PARAMETRELERİ ---
@export var min_scoops: int = 3
@export var max_scoops: int = 6
@export var topping_chance: float = 0.6
@export var two_toppings_chance: float = 0.25
@export var score_decay_rate: float = 0.032
@export var patience_grace_time: float = 14.0
@export var tip_multiplier: float = 1.0
@export var topping_bonus: float = 2.0
@export var reputation_bonus: float = 1.0

# --- FİZİK VE TERCİH PARAMETRELERİ ---
@export var balance_tolerance: float = 1.0 # Külah denge tolerans çarpanı (Düşük = Daha hassas)
@export var order_complexity: float = 1.0  # Aroma çeşitliliği katsayısı
@export var focus_flavor_chance: float = 0.25 # Aynı aromadan çoklu top (Örn: 3x Çikolata) isteme eğilimi
@export var preferred_flavors: Array[String] = []
@export var preferred_toppings: Array[String] = []

# --- AĞIRLIKLI SPAWN HESABI ---
@export var base_spawn_weight: float = 1.0

func get_spawn_weight_for_day(day: int) -> float:
	match type:
		ArchetypeType.BUSINESS:
			# İlk günlerde yüksek, sonra dengeli
			return max(0.6, 1.4 - (float(day) * 0.1))
		ArchetypeType.TOURIST:
			# Her zaman dengeli ve popüler
			return 1.2
		ArchetypeType.CHILD:
			# Gün ilerledikçe hafifçe artar
			return 0.8 + (float(day) * 0.12)
		ArchetypeType.GOURMET:
			# 2. Günden itibaren belirir
			return 0.3 + (float(day) * 0.15) if day >= 2 else 0.1
		ArchetypeType.INFLUENCER:
			# 1. Gün çok nadir (0.05), 3. Günden itibaren artar (0.3 - 0.7)
			if day <= 1:
				return 0.08
			elif day <= 3:
				return 0.25
			else:
				return min(0.8, 0.25 + (float(day) * 0.1))
	return 1.0
