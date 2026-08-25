class_name Customer
extends CharacterBody3D

enum State {
	ARRIVING,
	WAITING,
	ORDER_IN_PROGRESS,
	IMPATIENT,
	ORDER_READY,
	DELIVERED,
	SATISFIED,
	DISAPPOINTED,
	TIMEOUT,
	LEAVING
}

@export var customer_data: CustomerData
@export var current_order: OrderData

@onready var visual_pivot: Node3D = $VisualPivot
@onready var head_pivot: Node3D = $VisualPivot/HeadPivot
@onready var hands_pivot: Node3D = $VisualPivot/HandsPivot
@onready var speech_label_3d: Label3D = $VisualPivot/SpeechLabel3D
@onready var customer_mesh: MeshInstance3D = $VisualPivot/CustomerMesh
@onready var head_mesh: MeshInstance3D = $VisualPivot/HeadPivot/HeadMesh
@onready var beanie_mesh: MeshInstance3D = $VisualPivot/HeadPivot/BeanieMesh
@onready var accessory_mesh: MeshInstance3D = $VisualPivot/AccessoryMesh

var archetype: CustomerArchetype = null
var state: State = State.ARRIVING
var _is_score_decaying: bool = false
var _target_counter_pos: Vector3
var _spawn_pos: Vector3
var _coat_mat: StandardMaterial3D
var _is_highlighted: bool = false

var _anim_time: float = 0.0
var _freeze_timer: float = 0.0
var _patience_depleted_timer: float = 0.0
const MAX_PATIENCE_GRACE_TIME: float = 14.0

var _target_look_y: float = 0.0
var _target_look_x: float = 0.0

func _ready() -> void:
	EventBus.cone_dropped.connect(_on_cone_dropped)
	EventBus.ice_cream_added.connect(_on_ice_cream_added)
	EventBus.order_progress_updated.connect(_on_order_progress_updated)

func apply_archetype(arch: CustomerArchetype) -> void:
	archetype = arch
	if archetype == null:
		return
		
	if visual_pivot:
		visual_pivot.scale = archetype.scale_factor
	
	if customer_mesh:
		_coat_mat = StandardMaterial3D.new()
		_coat_mat.albedo_color = archetype.body_color
		_coat_mat.roughness = 0.75
		customer_mesh.material_override = _coat_mat
		
	if beanie_mesh:
		var beanie_mat = StandardMaterial3D.new()
		beanie_mat.albedo_color = archetype.hat_color
		beanie_mat.roughness = 0.85
		beanie_mesh.material_override = beanie_mat
		
	if accessory_mesh:
		var acc_mat = StandardMaterial3D.new()
		match archetype.type:
			CustomerArchetype.ArchetypeType.BUSINESS:
				acc_mat.albedo_color = Color(0.1, 0.1, 0.12, 1) # Siyah deri çanta
				accessory_mesh.scale = Vector3(1.2, 1.4, 0.4)
			CustomerArchetype.ArchetypeType.TOURIST:
				acc_mat.albedo_color = Color(0.9, 0.8, 0.2, 1) # Sarı fotoğraf makinesi
				accessory_mesh.scale = Vector3(1.0, 0.8, 0.8)
			CustomerArchetype.ArchetypeType.CHILD:
				acc_mat.albedo_color = Color(0.2, 0.7, 0.9, 1) # Minik çocuk rozeti
				accessory_mesh.scale = Vector3(0.6, 0.6, 0.4)
			CustomerArchetype.ArchetypeType.GOURMET:
				acc_mat.albedo_color = Color(0.85, 0.85, 0.8, 1) # Beyaz ipek fular
				accessory_mesh.scale = Vector3(1.4, 0.5, 0.6)
			CustomerArchetype.ArchetypeType.INFLUENCER:
				acc_mat.albedo_color = Color(0.1, 0.9, 0.8, 1) # Neon kulaklık
				acc_mat.emission_enabled = true
				acc_mat.emission = Color(0.1, 0.9, 0.8, 1)
				acc_mat.emission_energy_multiplier = 1.2
				accessory_mesh.scale = Vector3(1.1, 1.1, 1.1)
		accessory_mesh.material_override = acc_mat

