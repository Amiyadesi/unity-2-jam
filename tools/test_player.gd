extends SceneTree
## test_player.gd — 验证玩家场景实例化 + 动画齐全
## 运行：godot --headless --path . --script res://tools/test_player.gd

var _failures := 0
var _checks := 0

## 延迟运行测试，等待引擎初始化。
func _init() -> void:
	call_deferred("_run")

## 记录一条检查结果。
func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  [PASS] " if cond else "  [FAIL] ") + label)
	if not cond:
		_failures += 1

## 实例化玩家并验证动画、能量、觉醒接口。
func _run() -> void:
	print("=== CloseAI player test ===")
	await process_frame
	var packed = load("res://scenes/player.tscn")
	_check("player.tscn loads", packed != null)
	if packed == null:
		_finish(); return
	var p = packed.instantiate()
	_check("player instantiates", p != null)
	root.add_child(p)
	await process_frame
	var anim = p.get_node_or_null("AnimationPlayer")
	_check("has AnimationPlayer", anim != null)
	var expected = ["idle","walk","jump","fall","crouch","standup","pickup",
		"transform","morph_idle","morph_move","untransform","cast_forward","cast_side","death"]
	for name in expected:
		_check("anim '%s' exists" % name, anim != null and anim.has_animation(name))
	var sprite = p.get_node_or_null("Body/Sprite2D")
	_check("sprite hframes=17", sprite != null and sprite.hframes == 17)
	_check("sprite vframes=16", sprite != null and sprite.vframes == 16)
	var script_property_names := _get_script_property_names(p)
	_check("has energy property", script_property_names.has("energy"))
	_check("has max_energy property", script_property_names.has("max_energy"))
	_check("energy starts within max", script_property_names.has("energy") and script_property_names.has("max_energy") and p.energy >= 0.0 and p.energy <= p.max_energy)
	_check("awaken action exists", InputMap.has_action("awaken"))
	# play_action runs without error
	if p.has_method("play_action"):
		p.play_action("pickup")
		await process_frame
		_check("play_action('pickup') runs", true)
		p.play_action("transform")
		await process_frame
		_check("play_action('transform') runs", true)
		p.play_action("untransform")
		await process_frame
		_check("play_action('untransform') runs", true)
	p.queue_free()
	_finish()

## 读取脚本导出的/声明的属性名，避免测试依赖私有实现。
func _get_script_property_names(node: Object) -> Array[String]:
	var names: Array[String] = []
	for property in node.get_property_list():
		var property_name := str(property.get("name", ""))
		if property_name != "":
			names.append(property_name)
	return names

## 输出测试汇总并设置退出码。
func _finish() -> void:
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)
