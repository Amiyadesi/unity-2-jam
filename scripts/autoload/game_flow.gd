extends Node
## ════════════════════════════════════════════════════════════════
##  GameFlow — CloseAI 全局流程编排器（AutoLoad: "GameFlow"）
## ════════════════════════════════════════════════════════════════
##
## 核心理念（反转版）：玩家永远无法自己关闭窗口。
## ────────────────────────────────────────────────
##  只有"游戏自己"会在剧情节点关闭（self_close）。
##  玩家任何关闭尝试都会被拦截并嘲讽：
##    · 普通点 × / 任务栏关闭 → 弹出嘲讽，几秒后自动消失，每次更狠
##    · 真正强杀（任务管理器）→ 进程被杀，但下次启动检测到"脏关闭"，
##      回来后被狠狠嘲讽 + 戳穿"没用的，你逃不掉，只能照我的流程来"
##  目的：让玩家明白，离开的唯一方式就是顺着游戏走下去。
##
##  唯一真正的退出入口 = self_close()：由"开始游戏"和各关"关闭时刻"调用。
##  关闭前会 emit pre_self_close 并 await 已注册的演出钩子（留给设计接演出）。
##
## 进度（持久化到 AppStateModule）：
##  closeai_started  —— 是否已经历过"开始时的第一次自我关闭"
##  closeai_stage    —— 当前关卡编号
##  closeai_finished —— 是否已通关（看完结局）

# ──────────────────────────────────────────────
# 信号
# ──────────────────────────────────────────────

## 即将自我关闭：演出钩子可连接此信号或用 register_pre_close_hook 注册 await
signal pre_self_close(reason: String)
## 玩家尝试关闭窗口被拦截（attempt_index 从 1 起，越大越多次）
signal close_attempt_mocked(attempt_index: int, is_post_kill: bool)
## 进入"关闭时刻"：游戏允许（并提示）自我关闭推进剧情
signal close_moment_ready(stage_index: int)

# ──────────────────────────────────────────────
# 常量
# ──────────────────────────────────────────────

const TOTAL_STAGES := 3

const STARTED_KEY := "closeai_started"
const STAGE_KEY := "closeai_stage"
const FINISHED_KEY := "closeai_finished"

const NORMAL_GAME_TITLE := "Close AI"
const POST_GAME_TITLE := "Open AI"
const POST_GAME_FLAG_PATH := "user://saves/openai.flag"
const POST_GAME_RENAME_SCRIPT_PATH := "user://saves/openai_rename.cmd"
const STAGE_RELAUNCH_SCRIPT_PATH := "user://saves/relaunch_closeai.cmd"
const STAGE_RELAUNCH_DELAY_SECONDS := 2
const WINDOWS_EXECUTABLE_EXTENSION := ".exe"

const SCENE_MENU := "res://scenes/menu.tscn"
const SCENE_ENDING := "res://scenes/ending.tscn"
const SCENE_OPENAI_NOTE := "res://scenes/openai_note.tscn"
const STAGE_SCENE_PATTERN := "res://scenes/stage_%d.tscn"
const DIALOGUE_PATTERN := "res://dialogue/closeai_stage%d.dialogue"

## 嘲讽 overlay 场景（常驻顶层，监听 close_attempt_mocked）
const CLOSE_MOCK_SCENE := "res://scenes/close_mock.tscn"

# ──────────────────────────────────────────────
# 运行时状态
# ──────────────────────────────────────────────

## 进入本次会话时读到的"上次是脏关闭/强杀"标记（启动锁存，只读）
var entered_with_unclean_exit: bool = false
## 本次会话玩家尝试关闭窗口的次数（用于嘲讽升级）
var close_attempt_count: int = 0
## 是否正在执行真正的自我关闭（避免重入）
var _self_closing: bool = false
## 已注册的关闭前演出钩子（Callable，返回值可为协程；逐个 await）
var _pre_close_hooks: Array[Callable] = []
## 当前唯一的全局对话气泡；新对白会顶替旧对白，避免最终战气泡重叠。
var _active_dialogue_balloon: Node = null
## 当前对话令牌；旧协程看到令牌变化后会结束等待。
var _active_dialogue_serial: int = 0

