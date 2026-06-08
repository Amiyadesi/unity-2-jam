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
	_check("menu status label removed", menu.get_node_or_null("StatusLabel") == null)
	_check("menu footer key hint removed", menu.get_node_or_null("Hint") == null)
	var start_line := menu.get_node_or_null("StartLine") as Label
	_check("menu start line updated", start_line != null and start_line.text == "我期待与你的再会")
	var primary = menu.get_node_or_null("ButtonColumn/PrimaryButton")
	_check("PrimaryButton is ShaderButton", primary != null and primary.has_method("set_bbtext"))
	_check("PrimaryButton has hover sfx", primary != null and primary.get_node_or_null("HoverSfx") is AudioStreamPlayer and primary.get_node("HoverSfx").stream != null and primary.get_node("HoverSfx").bus == "UI")
	_check("PrimaryButton has press sfx", primary != null and primary.get_node_or_null("PressSfx") is AudioStreamPlayer and primary.get_node("PressSfx").stream != null and primary.get_node("PressSfx").bus == "UI")
	var settings = menu.get_node_or_null("SettingsScreen")
	var thanks = menu.get_node_or_null("ThanksScreen")
	_check("SettingsScreen present", settings != null)
	_check("ThanksScreen present", thanks != null)
	var thanks_body := thanks.get_node_or_null("Panel/Margin/VBox/Body") as RichTextLabel if thanks != null else null
	_check("thanks credits author Amiya_desi", thanks_body != null and thanks_body.text.contains("Amiya_desi"))
	_check("thanks credits sponsor unity2.ai", thanks_body != null and thanks_body.text.contains("unity2.ai"))
	_check("thanks credits PeriTune music", thanks_body != null and thanks_body.text.contains("PeriTune"))
	_check("settings removed fullscreen button", settings != null and settings.get_node_or_null("Panel/Margin/VBox/DisplayRow/FullscreenCheck") == null)
	_check("settings has UI volume slider", settings != null and settings.get_node_or_null("Panel/Margin/VBox/UiRow/UiSlider") is HSlider)
	_check("settings has Ambient volume slider", settings != null and settings.get_node_or_null("Panel/Margin/VBox/AmbientRow/AmbientSlider") is HSlider)
	var keybind_panel: Control = null
	var keybinding_ui = null
	if settings != null:
		keybind_panel = settings.get_node_or_null("Panel/Margin/VBox/KeybindPanel") as Control
		keybinding_ui = settings.get_node_or_null("Panel/Margin/VBox/KeybindPanel/KeybindingUI")
	_check("settings has keybinding UI", keybinding_ui != null)
	_check("settings keybind panel has room", keybind_panel != null and keybind_panel.custom_minimum_size.y >= 320.0)
	_check("settings keybinding UI has room", keybinding_ui != null and keybinding_ui.custom_minimum_size.y >= 320.0)
	_check("settings keybinding allowlist includes dash", keybinding_ui != null and "action_allowlist" in keybinding_ui and keybinding_ui.action_allowlist.has("dash"))

	# 回归守护："overlay 挡住菜单按钮"——close_mock 等常驻 overlay 的所有
	# 可见控件都必须 mouse_filter=IGNORE(2)，否则会挡住其覆盖范围内的按钮点击。
	var mock_packed = load("res://scenes/close_mock.tscn")
	var mock = mock_packed.instantiate()
	var bad := _find_input_catching(mock)
	_check("close_mock overlay is fully click-through", bad == "")
	if bad != "":
		print("    blocking node: ", bad)
	mock.free()
	await _check_info_flow_authored_pool()

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
	hud_player.drain_energy(58.0)
	await _wait(0.2)
	_check("energy HUD label follows player energy", hud_label != null and hud_label.text == "42")
	_check("energy HUD fill shrinks", hud_fill != null and hud_fill.size.x < 260.0)
	holder.queue_free()

	# --- post-game OpenAI note is a paper note, not a black-screen scene ---
	var note = load("res://scenes/openai_note.tscn").instantiate()
	root.add_child(note)
	await process_frame
	await process_frame
	var paper = note.get_node_or_null("Paper")
	_check("OpenAI note has paper", paper is PanelContainer)
	_check("OpenAI note has no black background", note.get_node_or_null("Background") == null)
	_check("OpenAI note sits bottom-right", paper != null and paper.anchor_left >= 0.99 and paper.anchor_top >= 0.99)
	_check("OpenAI note removes hint body", note.get_node_or_null("Paper/Margin/Lines/Body") == null)
	_check("OpenAI note removes click footer", note.get_node_or_null("Paper/Margin/Lines/Footer") == null)
	_check("OpenAI note click closes shell", _read_res_text("res://scripts/ui/openai_note.gd").contains("GameFlow.self_close(\"openai_note\")"))
	_check("OpenAI note root catches paper clicks", _read_res_text("res://scripts/ui/openai_note.gd").contains("_paper.get_global_rect().has_point"))
	note.queue_free()

	if gf: gf.reset_progress()
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)


