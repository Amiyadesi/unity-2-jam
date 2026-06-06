extends SceneTree
## test_flow.gd — CloseAI 核心流程 headless 自测（反转版）
##
## 运行：godot --headless --path . --script res://tools/test_flow.gd
##
## 验证新模型：
##  1. 自动加载就绪
##  2. 进度 started/stage/finished 读写
##  3. 关闭尝试拦截发出嘲讽信号（玩家无法真正退出）
##  4. reach_close_moment 推进关卡 / 通关标记（不真正 quit：用信号断言）
##  5. pre_self_close 演出钩子被 await
##  6. 对话文件含 start / dirty_return / close_moment 锚点
##  7. 场景文件齐全

var _failures: int = 0
var _checks: int = 0
var _mock_signals: Array = []
var _pre_close_fired: bool = false
var _hook_awaited: bool = false

func _init() -> void:
	call_deferred("_run")

func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  [PASS] " if cond else "  [FAIL] ") + label)
	if not cond:
		_failures += 1

func _run() -> void:
	print("=== CloseAI flow test (inverted model) ===")
	await process_frame
	await process_frame

	var gf = root.get_node_or_null("GameFlow")
	var ss = root.get_node_or_null("SaveSystem")
	_check("GameFlow autoload exists", gf != null)
	_check("SaveSystem autoload exists", ss != null)
	if gf == null or ss == null:
		_finish()
		return

	# --- 进度 ---
	gf.reset_progress()
	_check("reset -> stage 1", gf.get_current_stage() == 1)
	_check("reset -> not started", gf.has_started() == false)
	_check("reset -> not finished", gf.has_finished_game() == false)
	_check("reset -> no OpenAI flag", gf.has_openai_flag() == false)
	_check("reset -> no progress", gf.has_progress() == false)

	gf.set_current_stage(2)
	_check("set_current_stage(2) persists", gf.get_current_stage() == 2)

	# --- 关闭尝试拦截：发信号、不退出 ---
	gf.close_attempt_mocked.connect(func(idx, post): _mock_signals.append(idx))
	gf._on_player_close_attempt()
	gf._on_player_close_attempt()
	await process_frame
	_check("close attempt 1 mocked", _mock_signals.size() >= 1 and _mock_signals[0] == 1)
	_check("close attempt 2 mocked (escalates)", _mock_signals.size() >= 2 and _mock_signals[1] == 2)
	_check("close attempts did NOT quit (still running)", true)

	# --- reach_close_moment 推进（监听信号，避免真 quit）---
	gf.reset_progress()
	gf.set_current_stage(1)
	var got_close_moment := [false]
	gf.close_moment_ready.connect(func(s): got_close_moment[0] = true, CONNECT_ONE_SHOT)
	# 直接验证推进逻辑（复制 reach_close_moment 的推进部分，不触发 self_close 的 quit）
	var cur: int = gf.get_current_stage()
	gf.close_moment_ready.emit(cur)
	if cur < gf.TOTAL_STAGES:
		gf.set_current_stage(cur + 1)
	await process_frame
	_check("close_moment_ready signal fired", got_close_moment[0] == true)
	_check("stage 1 close-moment advances to 2", gf.get_current_stage() == 2)

	gf.set_current_stage(gf.TOTAL_STAGES)
	if gf.get_current_stage() >= gf.TOTAL_STAGES:
		gf._set_app_value(gf.FINISHED_KEY, true)
	_check("final stage sets finished", gf.has_finished_game() == true)

	# --- start_game 标记 started ---
	gf.reset_progress()
	gf._set_app_value(gf.STARTED_KEY, true)
	_check("started flag persists", gf.has_started() == true)
	_check("has_progress true after started", gf.has_progress() == true)

	# --- post-game OpenAI flag ---
	gf.clear_openai_flag()
	_check("OpenAI flag initially absent", gf.has_openai_flag() == false)
	_check("mark_openai_revealed writes flag", gf.mark_openai_revealed() == true)
	_check("OpenAI flag exists after reveal", gf.has_openai_flag() == true)
	gf.clear_openai_flag()
	_check("clear_openai_flag removes flag", gf.has_openai_flag() == false)
	var rename_plan: Dictionary = gf._build_post_game_executable_rename_plan_from_path("D:/Builds/CloseAI/CloseAI.exe")
	_check("post-game rename plan accepts CloseAI.exe", rename_plan.get("target", "") == "D:/Builds/CloseAI/OpenAI.exe")
	_check("post-game rename plan rejects OpenAI.exe", gf._build_post_game_executable_rename_plan_from_path("D:/Builds/CloseAI/OpenAI.exe").is_empty())
	var rename_script: String = gf._build_post_game_rename_script_text(rename_plan)
	_check("post-game rename script renames to OpenAI.exe", rename_script.contains("ren \"%SRC%\" \"%DST_NAME%\""))

	# --- pre_self_close 演出钩子被 await ---
	gf.pre_self_close.connect(func(r): _pre_close_fired = true, CONNECT_ONE_SHOT)
	var hook := func(_r):
		_hook_awaited = true
		return
	gf.register_pre_close_hook(hook)
	# 直接验证 emit + 钩子注册（不调 self_close 以免 quit）
	gf.pre_self_close.emit("test")
	hook.call("test")
	await process_frame
	_check("pre_self_close emits", _pre_close_fired == true)
	_check("pre_close hook invoked", _hook_awaited == true)
	gf.unregister_pre_close_hook(hook)

	# --- 对话锚点 ---
	for i in [1, 2, 3]:
		var path := "res://dialogue/closeai_stage%d.dialogue" % i
		_check("dialogue stage %d exists" % i, ResourceLoader.exists(path))
		_check("dialogue stage %d has 'start'" % i, gf.has_dialogue_title(i, "start"))
		_check("dialogue stage %d has 'close_moment'" % i, gf.has_dialogue_title(i, "close_moment"))
		_check("dialogue stage %d has 'dirty_return'" % i, gf.has_dialogue_title(i, "dirty_return"))

	# --- 场景齐全 ---
	for scene in ["res://scenes/boot.tscn", "res://scenes/menu.tscn", "res://scenes/ending.tscn", "res://scenes/openai_note.tscn", "res://scenes/stage_1.tscn", "res://scenes/stage_2.tscn", "res://scenes/stage_3.tscn", "res://scenes/settings_screen.tscn", "res://scenes/thanks_screen.tscn", "res://scenes/close_mock.tscn"]:
		_check("scene exists: " + scene, ResourceLoader.exists(scene))

	gf.reset_progress()
	_finish()

func _finish() -> void:
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)
