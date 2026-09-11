extends Node

# --- ETKİLEŞİM SİNYALLERİ ---
signal player_interacted(target_collider: Object)
signal player_secondary_interacted(target_collider: Object)
signal interaction_target_changed(tooltip_text: String)
signal cone_dispenser_interacted
signal trash_can_interacted
signal tub_switch_interacted
signal order_delivery_attempted
signal bell_rung(ring_count: int)

# --- KEPÇE VE DONDURMA FİZİĞİ ---
signal scoop_dive_started(tub_node: Node3D, flavor: FlavorData, hit_point: Vector3)
signal scoop_dive_progress(progress_ratio: float)
signal scoop_dive_cancelled
signal scoop_filled(flavor: FlavorData)
signal place_on_cone_attempted
signal ice_cream_added(flavor: FlavorData, stack_index: int)
signal ice_cream_placed_on_cone(flavor: FlavorData, stack_index: int)
signal scoop_state_changed(has_ice_cream: bool, flavor: FlavorData)

# --- SOS VE SÜSLEME SİSTEMİ ---
signal topping_applied(topping: ToppingData)
signal topping_added_to_cone(topping: ToppingData)

# --- KÜLAH VE DENGE DURUMU ---
signal cone_taken
signal cone_discarded
signal cone_dropped
signal cone_reset
signal cone_state_changed(state_name: String, current_count: int, flavors: Array[FlavorData])
signal cone_balance_updated(balance_ratio: float, current_angle_deg: float)
signal cone_critical_tilt(tilt_ratio: float)
signal maras_trick_performed(trick_count: int, multiplier: float)
signal cone_flipped(is_flipped: bool)
signal clutch_window_started(fall_direction: float, duration: float)
signal clutch_catch_succeeded
signal clutch_catch_failed

# --- MÜŞTERİ VE SİPARİŞ SİSTEMİ ---
signal customer_arrived(customer_node: Node3D, order: OrderData)
signal customer_score_updated(current_score: float)
signal order_progress_updated(progress_info: Dictionary)
signal order_completed(order: OrderData, final_score: float)
signal customer_left(customer_node: Node3D)

# --- GÜN DÖNGÜSÜ VE EKONOMİ ---
signal day_started(day_number: int, target_customers: int)
signal day_progress_updated(served_count: int, target_count: int)
signal day_completed(summary_data: Dictionary)
signal next_day_started(day_number: int)
signal daily_event_announced(event_id: String, title: String, description: String)
signal shop_opened
signal shop_closed
signal upgrade_purchased(upgrade_id: String, new_level: int)

# --- EKONOMİ VE ARAYÜZ BİLDİRİMLERİ ---
signal money_changed(new_amount: float, diff: float)
signal reputation_changed(new_reputation: float, diff: float)
signal notification_requested(text: String, duration: float)