## 确认 InfoFlow/InfoOverlay 由 authored scene 和固定池承载，不运行时新增 UI 节点。
func _check_info_flow_authored_pool() -> void:
	var flow_scene: PackedScene = load("res://scenes/info_flow.tscn")
	_check("InfoFlow authored scene loads", flow_scene != null)
	if flow_scene == null:
		return
	var flow = flow_scene.instantiate()
	root.add_child(flow)
	await process_frame
	var overlay = flow.get_node_or_null("InfoOverlay")
	_check("InfoFlow authored child InfoOverlay", overlay != null and overlay.has_method("show_toast"))
	var breadcrumb_pool := overlay.get_node_or_null("OverlayRoot/BreadcrumbFeed/BreadcrumbPool") if overlay != null else null
	var hint_pool := overlay.get_node_or_null("OverlayRoot/HintFeed/HintPool") if overlay != null else null
	_check("InfoOverlay authored breadcrumb pool", breadcrumb_pool != null and breadcrumb_pool.get_child_count() >= 4)
	_check("InfoOverlay authored hint pool", hint_pool != null and hint_pool.get_child_count() >= 2)
	if overlay != null and breadcrumb_pool != null and hint_pool != null:
		var breadcrumb_count := breadcrumb_pool.get_child_count()
		var hint_count := hint_pool.get_child_count()
		overlay.show_toast(0.08, "T", "池化提示", "top_right")
		overlay.show_hint("test", "常驻提示", "show", "right")
		await process_frame
		_check("InfoOverlay toast uses existing pool item", breadcrumb_pool.get_child_count() == breadcrumb_count)
		_check("InfoOverlay hint uses existing pool item", hint_pool.get_child_count() == hint_count)
		overlay.hide_hint("test")
		await _wait(0.12)
		_check("InfoOverlay returns pool items hidden", _pool_all_hidden(breadcrumb_pool) and _pool_all_hidden(hint_pool))
		overlay.show_toast(0.25, "", "底部教学", "bottom+0,-40@520x72")
		await process_frame
		var bottom_item := _first_visible_control(breadcrumb_pool)
		var bottom_position := bottom_item.position if bottom_item != null else Vector2.ZERO
		overlay.show_toast(0.25, "", "右上计数", "top_right+0,12@200x56")
		await process_frame
		_check("InfoOverlay keeps existing toast layout when another layout appears", bottom_item != null and bottom_item.visible and bottom_item.position.is_equal_approx(bottom_position))
		await _wait(0.3)
	flow.queue_free()


## 检查池内控件是否全部归还隐藏。
func _pool_all_hidden(pool: Node) -> bool:
	for child in pool.get_children():
		if child is Control and (child as Control).visible:
			return false
	return true


## 返回池中第一条可见 Control，供布局迁移回归检查使用。
func _first_visible_control(pool: Node) -> Control:
	for child in pool.get_children():
		if child is Control and (child as Control).visible:
			return child as Control
	return null


## 读取 res:// 文本，用于轻量静态回归检查。
func _read_res_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text