func set_highlight(enabled: bool) -> void:
	if _is_highlighted == enabled or _coat_mat == null:
		return
		
	_is_highlighted = enabled
	if enabled:
		_coat_mat.emission_enabled = true
		_coat_mat.emission = Color(0.4, 0.6, 0.9, 1.0) * 0.35
	else:
		_coat_mat.emission_enabled = false

func interact() -> void:
	if state == State.WAITING or state == State.ORDER_IN_PROGRESS or state == State.ORDER_READY or state == State.IMPATIENT:
		EventBus.order_delivery_attempted.emit()

func initialize(order: OrderData, start_pos: Vector3, counter_pos: Vector3, arch: CustomerArchetype = null) -> void:
	current_order = order
	if current_order:
		current_order.is_active = true
		current_order.is_completed = false
		
	_spawn_pos = start_pos
	_target_counter_pos = counter_pos
	global_position = start_pos
	_patience_depleted_timer = 0.0
	
	if arch:
		apply_archetype(arch)
		
	if speech_label_3d:
		speech_label_3d.text = "..."
		
	_start_arrival_tween()

func _start_arrival_tween() -> void:
	state = State.ARRIVING
	var duration = 2.4
	if archetype and archetype.walk_speed > 0:
		duration = 5.2 / archetype.walk_speed
		
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", _target_counter_pos, duration)
	tween.tween_callback(_on_arrived_at_counter)

func _on_arrived_at_counter() -> void:
	state = State.WAITING
	_is_score_decaying = true
	
	if speech_label_3d and current_order:
		var flavor_names: Array[String] = []
		for f in current_order.flavors:
			flavor_names.append(f.flavor_name)
		for t in current_order.toppings:
			flavor_names.append("+" + t.topping_name)
			
		var arch_tag = ("[%s] " % archetype.title_name) if archetype else ""
		speech_label_3d.text = arch_tag + " + ".join(flavor_names)
		speech_label_3d.modulate = Color(1, 1, 1, 1)
		
	EventBus.customer_arrived.emit(self, current_order)
	if current_order:
		EventBus.customer_score_updated.emit(current_order.current_score)

func entertain_with_bell(duration: float = 3.5) -> void:
	if state != State.WAITING and state != State.ORDER_IN_PROGRESS and state != State.IMPATIENT:
		return
		
	_freeze_timer = duration
	_patience_depleted_timer = max(0.0, _patience_depleted_timer - 4.0)
	if speech_label_3d:
		speech_label_3d.text = "Harika şov! 🎵"
		speech_label_3d.modulate = Color(1.0, 0.85, 0.35, 1.0)
		
	_pop_reaction(0.06)

func _process(delta: float) -> void:
	var safe_delta = min(delta, 0.05)
	_anim_time += safe_delta
	
	_update_visual_animations(safe_delta)
	_update_look_at(safe_delta)
	_update_score_and_patience(safe_delta)

func _update_visual_animations(delta: float) -> void:
	if not visual_pivot:
		return
		
	if state == State.ARRIVING or state == State.LEAVING:
		var step_freq = (archetype.walk_speed * 4.5) if archetype else 11.0
		var bob_y = abs(sin(_anim_time * step_freq)) * 0.035
		var tilt_z = sin(_anim_time * (step_freq * 0.5)) * deg_to_rad(3.5)
		visual_pivot.position.y = bob_y
		visual_pivot.rotation.z = tilt_z
	elif state == State.IMPATIENT:
		var tap_y = abs(sin(_anim_time * 9.0)) * 0.02
		var fidget_z = sin(_anim_time * 4.5) * deg_to_rad(2.5)
		visual_pivot.position.y = tap_y
		visual_pivot.rotation.z = fidget_z
	elif state == State.ORDER_READY:
		visual_pivot.rotation.x = lerp_angle(visual_pivot.rotation.x, deg_to_rad(8.0), 6.0 * delta)
		visual_pivot.position.y = sin(_anim_time * 3.0) * 0.01
	elif state == State.WAITING or state == State.ORDER_IN_PROGRESS:
		var breath_y = sin(_anim_time * 2.2) * 0.008
		var breath_z = sin(_anim_time * 1.2) * deg_to_rad(1.2)
		visual_pivot.position.y = breath_y
		visual_pivot.rotation.z = breath_z
		visual_pivot.rotation.x = lerp_angle(visual_pivot.rotation.x, 0.0, 6.0 * delta)

