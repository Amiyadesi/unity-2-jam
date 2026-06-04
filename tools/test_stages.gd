extends SceneTree
## test_stages.gd — 验证各关卡场景能实例化并跑过 enter 序列前几帧
## 运行：godot --headless --path . --script res://tools/test_stages.gd

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
	print("=== CloseAI stage instantiation test ===")
	await process_frame
	await process_frame
	var gf = root.get_node_or_null("GameFlow")
	if gf != null:
		gf.reset_progress()

	for scene_path in ["res://scenes/stage_1.tscn", "res://scenes/stage_2.tscn", "res://scenes/stage_3.tscn", "res://scenes/menu.tscn", "res://scenes/ending.tscn"]:
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
		# 关掉可能弹出的对话气泡 + 移除场景
		var dm = root.get_node_or_null("DialogueManager")
		inst.queue_free()
		await process_frame
		await process_frame

	if gf != null:
		gf.reset_progress()
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)
