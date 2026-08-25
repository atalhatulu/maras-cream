class_name ToppingData
extends Resource

enum ToppingType {
	SAUCE,     # Sıvı sos (Çikolata, Karamel)
	SPRINKLE   # Taneli süsleme (Antep fıstığı, Fındık)
}

@export var id: String = ""
@export var topping_name: String = ""
@export var color: Color = Color.WHITE
@export var type: ToppingType = ToppingType.SAUCE
@export var extra_price: float = 2.5
