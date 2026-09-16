extends Node

var checks := 0
var failures: Array[String] = []
var main: Node3D
var manager: CustomerManager
var hand: LeftHandController
var hud: HUD
var last_quote: Dictionary = {}
var capture_dir := ""

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func close(actual: float, expected: float, message: String) -> void:
	check(absf(actual - expected) < 0.005, "%s (%.3f expected %.3f)" % [message, actual, expected])

func pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func archetype(kind: int) -> CustomerArchetype:
	var arch := CustomerArchetype.new()
	arch.type = kind as CustomerArchetype.ArchetypeType
	return arch

func _ready() -> void:
	# Test saves must never replace the player's career.
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		push_error("Run with XDG_DATA_HOME set to a temporary directory.")
		get_tree().quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
	get_tree().create_timer(180.0).timeout.connect(func():
		push_error("Regression watchdog: tests did not finish")
		get_tree().quit(2)
	)
	_run.call_deferred()

func _run() -> void:
	seed(12345)
	_test_reward_math()
	_test_show_policy()
	EventBus.reward_quote_updated.connect(func(quote): last_quote = quote)
	GameManager.day_active = false
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	# Desktop mouse motion must not steer the automated scene.
	main.get_node("PlayerRig").set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	manager = main.get_node("CustomerManager")
	hand = main.get_node("PlayerRig/Camera3D/LeftHandRig")
	hud = main.get_node("HUD")
	await get_tree().process_frame
	await _test_lifecycle()
	await _test_full_day()
	print("SHOW REGRESSION: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		print("  FAIL: " + failure)
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_reward_math() -> void:
	GameManager.current_daily_event_id = "NORMAL"
	close(GameManager.get_balance_event_multiplier(), 1.0, "Normal day keeps base balance tolerance")
	GameManager.current_daily_event_id = "HEATWAVE"
	close(GameManager.get_balance_event_multiplier(), 0.90, "Heatwave tightens balance tolerance")
	GameManager.current_daily_event_id = "NORMAL"
	var order := OrderData.new()
	order.flavors.assign([GameManager.get_flavor_by_id("sade"), GameManager.get_flavor_by_id("cikolata")])
	var sauce := GameManager.get_topping_by_id("cikolata_sos")
	order.toppings.append(sauce)
	var arch := archetype(CustomerArchetype.ArchetypeType.TOURIST)
	arch.tip_multiplier = 1.5
	arch.topping_bonus = 2.0
	var quote := OrderReward.calculate(order, arch, 5.0, 0.0, [], 0.0)
	close(quote.base, 10.0 + sauce.extra_price, "Required sauce included in base price")
	close(quote.tip, snappedf((10.0 + sauce.extra_price) * 0.6, 0.01), "Customer multiplier included")
	close(quote.show, 0.0, "No show means no show reward")
	close(quote.gift, 0.0, "Required sauce is not a gift")
	order.current_score = 3.0
	quote = OrderReward.calculate(order, arch, 6.0, 0.30, [sauce], 7.25)
	close(quote.base, 12.0 + sauce.extra_price, "Heatwave scoop price included")
	close(quote.tip, snappedf((12.0 + sauce.extra_price) * 0.6 * 0.4 * 1.8, 0.01), "Score and tip upgrade included")
	close(quote.total, quote.base + quote.tip + 2.0 + 7.25, "Quote reconciles all four components")
	close(order.current_score, 3.0, "Quoting does not mutate order score")

func _test_show_policy() -> void:
	for kind in CustomerArchetype.ArchetypeType.values():
		var session := ShowSession.new(archetype(kind))
		var first := session.complete("tease")
		var second := session.complete("tease")
		var third := session.complete("tease")
		check(first.amount > second.amount, "Repeat has diminishing returns for archetype %d" % kind)
		close(third.amount, 0.0, "Third identical trick earns nothing")
		if kind == CustomerArchetype.ArchetypeType.BUSINESS:
			close(second.penalty, 0.35, "Business customer penalizes prolonged show")
		var total_pause := float(first.pause + second.pause + third.pause)
		for i in range(100):
			for action in ["tease", "flip", "catch", "bell"]:
				var result := session.complete(action, true)
				total_pause += result.pause
		check(session.cone_bonus <= float(session.profile.cap), "Customer cap holds across 400 repeated actions")
		check(total_pause <= float(session.profile.pause) + 0.001, "Patience budget includes bell and catch")
		var used := session.pause_used
		var awarded := session.awarded
		session.lose_cone()
		close(session.cone_bonus, 0.0, "Losing cone forfeits unclaimed money")
		close(session.awarded, awarded, "Losing cone does not reset customer cap")
		close(session.pause_used, used, "Losing cone does not reset patience budget")
		close(session.complete("catch").amount, 0.0, "New cone cannot farm rescue rewards")
	var tourist := ShowSession.new(archetype(CustomerArchetype.ArchetypeType.TOURIST))
	close(tourist.complete("tease").amount, 3.5, "Tourist first tease earns $3.50")
	close(tourist.complete("flip").amount, 6.5, "Tourist first different move earns variety bonus")
	var influencer := ShowSession.new(archetype(CustomerArchetype.ArchetypeType.INFLUENCER))
	close(influencer.complete("tease").amount, 4.0, "Influencer first move")
	close(influencer.complete("flip").amount, 9.0, "Influencer rewards varied sequence")
	var gourmet := ShowSession.new(archetype(CustomerArchetype.ArchetypeType.GOURMET))
	close(gourmet.complete("flip", true, 4.0).amount, 8.0, "Gourmet rewards correct high-quality flip")
	gourmet = ShowSession.new(archetype(CustomerArchetype.ArchetypeType.GOURMET))
	close(gourmet.complete("flip", false).amount, 6.0, "Incomplete recipe has no gourmet quality premium")
	gourmet = ShowSession.new(archetype(CustomerArchetype.ArchetypeType.GOURMET))
	close(gourmet.complete("flip", true, 3.9).amount, 6.0, "Low score has no gourmet quality premium")

func wait_for_customer() -> bool:
	for frame in range(900):
		if manager.active_customer and manager.active_customer.accepts_service():
			await get_tree().process_frame
			return true
		await get_tree().process_frame
	check(false, "Customer arrives within 15 simulated seconds")
	return false

func prepare_order() -> void:
	hand.reset_cone()
	hand.take_cone()
	for flavor in manager.active_order.flavors:
		hand._finalize_add_scoop(flavor)
	for topping in manager.active_order.toppings:
		hand._on_topping_applied(topping)
	hand.current_angle_deg = 0.0
	hand.angular_velocity = 0.0

func settle_quote(message: String) -> void:
	var quote := manager.get_reward_quote()
	var before := GameManager.current_money
	var successes := GameManager.successful_orders
	close(last_quote.total, quote.total, message + ": HUD quote matches settlement")
	check(hud.order_score_label.text.contains("$%.2f" % quote.total), message + ": rendered label matches quote")
	EventBus.order_delivery_attempted.emit()
	close(GameManager.current_money - before, quote.total, message + ": bank receives quoted amount")
	check(GameManager.successful_orders == successes + 1, message + ": exactly one successful order")
	EventBus.order_delivery_attempted.emit()
	close(GameManager.current_money - before, quote.total, "Duplicate delivery cannot pay twice")
	check(not hand.has_cone() and not hand.is_action_busy(), "Delivery clears hand and animation state")
	check(not hud._latest_progress_info.get("is_completed", false), "Delivery removes the stale deliver prompt")

func _test_lifecycle() -> void:
	GameManager.start_day(1)
	if not await wait_for_customer(): return
	# Controlled customer type for exact integration expectations.
	manager.active_archetype = manager._archetypes[1]
	manager.active_customer.apply_archetype(manager.active_archetype)
	manager.show_session = ShowSession.new(manager.active_archetype)
	EventBus.customer_arrived.emit(manager.active_customer, manager.active_order)
	await get_tree().process_frame
	prepare_order()
	check(hand.perform_trick(), "Tease starts for waiting customer with ice cream")
	close(manager.show_session.cone_bonus, 0.0, "Starting animation does not award money")
	check(not hand.flip_cone() and not hand.perform_trick(), "Overlapping shows are blocked")
	var before := GameManager.current_money
	EventBus.order_delivery_attempted.emit()
	close(GameManager.current_money, before, "Cannot deliver during a show")
	await pause(0.7)
	close(manager.show_session.cone_bonus, 3.5, "Finished tease awarded exactly once")
	EventBus.show_completed.emit("tease")
	close(manager.show_session.cone_bonus, 3.5, "Duplicate completion ignored")
	await pause(0.6)
	hand.current_angle_deg = 12.0
	hand.angular_velocity = 2.0
	check(hand.flip_cone(), "Flip starts after tease cooldown")
	close(hand.current_angle_deg, 12.0, "Flip preserves tilt instead of granting free recovery")
	close(hand.angular_velocity, 2.0, "Flip preserves angular momentum")
	close(manager.show_session.cone_bonus, 3.5, "Flip start has no reward")
	await pause(0.4)
	check(absf(hand.cone_pivot.rotation.z) > 2.5, "Flip visibly holds cone upside down (rotation %.3f, active %s)" % [hand.cone_pivot.rotation.z, hand.is_flipping])
	await capture("01-flip")
	await pause(0.9)
	close(manager.show_session.cone_bonus, 10.0, "Completed varied flip earns $6.50")
	check(hud.order_score_label.text.contains("Şov $10.00"), "HUD shows accumulated bonus")
	await capture("02-show-quote")
	settle_quote("Show order")
	await pause(0.7)
	check(not hand.perform_trick(), "No show after delivery")

	if not await wait_for_customer(): return
	close(manager.show_session.cone_bonus, 0.0, "Next customer starts without previous bonus")
	prepare_order()
	check(hand.perform_trick(), "Cancellation scenario starts")
	hand.discard_cone_to_trash()
	check(not hand.is_performing_trick, "Discard cancels active animation immediately")
	check(hand.is_action_busy(), "Disposal animation holds hand busy")
	hand.reach_and_take_cone()
	check(not hand.is_reaching_cone, "Cannot take new cone during disposal")
	await pause(0.8)
	close(manager.show_session.cone_bonus, 0.0, "Cancelled tease never pays later")
	check(not hand.has_cone() and not hand.is_action_busy(), "Discard finishes with clean state")

	prepare_order()
	check(hand.flip_cone(), "Flip cancellation scenario starts")
	hand.reset_cone()
	await pause(1.4)
	close(manager.show_session.cone_bonus, 0.0, "Reset cancels delayed flip payout")
	check(not hand.is_flipping and not hand.is_action_busy(), "Reset releases all action flags")
	prepare_order()
	check(hand.perform_trick(), "Earned-bonus reset scenario starts")
	await pause(0.7)
	check(manager.show_session.cone_bonus > 0.0, "Scenario has an earned bonus to forfeit")
	var lifetime_award := manager.show_session.awarded
	hand.reset_cone()
	close(manager.show_session.cone_bonus, 0.0, "Direct cone reset also forfeits earned bonus")
	close(manager.show_session.awarded, lifetime_award, "Direct reset preserves lifetime budget")
	await pause(0.6)

	prepare_order()
	var right: RightHandController = main.get_node("PlayerRig/Camera3D/RightHandRig")
	right.current_scooped_flavor = GameManager.get_flavor_by_id("sade")
	EventBus.place_on_cone_attempted.emit()
	check(hand.is_action_busy() and not hand.perform_trick(), "Scoop transfer excludes shows")
	hand.reset_cone()
	hand.take_cone()
	await pause(0.4)
	check(hand.stacked_flavors.is_empty(), "Cancelled transfer cannot add scoop to replacement cone")
	check(not hand.is_action_busy() and not is_instance_valid(hand._flying_scoop), "Cancelled transfer releases animation and flying mesh")
	prepare_order()
	check(hand.perform_trick(), "Drop scenario starts")
	hand._trigger_cone_drop()
	await pause(0.8)
	close(manager.show_session.cone_bonus, 0.0, "Dropping mid-show cancels reward")
	check(not hand.has_cone(), "Drop animation finishes")

	prepare_order()
	hand._start_clutch_window(1.0)
	check(not hand.flip_cone() and not hand.perform_trick(), "Rescue excludes other shows")
	before = GameManager.current_money
	EventBus.order_delivery_attempted.emit()
	close(GameManager.current_money, before, "Cannot deliver during rescue")
	Input.action_press("balance_left")
	await pause(0.05)
	Input.action_release("balance_left")
	check(not hand.is_clutch_active, "Opposite balance input rescues cone")
	check(manager.show_session.cone_bonus > 0.0, "Successful rescue awards a bonus")
	var rescue_bonus := manager.show_session.cone_bonus
	hand._clutch_recover()
	close(manager.show_session.cone_bonus, rescue_bonus, "Repeated recovery callback cannot pay twice")
	settle_quote("Rescue order")

	if not await wait_for_customer(): return
	prepare_order()
	hand._start_clutch_window(-1.0)
	await pause(1.0)
	check(not hand.has_cone(), "Failed rescue drops the cone")
	close(manager.show_session.cone_bonus, 0.0, "Failed rescue pays nothing")
	check(not hud._is_clutch_ui_active, "Failed rescue clears HUD warning")
	prepare_order()
	check(hand.flip_cone(), "Timeout scenario starts during flip")
	manager.active_customer._trigger_patience_timeout()
	check(not hand.is_flipping and not hand.is_action_busy(), "Timeout cancels show immediately")
	check(not hand.perform_trick(), "Timed-out customer cannot receive new shows")
	await pause(1.4)
	close(manager.show_session.cone_bonus, 0.0, "Timeout leaves no delayed payout")
	check(not hud.order_card_container.visible, "Timeout hides stale quote")

	if not await wait_for_customer(): return
	check(not hand.has_cone(), "Failed order cone is cleared before new customer")
	close(manager.show_session.pause_used, 0.0, "New customer receives fresh patience budget")
	prepare_order()
	var waiting_customer := manager.active_customer
	var score_before := manager.active_order.current_score
	for i in range(20):
		manager._on_bell_rung(i)
	check(waiting_customer._freeze_timer <= float(manager.show_session.profile.pause), "Bell spam cannot exceed live patience budget")
	for frame in range(600):
		waiting_customer._update_score_and_patience(1.0 / 60.0)
	check(manager.active_order.current_score < score_before, "Live score decays after finite entertainment budget")
	close(manager.show_session.cone_bonus, 0.0, "Bell spam earns no show money")
	settle_quote("No-show order")
	# Stop spawning before resetting the test day.
	GameManager.day_active = false
	await pause(5.0)
	check(manager.active_customer == null, "Last customer leaves normally")

func _test_full_day() -> void:
	GameManager.current_money = 50.0
	GameManager.current_reputation = 100.0
	GameManager.start_day(1)
	# Heatwave + upgrade exercise live quote refresh using real upgrade data.
	GameManager.current_daily_event_id = "HEATWAVE"
	GameManager.upgrades["tip_mastery"].current_level = 2
	var expected_base := 0.0
	var expected_tip := 0.0
	var expected_gift := 0.0
	var expected_show := 0.0
	for index in range(10):
		if not await wait_for_customer(): return
		prepare_order()
		if index % 2 == 0:
			check(hand.perform_trick(), "Full day: show starts on order %d" % index)
			await pause(0.7)
		if index % 3 == 0:
			for topping in GameManager.get_all_toppings():
				if not hand.applied_toppings.has(topping):
					hand._on_topping_applied(topping)
					break
		var quote := manager.get_reward_quote()
		expected_base += quote.base
		expected_tip += quote.tip
		expected_gift += quote.gift
		expected_show += quote.show
		settle_quote("Full day order %d" % (index + 1))
	await pause(5.0)
	check(not GameManager.day_active and GameManager.day_state == GameState.DayState.SUMMARY, "Ten deliveries finish the full day")
	var summary := GameManager.get_day_summary()
	close(summary.base_revenue, expected_base, "Day report base revenue reconciles")
	close(summary.tips, expected_tip, "Day report tips reconcile")
	close(summary.bonus, expected_gift, "Day report gifts reconcile")
	close(summary.show_bonus, expected_show, "Day report separately totals show income")
	close(summary.total_earned, expected_base + expected_tip + expected_gift + expected_show, "Day report total reconciles")
	close(summary.final_money - 50.0, summary.total_earned, "Day bank equals all settled quotes")
	var dialog: DaySummaryDialog = hud.get_node("DaySummaryDialog")
	check(dialog.visible and dialog.revenue_breakdown_label.text.contains("Şov Geliri:"), "Visible summary separates show income")
	await capture("03-day-summary")
	dialog._on_continue_pressed()
	check(hud.get_node("ShopDialog").visible, "Summary continues into the shop")
	var shop: ShopDialog = hud.get_node("ShopDialog")
	await get_tree().process_frame
	check(shop.items_container.get_child_count() > 0, "Shop renders actual upgrade cards")
	var money_before := GameManager.current_money
	var level_before: int = GameManager.upgrades["scoop_speed"].current_level
	var cost: float = GameManager.upgrades["scoop_speed"].get_cost_for_next_level()
	var buy_button: Button = shop.items_container.get_child(0).get_child(0).get_child(1).get_child(0)
	buy_button.pressed.emit()
	check(GameManager.upgrades["scoop_speed"].current_level == level_before + 1, "Upgrade purchase button works")
	close(GameManager.current_money, money_before - cost, "Upgrade button charges displayed price")
	shop.start_day_button.pressed.emit()
	check(GameManager.current_day == 2 and GameManager.day_active, "Day two starts")
	close(GameManager.daily_show_bonus, 0.0, "Day two resets daily show accounting")
	if not await wait_for_customer(): return
	close(manager.show_session.cone_bonus, 0.0, "Day two has fresh show session")

func capture(filename: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var screenshot := get_viewport().get_texture().get_image()
	var error := screenshot.save_png(capture_dir.path_join(filename + ".png"))
	check(error == OK, "Screenshot saved: " + filename)
