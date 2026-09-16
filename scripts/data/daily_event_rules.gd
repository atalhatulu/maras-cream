extends RefCounted

const EVENTS := {
	"NORMAL": {"title": "Güneşli ve Sakin Bir Gün", "description": "Standart fiyatlar ve müşteri tercihleri geçerli."},
	"HEATWAVE": {"title": "Sıcak Hava Dalgası", "description": "Top başı +$1. Güvenli denge açısı %10 daha dar."},
	"TOURIST_BUS": {"title": "Turist Kafilesi", "description": "Daha çok turist! Turist bahşişi +%25; farklı şovlara +$1, şov sınırına +$2."},
	"CHILDRENS_DAY": {"title": "Çocuk Şenliği", "description": "Daha çok çocuk! Açık iki sosu da isterler. Çocuklara ikram +%50; şov sabrı +2 sn."},
	"GOURMET_VISIT": {"title": "Gurme Teftişi", "description": "Daha çok gurme! Düşürmeden, çöpe atmadan 4,5+ puanlı doğru teslim: +$8 ve +3 itibar."}
}
const INTRODUCTIONS := ["NORMAL", "HEATWAVE", "TOURIST_BUS", "CHILDRENS_DAY", "GOURMET_VISIT"]

static func details(event_id: String, day: int = 0) -> Dictionary:
	if day == 1 and event_id == "NORMAL":
		return {"title": "Açılış Günü", "description": "Hayırlı işler! Siparişi hazırla, külahı dengele ve teslim et."}
	return EVENTS.get(event_id, EVENTS.NORMAL).duplicate()

static func pick_for_day(day: int, previous: String) -> String:
	if day <= INTRODUCTIONS.size():
		return INTRODUCTIONS[maxi(0, day - 1)]
	var choices: Array = EVENTS.keys()
	choices.erase(previous)
	return choices.pick_random()

static func targets(event_id: String, archetype: CustomerArchetype) -> bool:
	if archetype == null:
		return false
	match event_id:
		"TOURIST_BUS": return archetype.type == CustomerArchetype.ArchetypeType.TOURIST
		"CHILDRENS_DAY": return archetype.type == CustomerArchetype.ArchetypeType.CHILD
		"GOURMET_VISIT": return archetype.type == CustomerArchetype.ArchetypeType.GOURMET
	return false

static func spawn_multiplier(event_id: String, archetype: CustomerArchetype) -> float:
	return 3.2 if targets(event_id, archetype) else 1.0

static func tip_multiplier(event_id: String, archetype: CustomerArchetype) -> float:
	return 1.25 if event_id == "TOURIST_BUS" and targets(event_id, archetype) else 1.0

static func gift_multiplier(event_id: String, archetype: CustomerArchetype) -> float:
	return 1.5 if event_id == "CHILDRENS_DAY" and targets(event_id, archetype) else 1.0

static func wants_two_toppings(event_id: String, archetype: CustomerArchetype) -> bool:
	return event_id == "CHILDRENS_DAY" and targets(event_id, archetype)

static func show_adjustments(event_id: String, archetype: CustomerArchetype) -> Dictionary:
	if not targets(event_id, archetype):
		return {}
	match event_id:
		"TOURIST_BUS": return {"variety": 1.0, "cap": 2.0}
		"CHILDRENS_DAY": return {"pause": 2.0}
	return {}

static func inspection_reward(event_id: String, archetype: CustomerArchetype,
		score: float, recipe_complete: bool, clean_service: bool) -> Dictionary:
	var result := {"money": 0.0, "reputation": 0.0, "note": ""}
	if event_id != "GOURMET_VISIT" or not targets(event_id, archetype):
		return result
	if not clean_service:
		result.note = "Teftiş primi yok: bu siparişte külah kaybedildi."
	elif score < 4.5:
		result.note = "Teftiş primi için en az 4,5 puan gerekiyor."
	elif not recipe_complete:
		result.note = "Teftiş: doğru siparişi tamamla; +$8 ve +3 itibar kazan."
	else:
		result.money = 8.0
		result.reputation = 3.0
		result.note = "Teftiş başarılı: teslimde +$8 ve +3 itibar."
	return result