func _update_look_at(delta: float) -> void:
	if not head_pivot:
		return
		
	var target_yaw = 0.0
	var target_pitch = 0.0
	
	if state == State.ORDER_IN_PROGRESS or state == State.ORDER_READY:
		target_yaw = deg_to_rad(-12.0) # Sol eldeki külaha doğru
		target_pitch = deg_to_rad(-10.0) # Aşağıya doğru
	elif state == State.WAITING:
		target_yaw = sin(_anim_time * 0.8) * deg_to_rad(5.0)
		target_pitch = deg_to_rad(-4.0)
	elif state == State.IMPATIENT:
		target_yaw = sin(_anim_time * 3.5) * deg_to_rad(12.0)
		target_pitch = deg_to_rad(2.0)
	elif state == State.DISAPPOINTED:
		target_yaw = sin(_anim_time * 8.0) * deg_to_rad(16.0) # Başını iki yana sallama
		
	_target_look_y = lerp_angle(_target_look_y, target_yaw, 6.0 * delta)
	_target_look_x = lerp_angle(_target_look_x, target_pitch, 6.0 * delta)
	head_pivot.rotation.y = _target_look_y
	head_pivot.rotation.x = _target_look_x

func _update_score_and_patience(delta: float) -> void:
	if (state == State.WAITING or state == State.ORDER_IN_PROGRESS or state == State.IMPATIENT or state == State.ORDER_READY or state == State.DISAPPOINTED) and _is_score_decaying and current_order:
		if _freeze_timer > 0.0:
			_freeze_timer -= delta
		else:
			var decay = current_order.score_decay_rate
			if archetype:
				decay = archetype.score_decay_rate
				
			var patience_red = GameManager.get_upgrade_effect("patience_boost", "patience_decay_reduction")
			decay *= max(0.4, 1.0 - patience_red)
			
			if current_order.current_score > current_order.min_score:
				current_order.current_score = max(current_order.min_score, current_order.current_score - (decay * delta))
				EventBus.customer_score_updated.emit(current_order.current_score)
				
				# Sabırsızlanma durumuna geçiş
				if current_order.current_score < 3.2 and state != State.IMPATIENT and state != State.ORDER_READY:
					state = State.IMPATIENT
					if speech_label_3d:
						speech_label_3d.text = "Biraz acele edebilir misiniz?"
						speech_label_3d.modulate = Color(1.0, 0.65, 0.25, 1.0)
			else:
				_patience_depleted_timer += delta
				if _patience_depleted_timer >= MAX_PATIENCE_GRACE_TIME:
					_trigger_patience_timeout()

func _on_ice_cream_added(_flavor: FlavorData, total_count: int) -> void:
	if state == State.LEAVING or state == State.TIMEOUT or state == State.COMPLETED:
		return
		
	if state != State.ORDER_READY:
		state = State.ORDER_IN_PROGRESS
		
	if total_count >= 8:
		if speech_label_3d:
			speech_label_3d.text = "Vay canına! Dev kule!"
			speech_label_3d.modulate = Color(1.0, 0.85, 0.2, 1.0)
		_pop_reaction(0.08)
	elif total_count >= 5:
		if speech_label_3d:
			speech_label_3d.text = "Harika yükseliyor..."
			speech_label_3d.modulate = Color(0.8, 1.0, 0.5, 1.0)
		_pop_reaction(0.04)

func _on_order_progress_updated(progress_info: Dictionary) -> void:
	if state == State.LEAVING or state == State.TIMEOUT or state == State.COMPLETED:
		return
		
	if progress_info.get("is_completed", false):
		state = State.ORDER_READY
		if speech_label_3d:
			speech_label_3d.text = "Dondurmam hazır! [E] ile alabilirim."
			speech_label_3d.modulate = Color(0.4, 1.0, 0.5, 1.0)
	elif not progress_info.get("is_valid_so_far", true):
		state = State.DISAPPOINTED
		if speech_label_3d:
			speech_label_3d.text = "Bu benim istediğim aroma değil..."
			speech_label_3d.modulate = Color(1.0, 0.35, 0.35, 1.0)

func _pop_reaction(amount: float) -> void:
	if visual_pivot:
		var base_scale = archetype.scale_factor if archetype else Vector3.ONE
		var pop_tween = create_tween().set_trans(Tween.TRANS_QUAD)
		pop_tween.tween_property(visual_pivot, "scale", base_scale * (1.0 + amount), 0.08).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(visual_pivot, "scale", base_scale, 0.12).set_ease(Tween.EASE_OUT)

