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

## 递归查找 overlay 里任何会拦截鼠标（mouse_filter != IGNORE）的 Control。
## 返回第一个违规节点路径；全部 click-through 则返回 ""。
func _find_input_catching(node: Node) -> String:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return str(node.get_path())
	for c in node.get_children():
		var r := _find_input_catching(c)
		if r != "":
			return r
	return ""

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

	# 回归守护："overlay 挡住菜单按钮"——close_mock 等常驻 overlay 的所有
	# 可见控件都必须 mouse_filter=IGNORE(2)，否则会挡住其覆盖范围内的按钮点击。
	var mock_packed = load("res://scenes/close_mock.tscn")
	var mock = mock_packed.instantiate()
	var bad := _find_input_catching(mock)
	_check("close_mock overlay is fully click-through", bad == "")
	if bad != "":
		print("    blocking node: ", bad)
	mock.free()

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
	await process_frame

	# --- energy HUD binds to authored player and updates fill/label ---
	var holder := Node2D.new()
	root.add_child(holder)
	var hud_player = load("res://scenes/player.tscn").instantiate()
	hud_player.name = "Player"
	holder.add_child(hud_player)
	hud_player.frozen = true
	var hud = load("res://scenes/ui/energy_hud.tscn").instantiate()
	hud.player_path = NodePath("../Player")
	holder.add_child(hud)
	await process_frame
	await process_frame
	_check("energy HUD instantiates", is_instance_valid(hud))
	var hud_label = hud.get_node_or_null("Root/BarFrame/Label")
	var hud_fill = hud.get_node_or_null("Root/BarFrame/FillClip/Fill")
	_check("energy HUD label present", hud_label is Label)
	_check("energy HUD fill present", hud_fill is ColorRect)
	hud_player._set_energy(42.0)
	await _wait(0.2)
	_check("energy HUD label follows player energy", hud_label != null and hud_label.text == "42")
	_check("energy HUD fill shrinks", hud_fill != null and hud_fill.size.x < 260.0)
	holder.queue_free()

	if gf: gf.reset_progress()
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)
