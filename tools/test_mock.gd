extends SceneTree
## test_mock.gd — 验证关闭嘲讽链路（反转模型核心）
## 运行：godot --headless --path . --script res://tools/test_mock.gd
##
## headless 下 GameFlow 不会自动 spawn overlay，这里手动实例化后断言：
##  - 普通关闭尝试 → overlay 面板浮现（modulate.a 上升）
##  - 强杀恢复首次尝试 → 用 POST_KILL 狠话
##  - 多次尝试 → 嘲讽升级（标题随次数变化）

var _failures: int = 0
var _checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  [PASS] " if cond else "  [FAIL] ") + label)
	if not cond:
		_failures += 1

func _run() -> void:
	print("=== CloseAI close-mock test ===")
	await process_frame
	await process_frame
	var gf = root.get_node_or_null("GameFlow")
	_check("GameFlow exists", gf != null)
	if gf == null:
		_finish()
		return

	# 手动实例化 overlay（headless 下不自动 spawn）
	var packed = load("res://scenes/close_mock.tscn")
	_check("close_mock scene loads", packed != null)
	if packed == null:
		_finish()
		return
	var overlay = packed.instantiate()
	root.add_child(overlay)
	await process_frame
	_check("overlay instantiated", is_instance_valid(overlay))

	var panel = overlay.get_node_or_null("Root/Panel")
	var title = overlay.get_node_or_null("Root/Panel/Margin/VBox/TitleLine")
	_check("overlay panel exists", panel != null)
	_check("overlay panel starts hidden", panel != null and panel.modulate.a < 0.01)

	# 普通关闭尝试 1
	gf.entered_with_unclean_exit = false
	gf.close_attempt_count = 0
	gf._on_player_close_attempt()
	# 等面板闪入（tween 0.08s）
	await create_timer_await(0.2)
	_check("attempt 1 reveals panel", panel != null and panel.modulate.a > 0.5)
	var title_1 = title.text if title != null else ""

	# 普通关闭尝试 2/3/4：标题应升级（与第1条不同）
	gf._on_player_close_attempt()
	await create_timer_await(0.15)
	gf._on_player_close_attempt()
	await create_timer_await(0.15)
	var title_later = title.text if title != null else ""
	_check("taunt escalates (title changes)", title_1 != title_later)

	# 强杀恢复：新建 overlay 验证 POST_KILL 狠话
	overlay.queue_free()
	await process_frame
	var overlay2 = packed.instantiate()
	root.add_child(overlay2)
	await process_frame
	var title2 = overlay2.get_node_or_null("Root/Panel/Margin/VBox/TitleLine")
	gf.entered_with_unclean_exit = true
	gf.close_attempt_count = 0
	gf._on_player_close_attempt()
	await create_timer_await(0.2)
	_check("post-kill taunt uses harsh title", title2 != null and title2.text == "哦，是你")

	overlay2.queue_free()
	gf.entered_with_unclean_exit = false
	_finish()

func create_timer_await(t: float) -> Signal:
	return create_timer(t).timeout

func _finish() -> void:
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)