# ──────────────────────────────────────────────
# 生命周期
# ──────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if has_openai_flag():
		get_tree().set_auto_accept_quit(true)
		apply_openai_identity()
		return
	apply_closeai_identity()
	# 接管窗口关闭：玩家永远关不掉，只有 self_close 能退
	get_tree().set_auto_accept_quit(false)
	entered_with_unclean_exit = _read_unclean_exit()
	_spawn_close_mock_overlay.call_deferred()


## 实例化常驻嘲讽 overlay（headless 下跳过，避免无渲染环境的多余开销）
func _spawn_close_mock_overlay() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not ResourceLoader.exists(CLOSE_MOCK_SCENE):
		return
	var packed: PackedScene = load(CLOSE_MOCK_SCENE)
	if packed == null:
		return
	var overlay := packed.instantiate()
	get_tree().root.add_child.call_deferred(overlay)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_player_close_attempt()


# ──────────────────────────────────────────────
# 玩家关闭尝试 —— 永远拦截 + 嘲讽
# ──────────────────────────────────────────────

func _on_player_close_attempt() -> void:
	if has_openai_flag():
		get_tree().quit()
		return
	# 正在执行游戏自己的关闭：放行（理论上此时窗口已在关，不会触发）
	if _self_closing:
		return
	close_attempt_count += 1
	# is_post_kill：本次会话由上次强杀恢复，且这是回来后的首次关闭尝试时语气最狠
	var is_post_kill := entered_with_unclean_exit
	close_attempt_mocked.emit(close_attempt_count, is_post_kill)
	# 关键：不退出。窗口"弹回来"，由嘲讽 overlay 接管表现。


# ──────────────────────────────────────────────
# 自我关闭 —— 唯一真正的退出
# ──────────────────────────────────────────────

## 游戏自己关闭。reason 供演出钩子区分场合（"start" / "stage_close_moment" / "ending"）。
## 关闭前 emit pre_self_close 并 await 所有已注册演出钩子（设计在此接入演出）。
func self_close(reason: String = "") -> void:
	if _self_closing:
		return
	_self_closing = true
	pre_self_close.emit(reason)
	# 依次执行演出钩子。await 对非协程返回值是同步直通，对协程则等待其结束。
	for hook in _pre_close_hooks:
		if hook.is_valid():
			await hook.call(reason)
	# 干净退出：先让存档系统记录 clean_exit，再兜底退出，避免存档失败卡住剧情外壳。
	_schedule_stage_relaunch(reason)
	var save_system := _save_system()
	if save_system != null and save_system.has_method("quit_cleanly"):
		save_system.quit_cleanly()
	else:
		get_tree().quit()
	if get_tree() != null:
		get_tree().quit()


## 注册一个关闭前演出钩子。Callable 形如 func(reason: String) -> void（可为协程）。
## 返回一个用于注销的 Callable 句柄。
func register_pre_close_hook(hook: Callable) -> void:
	if not _pre_close_hooks.has(hook):
		_pre_close_hooks.append(hook)

func unregister_pre_close_hook(hook: Callable) -> void:
	_pre_close_hooks.erase(hook)


# ──────────────────────────────────────────────
# 开始游戏 —— 首次会触发一次"自我关闭"
# ──────────────────────────────────────────────

## 从菜单点"开始"调用：标记已开始，然后游戏自我关闭一次（reason="start"）。
## 演出由 pre_self_close 钩子接入；关闭后玩家再次打开将进入第 1 关。
func start_game() -> void:
	_set_app_value(STARTED_KEY, true)
	set_current_stage(1)
	self_close("start")


## 是否已经历过开场的第一次自我关闭
func has_started() -> bool:
	return bool(_get_app_value(STARTED_KEY, false))


# ──────────────────────────────────────────────
# 关闭时刻 —— 关卡高潮，游戏自我关闭推进剧情
# ──────────────────────────────────────────────

## 由关卡在高潮调用：推进进度 → 提示 → 自我关闭。
## 玩家下次打开进入推进后的关卡（或结局）。
func reach_close_moment(stage_index: int) -> void:
	close_moment_ready.emit(stage_index)
	if stage_index >= TOTAL_STAGES:
		prepare_openai_shell()
	else:
		set_current_stage(stage_index + 1)
	self_close("stage_close_moment")


