extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for i in range(100):
		AudioManager.play_sfx("bell_hit")
		AudioManager.play_sfx("cone_wobble")
	await get_tree().process_frame
	var released: bool = await AudioManager.shutdown_and_drain()
	AudioManager.play_sfx("bell_hit")
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			released = released and player.stream == null and not player.playing
	print("AUDIO REGRESSION: %s" % ("PASS" if released else "FAIL"))
	get_tree().quit(0 if released else 1)
