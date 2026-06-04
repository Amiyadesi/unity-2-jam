extends SceneTree
## test_ui.gd — 验证菜单/设置/感谢模态 + 玩家飞行形态
## 运行：godot --headless --path . --script res://tools/test_ui.gd

var _failures := 0
var _checks := 0

func _init() -> void:
	call_deferred("_run")

func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  [PASS] " if cond else "  [FAIL] ") + label)
	if not cond:
		_failures += 1

func _wait(t: float) -> void:
	var timer := root.get_tree().create_timer(t)
	await timer.timeout

func _run() -> void:
	print("=== CloseAI UI + flight test ===")
	await process_frame
	await process_frame
	var gf = root.get_node_or_null("GameFlow")
	if gf: gf.reset_progress()

	# --- menu instantiates with ShaderButtons ---
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	_check("menu instantiates", is_instance_valid(menu))
	var primary = menu.get_node_or_null("ButtonColumn/PrimaryButton")
	_check("PrimaryButton is ShaderButton", primary != null and primary.has_method("set_bbtext"))
	var settings = menu.get_node_or_null("SettingsScreen")
	var thanks = menu.get_node_or_null("ThanksScreen")
	_check("SettingsScreen present", settings != null)
	_check("ThanksScreen present", thanks != null)

	# --- settings modal open/close ---
	if settings != null and settings.has_method("open_modal"):
		settings.open_modal()
		await _wait(0.4)
		_check("settings opens (visible)", settings.visible)
		_check("settings is_open()", settings.is_open())
		settings.close_modal()
		await _wait(0.4)
		_check("settings closes (hidden)", not settings.visible)

	# --- thanks modal open/close ---
	if thanks != null and thanks.has_method("open_modal"):
		thanks.open_modal()
		await _wait(0.4)
		_check("thanks opens", thanks.visible)
		thanks.close_modal()
		await _wait(0.4)
		_check("thanks closes", not thanks.visible)
	menu.queue_free()
	await process_frame

	# --- player flight form ---
	var p = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	await process_frame
	_check("player has morphed property", "morphed" in p)
	_check("player starts unmorphed", p.morphed == false)
	if p.has_method("play_action"):
		await p.play_action("transform")
		_check("transform -> morphed true", p.morphed == true)
		# simulate flight physics tick (no crash, no gravity pinning)
		await _wait(0.2)
		_check("morphed player alive after fly ticks", is_instance_valid(p))
		await p.play_action("untransform")
		_check("untransform -> morphed false", p.morphed == false)
	p.queue_free()

	if gf: gf.reset_progress()
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)