# ──────────────────────────────────────────────
# 关卡进度
# ──────────────────────────────────────────────

func get_current_stage() -> int:
	var raw: Variant = _get_app_value(STAGE_KEY, 1)
	return clampi(int(raw), 1, TOTAL_STAGES)

func set_current_stage(stage: int) -> void:
	_set_app_value(STAGE_KEY, clampi(stage, 1, TOTAL_STAGES))

func has_finished_game() -> bool:
	return bool(_get_app_value(FINISHED_KEY, false))

## 通关后的外壳标记：存在则下次启动只显示 OpenAI 纸条。
func has_openai_flag() -> bool:
	return FileAccess.file_exists(POST_GAME_FLAG_PATH)

## 结局结束时写入 post-game flag，进入 OpenAI 外壳状态。
func mark_openai_revealed() -> bool:
	var err := DirAccess.make_dir_recursive_absolute(POST_GAME_FLAG_PATH.get_base_dir())
	if err != OK:
		push_error("GameFlow.mark_openai_revealed: cannot create save dir '%s' (err=%d)" % [POST_GAME_FLAG_PATH.get_base_dir(), err])
		return false
	var file := FileAccess.open(POST_GAME_FLAG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameFlow.mark_openai_revealed: cannot write flag '%s' (err=%d)" % [POST_GAME_FLAG_PATH, FileAccess.get_open_error()])
		return false
	file.store_line("OpenAI")
	file.store_line(Time.get_datetime_string_from_system(true))
	file.close()
	_schedule_post_game_executable_rename()
	return true

## 记录完整通关状态并写入下次启动直达纸条的 OpenAI flag。
func prepare_openai_shell() -> bool:
	_set_app_value(FINISHED_KEY, true)
	return mark_openai_revealed()

## 安排 Windows 导出版在进程退出后把 Close AI.exe 改成 Open AI.exe。
func _schedule_post_game_executable_rename() -> void:
	if not OS.has_feature("windows") or OS.has_feature("editor"):
		return
	var plan := _build_post_game_executable_rename_plan_from_path(OS.get_executable_path())
	if plan.is_empty():
		return
	if not _write_post_game_rename_script(plan):
		return
	var script_path := String(plan.get("script", ""))
	var pid := OS.create_process("cmd.exe", PackedStringArray(["/c", script_path]), false)
	if pid <= 0:
		push_warning("GameFlow: cannot start post-game executable rename script '%s'" % script_path)

## 从可执行路径构造通关后改名计划；只接受 Close AI.exe。
func _build_post_game_executable_rename_plan_from_path(executable_path: String) -> Dictionary:
	if executable_path.is_empty():
		return {}
	var source_name := NORMAL_GAME_TITLE + WINDOWS_EXECUTABLE_EXTENSION
	if executable_path.get_file().to_lower() != source_name.to_lower():
		return {}
	var base_dir := executable_path.get_base_dir()
	if base_dir.is_empty():
		return {}
	var target_name := POST_GAME_TITLE + WINDOWS_EXECUTABLE_EXTENSION
	return {
		"source": executable_path,
		"target": base_dir.path_join(target_name),
		"target_name": target_name,
		"script": ProjectSettings.globalize_path(POST_GAME_RENAME_SCRIPT_PATH),
	}

## 写出通关后改名脚本；脚本会等当前 exe 释放锁后再 rename。
func _write_post_game_rename_script(plan: Dictionary) -> bool:
	var script_path := String(plan.get("script", ""))
	if script_path.is_empty():
		return false
	var err := DirAccess.make_dir_recursive_absolute(script_path.get_base_dir())
	if err != OK:
		push_warning("GameFlow: cannot create rename script dir '%s' (err=%d)" % [script_path.get_base_dir(), err])
		return false
	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		push_warning("GameFlow: cannot write rename script '%s' (err=%d)" % [script_path, FileAccess.get_open_error()])
		return false
	file.store_string(_build_post_game_rename_script_text(plan))
	file.close()
	return true

## 生成 Windows cmd 文本；单独成函数方便 headless 测试。
func _build_post_game_rename_script_text(plan: Dictionary) -> String:
	var lines := PackedStringArray([
		"@echo off",
		"setlocal",
		"set \"SRC=%s\"" % _escape_cmd_value(String(plan.get("source", ""))),
		"set \"DST=%s\"" % _escape_cmd_value(String(plan.get("target", ""))),
		"set \"DST_NAME=%s\"" % _escape_cmd_value(String(plan.get("target_name", ""))),
		"for /L %%i in (1,1,80) do (",
		"  if not exist \"%SRC%\" exit /b 0",
		"  if exist \"%DST%\" del /f /q \"%DST%\" 2>nul",
		"  ren \"%SRC%\" \"%DST_NAME%\" 2>nul",
		"  if not exist \"%SRC%\" if exist \"%DST%\" exit /b 0",
		"  timeout /t 1 /nobreak >nul",
		")",
		"exit /b 0",
	])
	return "\r\n".join(lines) + "\r\n"


## 安排关卡层关闭后延迟重启，让下一层自动拉起；只在 Windows 导出版生效。
func _schedule_stage_relaunch(reason: String) -> void:
	if reason != "stage_close_moment":
		return
	if not OS.has_feature("windows") or OS.has_feature("editor"):
		return
	var executable_path := OS.get_executable_path()
	if executable_path.is_empty():
		return
	var script_path := ProjectSettings.globalize_path(STAGE_RELAUNCH_SCRIPT_PATH)
	if not _write_stage_relaunch_script(script_path, executable_path):
		return
	var pid := OS.create_process("cmd.exe", PackedStringArray(["/c", script_path]), false)
	if pid <= 0:
		push_warning("GameFlow: cannot start stage relaunch script '%s'" % script_path)


## 写出延迟重启脚本。
func _write_stage_relaunch_script(script_path: String, executable_path: String) -> bool:
	if script_path.is_empty() or executable_path.is_empty():
		return false
	var err := DirAccess.make_dir_recursive_absolute(script_path.get_base_dir())
	if err != OK:
		push_warning("GameFlow: cannot create relaunch script dir '%s' (err=%d)" % [script_path.get_base_dir(), err])
		return false
	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		push_warning("GameFlow: cannot write relaunch script '%s' (err=%d)" % [script_path, FileAccess.get_open_error()])
		return false
	file.store_string(_build_stage_relaunch_script_text(executable_path, STAGE_RELAUNCH_DELAY_SECONDS))
	file.close()
	return true


## 生成 Windows 延迟重启 cmd 文本，供导出版和 headless 测试共用。
func _build_stage_relaunch_script_text(executable_path: String, delay_seconds: int) -> String:
	var safe_delay := maxi(delay_seconds, 1)
	var lines := PackedStringArray([
		"@echo off",
		"setlocal",
		"set \"EXE=%s\"" % _escape_cmd_value(executable_path),
		"timeout /t %d /nobreak >nul" % safe_delay,
		"if exist \"%EXE%\" start \"\" \"%EXE%\"",
		"exit /b 0",
	])
	return "\r\n".join(lines) + "\r\n"

## 转义 cmd 环境变量值中会触发变量展开的百分号。
func _escape_cmd_value(value: String) -> String:
	return value.replace("%", "%%").replace("\"", "")

## 测试/重置进度时移除 post-game flag。
func clear_openai_flag() -> void:
	if FileAccess.file_exists(POST_GAME_FLAG_PATH):
		var err := DirAccess.remove_absolute(POST_GAME_FLAG_PATH)
		if err != OK:
			push_error("GameFlow.clear_openai_flag: cannot remove flag '%s' (err=%d)" % [POST_GAME_FLAG_PATH, err])

## 切到 post-game 外壳身份：窗口标题显示 Open AI。
func apply_openai_identity() -> void:
	var win := get_window()
	_set_shell_transparency(true)
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_title(POST_GAME_TITLE)
	if win != null:
		win.mode = Window.MODE_WINDOWED
		win.borderless = true

## 切到正常游戏身份：导出包元数据和游玩窗口都保持 Close AI。
func apply_closeai_identity() -> void:
	_set_shell_transparency(false)
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_title(NORMAL_GAME_TITLE)

## 同步 viewport/window 透明背景，避免 OpenAI 纸条落回黑底。
func _set_shell_transparency(enabled: bool) -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.transparent_bg = enabled
	if DisplayServer.get_name() != "headless":
		var win := get_window()
		if win != null:
			win.transparent_bg = enabled
	var clear_color := Color(0, 0, 0, 0) if enabled else Color(0, 0, 0, 1)
	RenderingServer.set_default_clear_color(clear_color)

## 是否有可继续的进度（已开始过，或已通关）
func has_progress() -> bool:
	return has_started() or get_current_stage() > 1 or has_finished_game()

## 重置全部进度（新游戏）
func reset_progress() -> void:
	clear_openai_flag()
	_set_app_value(STARTED_KEY, false)
	set_current_stage(1)
	_set_app_value(FINISHED_KEY, false)
	var save_system := _save_system()
	if save_system != null and save_system.has_method("new_game"):
		save_system.new_game()
	if save_system != null and save_system.has_method("save_global"):
		save_system.save_global()


# ──────────────────────────────────────────────
# 场景路由
# ──────────────────────────────────────────────

## 再次打开游戏时由 boot 调用：根据进度进入正确场景。
##  post-game flag → OpenAI 纸条；未开始 → 菜单；旧已通关存档 → 迁移到纸条；游玩中 → 当前关卡。
func enter_after_boot() -> void:
	if has_openai_flag():
		goto_openai_note()
	elif has_finished_game():
		prepare_openai_shell()
		goto_openai_note()
	elif not has_started():
		goto_menu()
	else:
		goto_stage(get_current_stage())

## 返回启动后应进入的场景路径，供流程测试和菜单文案判断使用。
func get_scene_path_after_boot() -> String:
	if has_openai_flag():
		return SCENE_OPENAI_NOTE
	if has_finished_game():
		return SCENE_OPENAI_NOTE
	if not has_started():
		return SCENE_MENU
	return STAGE_SCENE_PATTERN % get_current_stage()

func goto_menu() -> void:
	apply_closeai_identity()
	_change_scene(SCENE_MENU)

func goto_stage(stage: int) -> void:
	var s := clampi(stage, 1, TOTAL_STAGES)
	set_current_stage(s)
	apply_closeai_identity()
	_change_scene(STAGE_SCENE_PATTERN % s)

## 兼容旧调用名；终局现在直接迁移到 OpenAI 纸条外壳。
func goto_ending() -> void:
	prepare_openai_shell()
	goto_openai_note()

## 进入通关后的 OpenAI 纸条场景。
func goto_openai_note() -> void:
	apply_openai_identity()
	_change_scene(SCENE_OPENAI_NOTE)

func _change_scene(path: String) -> void:
	var sm := _scene_manager()
	if sm != null and sm.has_method("change_scene_to_file"):
		sm.change_scene_to_file(path)
	else:
		get_tree().change_scene_to_file(path)


# ──────────────────────────────────────────────
# 对话辅助
# ──────────────────────────────────────────────

## 加载并播放某关卡对话；await 直到对话结束。
func play_dialogue(stage: int, title: String = "") -> void:
	var path := DIALOGUE_PATTERN % stage
	if not ResourceLoader.exists(path):
		push_warning("GameFlow.play_dialogue: 对话文件不存在 '%s'" % path)
		return
	var resource: Resource = load(path)
	if resource == null:
		push_warning("GameFlow.play_dialogue: 对话加载失败 '%s'" % path)
		return
	var dm := _dialogue_manager()
	if dm == null:
		push_warning("GameFlow.play_dialogue: DialogueManager 不可用")
		return
	if title != "" and not ("titles" in resource and resource.titles is Dictionary and resource.titles.has(title)):
		push_error("GameFlow.play_dialogue: 标题 '%s' 不存在于 '%s'" % [title, resource.resource_path])
		return
	var balloon := _show_single_dialogue_balloon(dm, resource, title)
	if balloon == null:
		return
	var serial := _active_dialogue_serial
	await _wait_for_dialogue_balloon_end(balloon, dm, resource, serial)
	if serial == _active_dialogue_serial and is_instance_valid(balloon) and is_instance_valid(_active_dialogue_balloon) and _active_dialogue_balloon == balloon:
		_active_dialogue_balloon = null
		_release_dialogue_balloon(balloon, false)

## 本关对话文件是否含某标题锚点
func has_dialogue_title(stage: int, title: String) -> bool:
	var path := DIALOGUE_PATTERN % stage
	if not ResourceLoader.exists(path):
		return false
	var res = load(path)
	if res == null:
		return false
	if "titles" in res and res.titles is Dictionary:
		return res.titles.has(title)
	return false

## 播放一个新的全局对话气泡，并立即顶替仍在场的旧气泡。
func _show_single_dialogue_balloon(dm: Node, resource: Resource, title: String) -> Node:
	_close_active_dialogue_balloon()
	if dm == null or not dm.has_method("show_dialogue_balloon"):
		return null
	var balloon: Node = dm.show_dialogue_balloon(resource, title)
	if balloon == null:
		return null
	_active_dialogue_serial += 1
	_active_dialogue_balloon = balloon
	return balloon

## 结束当前全局气泡；用于新对白抢占旧对白时清场。
func _close_active_dialogue_balloon() -> void:
	if not is_instance_valid(_active_dialogue_balloon):
		_active_dialogue_balloon = null
		return
	var balloon := _active_dialogue_balloon
	_active_dialogue_balloon = null
	_active_dialogue_serial += 1
	_release_dialogue_balloon(balloon, true)

## 等到气泡自己结束，或被更新的对话令牌顶替。
func _wait_for_dialogue_balloon_end(balloon: Variant, dm: Node, resource: Resource, serial: int) -> void:
	var ended := [false]
	var dm_callback := Callable()
	if is_instance_valid(balloon) and balloon.has_signal("dialogue_ended"):
		balloon.dialogue_ended.connect(func() -> void: ended[0] = true, CONNECT_ONE_SHOT)
	elif dm != null and dm.has_signal("dialogue_ended"):
		dm_callback = func(ended_resource: Resource) -> void:
			if ended_resource == resource:
				ended[0] = true
		dm.dialogue_ended.connect(dm_callback)
	while not ended[0] and serial == _active_dialogue_serial and is_instance_valid(balloon) and not balloon.is_queued_for_deletion():
		await get_tree().process_frame
	if dm_callback.is_valid() and dm != null and dm.has_signal("dialogue_ended") and dm.dialogue_ended.is_connected(dm_callback):
		dm.dialogue_ended.disconnect(dm_callback)

## 释放一个气泡节点；force_end 会让本地等待者收到结束信号。
func _release_dialogue_balloon(balloon: Variant, force_end: bool) -> void:
	if not is_instance_valid(balloon):
		return
	if force_end and balloon.has_method("force_end"):
		balloon.force_end()
	if not balloon.is_queued_for_deletion():
		balloon.queue_free()


# ──────────────────────────────────────────────
# 内部：autoload / 存档模块访问
# ──────────────────────────────────────────────

func _save_system() -> Node:
	return get_node_or_null("/root/SaveSystem")

func _scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")

func _dialogue_manager() -> Node:
	return get_node_or_null("/root/DialogueManager")

func _read_unclean_exit() -> bool:
	var save_system := _save_system()
	if save_system == null or not save_system.has_method("get_module"):
		return false
	var stats = save_system.get_module("stats")
	if stats != null and stats.has_method("had_unclean_exit"):
		return bool(stats.had_unclean_exit())
	return false

func _get_app_value(key: String, fallback: Variant) -> Variant:
	var save_system := _save_system()
	if save_system == null or not save_system.has_method("get_module"):
		return fallback
	var app_state = save_system.get_module("app_state")
	if app_state != null and app_state.has_method("get_value"):
		return app_state.get_value(key, fallback)
	return fallback

func _set_app_value(key: String, value: Variant) -> void:
	var save_system := _save_system()
	if save_system == null or not save_system.has_method("get_module"):
		return
	var app_state = save_system.get_module("app_state")
	if app_state != null and app_state.has_method("set_value"):
		app_state.set_value(key, value)
		if save_system.has_method("save_global"):
			save_system.save_global()
