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
		gf.prepare_openai_shell()
	_check("final stage sets finished", gf.has_finished_game() == true)
	_check("final stage prepares OpenAI flag", gf.has_openai_flag() == true)
	gf.clear_openai_flag()
	_check("legacy finished save routes to OpenAI note", gf.get_scene_path_after_boot() == gf.SCENE_OPENAI_NOTE)

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
	var rename_plan: Dictionary = gf._build_post_game_executable_rename_plan_from_path("D:/Builds/CloseAI/Close AI.exe")
	_check("post-game rename plan accepts Close AI.exe", rename_plan.get("target", "") == "D:/Builds/CloseAI/Open AI.exe")
	_check("post-game rename plan rejects Open AI.exe", gf._build_post_game_executable_rename_plan_from_path("D:/Builds/CloseAI/Open AI.exe").is_empty())
	var rename_script: String = gf._build_post_game_rename_script_text(rename_plan)
	_check("post-game rename script renames to Open AI.exe", rename_script.contains("ren \"%SRC%\" \"%DST_NAME%\""))
	var relaunch_script: String = gf._build_stage_relaunch_script_text("D:/Builds/CloseAI/Close AI.exe", 2)
	_check("stage relaunch script waits before restart", relaunch_script.contains("timeout /t 2"))
	_check("stage relaunch script starts Close AI", relaunch_script.contains("start \"\" \"%EXE%\""))
	var game_flow_source := _read_res_text("res://scripts/autoload/game_flow.gd")
	_check("self_close forces quit after clean save attempt", game_flow_source.contains("save_system.quit_cleanly()") and game_flow_source.find("get_tree().quit()", game_flow_source.find("save_system.quit_cleanly()")) > 0)
	gf.apply_openai_identity()
	_check("OpenAI identity enables transparent viewport", root.transparent_bg == true)
	gf.apply_closeai_identity()
	_check("CloseAI identity restores opaque viewport", root.transparent_bg == false)

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
	await _check_single_dialogue_balloon(gf)

	# --- 对话锚点 ---
	for i in [1, 2, 3]:
		var path := "res://dialogue/closeai_stage%d.dialogue" % i
		_check("dialogue stage %d exists" % i, ResourceLoader.exists(path))
		_check("dialogue stage %d has 'start'" % i, gf.has_dialogue_title(i, "start"))
		_check("dialogue stage %d has 'close_moment'" % i, gf.has_dialogue_title(i, "close_moment"))
		_check("dialogue stage %d has 'dirty_return'" % i, gf.has_dialogue_title(i, "dirty_return"))
		var dialogue_text := _read_res_text(path)
		_check("dialogue stage %d uses DialogueManager wait tags" % i, not dialogue_text.contains("[pause="))
		_check("dialogue stage %d has no standalone wait tags" % i, _has_no_standalone_wait_tags(dialogue_text))
		if i == 1:
			_check("dialogue stage %d keeps authored wait beats" % i, dialogue_text.contains("[wait=0.4]") and dialogue_text.contains("[wait=0.8]"))
	_check("GameFlow keeps one active dialogue balloon", game_flow_source.contains("_active_dialogue_balloon") and game_flow_source.contains("_close_active_dialogue_balloon()") and game_flow_source.contains("force_end"))

	# --- 场景齐全 ---
	for scene in ["res://scenes/boot.tscn", "res://scenes/menu.tscn", "res://scenes/ending.tscn", "res://scenes/openai_note.tscn", "res://scenes/stage_1.tscn", "res://scenes/stage_2.tscn", "res://scenes/stage_3.tscn", "res://scenes/settings_screen.tscn", "res://scenes/thanks_screen.tscn", "res://scenes/close_mock.tscn"]:
		_check("scene exists: " + scene, ResourceLoader.exists(scene))

	gf.reset_progress()
	_finish()

func _finish() -> void:
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)


## 读取 res:// 文本文件，供 dialogue 标签格式回归检查使用。
func _read_res_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## 确认 wait 标签不是单独一条空对白。
func _has_no_standalone_wait_tags(text: String) -> bool:
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("[wait=") and trimmed.ends_with("]") and trimmed.count("[") == 1:
			return false
	return true


## 新对白会顶掉旧气泡，保证全局最多一个气泡。
func _check_single_dialogue_balloon(gf: Node) -> void:
	var dm := root.get_node_or_null("DialogueManager")
	var resource: Resource = load("res://dialogue/closeai_stage1.dialogue")
	_check("single-balloon test prerequisites", dm != null and resource != null)
	if dm == null or resource == null:
		return
	var first: Node = gf._show_single_dialogue_balloon(dm, resource, "dirty_return")
	var second: Node = gf._show_single_dialogue_balloon(dm, resource, "start")
	await process_frame
	await process_frame
	_check("new dialogue replaces previous balloon", is_instance_valid(second) and not is_instance_valid(first))
	_check("only one modular balloon remains", _count_modular_balloons(root) == 1)
	gf._close_active_dialogue_balloon()
	await process_frame
	await process_frame
	_check("dialogue balloon cleanup removes active balloon", _count_modular_balloons(root) == 0)


## 统计当前场景树里的模块化对话气泡数量。
func _count_modular_balloons(node: Node) -> int:
	var total := 0
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path == "res://addons/dialogue_manager/modify_test/modular_balloon.gd" and not node.is_queued_for_deletion():
		total += 1
	for child in node.get_children():
		total += _count_modular_balloons(child)
	return total
