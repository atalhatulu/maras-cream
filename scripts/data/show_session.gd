class_name ShowSession
extends RefCounted

const DailyEvents = preload("res://scripts/data/daily_event_rules.gd")

## History and budgets belong to a customer; unclaimed money belongs to a cone.
## Replacing a cone forfeits its bonus without refreshing novelty or patience.
const PROFILES := {
	CustomerArchetype.ArchetypeType.BUSINESS: {
		"tease": 3.0, "flip": 2.0, "catch": 2.0, "cap": 6.0, "pause": 1.2,
		"repeat": 0.0, "variety": 0.0, "hint": "Kısa bir şov yeter; acelem var."},
	CustomerArchetype.ArchetypeType.TOURIST: {
		"tease": 3.5, "flip": 4.5, "catch": 3.0, "cap": 16.0, "pause": 6.0,
		"repeat": 0.35, "variety": 2.0, "hint": "Farklı Maraş numaralarını görmek isterim!"},
	CustomerArchetype.ArchetypeType.CHILD: {
		"tease": 4.0, "flip": 4.0, "catch": 3.0, "cap": 14.0, "pause": 7.0,
		"repeat": 0.35, "variety": 1.0, "hint": "Beni şaşırt! Hep aynı numara olmasın."},
	CustomerArchetype.ArchetypeType.GOURMET: {
		"tease": 1.0, "flip": 6.0, "catch": 2.0, "cap": 12.0, "pause": 3.0,
		"repeat": 0.25, "variety": 0.0, "hint": "Doğru sipariş ve ters külah: gerçek ustalık."},
	CustomerArchetype.ArchetypeType.INFLUENCER: {
		"tease": 4.0, "flip": 5.0, "catch": 3.0, "cap": 22.0, "pause": 6.0,
		"repeat": 0.25, "variety": 4.0, "hint": "Farklı hareketleri peş peşe yap, çekiyorum!"}
}

var customer_type: int
var profile: Dictionary
var counts: Dictionary = {}
var awarded: float = 0.0
var cone_bonus: float = 0.0
var pause_used: float = 0.0
var show_count: int = 0
var catch_rewarded: bool = false

func _init(archetype: CustomerArchetype = null, event_id: String = "NORMAL") -> void:
	customer_type = archetype.type if archetype else CustomerArchetype.ArchetypeType.TOURIST
	profile = PROFILES[customer_type].duplicate()
	var adjustments := DailyEvents.show_adjustments(event_id, archetype)
	for key in adjustments:
		profile[key] += adjustments[key]

func lose_cone() -> void:
	cone_bonus = 0.0
	catch_rewarded = false

func complete(kind: String, correct_order: bool = false, score: float = 5.0) -> Dictionary:
	if kind not in ["tease", "flip", "catch", "bell"]:
		return {}
	var previous := int(counts.get(kind, 0))
	counts[kind] = previous + 1
	var factor := 1.0 if previous == 0 else (float(profile.repeat) if previous == 1 else 0.0)
	if kind == "catch" or kind == "bell":
		factor = 1.0 if previous == 0 else 0.0
	var amount := 0.0
	var penalty := 0.0
	if kind != "bell":
		amount = float(profile[kind]) * factor
		if previous == 0 and show_count > 0:
			amount += float(profile.variety)
		if customer_type == CustomerArchetype.ArchetypeType.GOURMET and kind == "flip" and correct_order and score >= 4.0:
			amount += 2.0 * factor
		show_count += 1
		if customer_type == CustomerArchetype.ArchetypeType.BUSINESS and show_count > 1:
			amount = 0.0
			penalty = 0.35
	amount = snappedf(minf(amount, maxf(0.0, float(profile.cap) - awarded)), 0.01)
	awarded = snappedf(awarded + amount, 0.01)
	cone_bonus = snappedf(cone_bonus + amount, 0.01)
	if kind == "catch" and amount > 0.0:
		catch_rewarded = true
	var pause := minf(2.0 * factor, maxf(0.0, float(profile.pause) - pause_used))
	if penalty > 0.0:
		pause = 0.0
	pause_used += pause
	var reaction: String = profile.hint
	if penalty > 0.0:
		reaction = "Lütfen uzatmayalım, toplantım var!"
	elif kind == "bell":
		reaction = "Güzel ritim!" if pause > 0.0 else "Zili duydum, dondurmamı bekliyorum."
	elif amount <= 0.0:
		reaction = "Şov yeterli, artık dondurmamı alayım!"
	elif previous > 0:
		reaction = "Bu numarayı gördüm; başka bir şey dene!"
	elif kind == "catch":
		reaction = "Oh be! Son anda kurtardın!"
	elif customer_type == CustomerArchetype.ArchetypeType.GOURMET and kind == "flip":
		reaction = "İşte hakiki Maraş kıvamı!"
	elif show_count > 1 and float(profile.variety) > 0.0:
		reaction = "İşte bu! Farklı numaralar, harika şov!"
	return {"kind": kind, "amount": amount, "total": cone_bonus,
		"pause": pause, "penalty": penalty, "reaction": reaction,
		"repeated": previous > 0, "cap": float(profile.cap)}