func _trigger_patience_timeout() -> void:
	if state == State.TIMEOUT or state == State.LEAVING or state == State.COMPLETED:
		return
		
	state = State.TIMEOUT
	_is_score_decaying = false
	set_highlight(false)
	
	if current_order:
		current_order.is_active = false
		
	GameManager.update_reputation(-2.5)
	GameManager.record_order_failed()
	EventBus.notification_requested.emit("Müşteri çok beklediği için kızıp ayrıldı! (-%2.5 İtibar)", 2.4)
	
	if speech_label_3d:
		speech_label_3d.text = "Çok bekledim, artık gidiyorum!"
		speech_label_3d.modulate = Color(1.0, 0.35, 0.35, 1.0)
		
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(_start_leaving_tween)

func complete_order(final_score: float) -> void:
	if state == State.COMPLETED or state == State.LEAVING or state == State.TIMEOUT:
		return
		
	state = State.DELIVERED
	_is_score_decaying = false
	set_highlight(false)
	
	if current_order:
		current_order.is_completed = true
		current_order.is_active = false
		current_order.current_score = final_score
		
	# 1. Elleri öne uzatıp külahı teslim alma hareketi
	if hands_pivot:
		var reach_tween = create_tween().set_trans(Tween.TRANS_CUBIC)
		reach_tween.tween_property(hands_pivot, "position:z", 0.24, 0.12).set_ease(Tween.EASE_OUT)
		reach_tween.tween_property(hands_pivot, "position:z", 0.0, 0.22).set_ease(Tween.EASE_OUT)
	
	# 2. Mutluluk Zıplaması (Happy Jump)
	if visual_pivot:
		var jump_tween = create_tween().set_trans(Tween.TRANS_QUAD)
		jump_tween.tween_property(visual_pivot, "position:y", 0.12, 0.12).set_ease(Tween.EASE_OUT)
		jump_tween.tween_property(visual_pivot, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	state = State.SATISFIED
	
	if speech_label_3d:
		if archetype and archetype.type == CustomerArchetype.ArchetypeType.BUSINESS:
			speech_label_3d.text = "Tam vaktinde! Harika (2x Bahşiş)"
		elif archetype and archetype.type == CustomerArchetype.ArchetypeType.CHILD:
			speech_label_3d.text = "Yaşasııın! Teşekkürler!"
		elif archetype and archetype.type == CustomerArchetype.ArchetypeType.GOURMET:
			speech_label_3d.text = "Mükemmel kıvam ve denge. Tebrikler!"
		elif archetype and archetype.type == CustomerArchetype.ArchetypeType.INFLUENCER:
			speech_label_3d.text = "İnanılmaz bir kule! Harika!"
		else:
			speech_label_3d.text = "Harika! Puan: %.2f" % final_score
		speech_label_3d.modulate = Color(0.4, 1.0, 0.5, 1.0)
		
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(_start_leaving_tween)

func _start_leaving_tween() -> void:
	if not is_inside_tree():
		return
		
	state = State.LEAVING
	var duration = 2.4
	if archetype and archetype.walk_speed > 0:
		duration = 5.2 / archetype.walk_speed
		
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", _spawn_pos + Vector3(2.5, 0, 0), duration)
	tween.tween_callback(func():
		EventBus.customer_left.emit(self)
		queue_free()
	)

func _on_cone_dropped() -> void:
	if (state == State.WAITING or state == State.ORDER_IN_PROGRESS or state == State.IMPATIENT) and current_order:
		var penalty = 0.40
		if archetype and archetype.type == CustomerArchetype.ArchetypeType.GOURMET:
			penalty = 0.65
		elif archetype and archetype.type == CustomerArchetype.ArchetypeType.CHILD:
			penalty = 0.20
			
		current_order.current_score = max(current_order.min_score, current_order.current_score - penalty)
		EventBus.customer_score_updated.emit(current_order.current_score)
		if speech_label_3d:
			speech_label_3d.text = "Aman dikkat! Yenisini bekliyorum."
			speech_label_3d.modulate = Color(1.0, 0.6, 0.2, 1.0)
