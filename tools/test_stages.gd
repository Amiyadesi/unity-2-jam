extends SceneTree
## test_stages.gd — 验证各关卡场景能实例化并跑过 enter 序列前几帧
## 运行：godot --headless --path . --script res://tools/test_stages.gd

var _failures: int = 0
var _checks: int = 0

const STAGE_SCENES := [
	"res://scenes/stage_1.tscn",
	"res://scenes/stage_2.tscn",
	"res://scenes/stage_3.tscn",
]

## 延迟启动测试，等 autoload 初始化完成。
func _init() -> void:
	call_deferred("_run")

## 记录一条布尔检查结果。
func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  [PASS] " if cond else "  [FAIL] ") + label)
	if not cond:
		_failures += 1

## 跑场景实例化和 authored 关卡结构回归检查。
func _run() -> void:
	print("=== CloseAI stage instantiation test ===")
	await process_frame
	await process_frame
	var gf = root.get_node_or_null("GameFlow")
	if gf != null:
		gf.reset_progress()

	for scene_path in STAGE_SCENES + ["res://scenes/menu.tscn", "res://scenes/ending.tscn", "res://scenes/openai_note.tscn"]:
		var packed = load(scene_path)
		_check("load packed: " + scene_path, packed != null)
		if packed == null:
			continue
		var inst = packed.instantiate()
		_check("instantiate: " + scene_path, inst != null)
		if inst == null:
			continue
		root.add_child(inst)
		# 跑若干帧，让 _ready / _run_enter_sequence / 对话调用执行
		for _i in range(8):
			await process_frame
		_check("alive after frames: " + scene_path, is_instance_valid(inst))
		if STAGE_SCENES.has(scene_path):
			_check_authored_stage_ui(inst, scene_path)
			_check_authored_energy_hud(inst, scene_path)
		if scene_path == "res://scenes/stage_1.tscn":
			_check_stage_1_interact_nodes(inst)
			_check_stage_1_tutorial_nodes(inst)
		# 关掉可能弹出的对话气泡 + 移除场景
		inst.queue_free()
		await process_frame
		await process_frame

	if gf != null:
		gf.reset_progress()
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)


## 确认关卡共享 UI 都来自 authored 场景节点，关闭按钮使用 ShaderButton 模板。
func _check_authored_stage_ui(inst: Node, scene_path: String) -> void:
	var pause_screen := inst.get_node_or_null("PauseLayer/PauseScreen")
	var close_layer := inst.get_node_or_null("CloseMomentLayer")
	var close_button := inst.get_node_or_null("CloseMomentLayer/CloseButton")
	_check("authored PauseLayer/PauseScreen: " + scene_path, pause_screen != null)
	_check("authored CloseMomentLayer: " + scene_path, close_layer != null)
	_check("authored CloseMomentLayer/CloseButton: " + scene_path, close_button != null)
	_check("CloseButton is ShaderButton: " + scene_path, close_button != null and close_button.has_method("set_bbtext"))


## 确认战斗关卡 authored 能量 HUD，第 1 关教学不显示战斗 HUD。
func _check_authored_energy_hud(inst: Node, scene_path: String) -> void:
	var energy_hud := inst.get_node_or_null("EnergyHud")
	if scene_path == "res://scenes/stage_1.tscn":
		_check("stage_1 has no combat EnergyHud", energy_hud == null)
		return
	_check("combat stage authored EnergyHud: " + scene_path, energy_hud != null)
	_check("EnergyHud has player_path: " + scene_path, energy_hud != null and "player_path" in energy_hud and str(energy_hud.player_path) != "")


## 确认第 1 关教学脚本使用的互动节点已 authored 到场景里。
func _check_stage_1_interact_nodes(inst: Node) -> void:
	var expected := ["InteractNode1", "InteractNode2", "InteractNode3"]
	for node_name in expected:
		var interact_node := inst.get_node_or_null(node_name)
		_check("stage_1 authored " + node_name, interact_node != null)
		_check("stage_1 " + node_name + " supports set_enabled", interact_node != null and interact_node.has_method("set_enabled"))
		_check("stage_1 " + node_name + " authored Lit", interact_node != null and interact_node.get_node_or_null("Lit") is CanvasItem)
		_check("stage_1 " + node_name + " authored Prompt", interact_node != null and interact_node.get_node_or_null("Prompt") is CanvasItem)
	_check("stage_1 removed old Switch1", inst.get_node_or_null("Switch1") == null)


## 确认第 1 关跳跃/掉坑判定已由 authored 节点承载。
func _check_stage_1_tutorial_nodes(inst: Node) -> void:
	var respawn := inst.get_node_or_null("TutorialMarkers/RespawnPoint")
	var gap_clear := inst.get_node_or_null("GapClearArea")
	var pit_recover := inst.get_node_or_null("PitRecoverArea")
	_check("stage_1 authored RespawnPoint", respawn is Marker2D)
	_check("stage_1 authored GapClearArea", gap_clear is Area2D)
	_check("stage_1 authored GapClearArea shape", gap_clear != null and gap_clear.get_node_or_null("CollisionShape2D") is CollisionShape2D)
	_check("stage_1 authored PitRecoverArea", pit_recover is Area2D)
	_check("stage_1 authored PitRecoverArea shape", pit_recover != null and pit_recover.get_node_or_null("CollisionShape2D") is CollisionShape2D)
