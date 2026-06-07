extends SceneTree
## test_audio.gd — 验证 SoundManager 使用独立音频 bus。
## 运行：godot --headless --path . --script res://tools/test_audio.gd

var _failures: int = 0
var _checks: int = 0


## 延迟启动，等 autoload 和默认 bus layout 完成初始化。
func _init() -> void:
	call_deferred("_run")


## 记录一条音频配置检查。
func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  [PASS] " if cond else "  [FAIL] ") + label)
	if not cond:
		_failures += 1


## 确认默认 bus layout 和 SoundManager 池子绑定一致。
func _run() -> void:
	print("=== CloseAI audio bus test ===")
	await process_frame
	await process_frame

	for bus_name in ["Music", "Sounds", "UI", "Ambient"]:
		_check("bus exists: " + bus_name, AudioServer.get_bus_index(bus_name) >= 0)

	var sound_manager := root.get_node_or_null("SoundManager")
	_check("SoundManager autoload exists", sound_manager != null)
	if sound_manager != null:
		_check("music uses Music bus", sound_manager.music.bus == "Music")
		_check("sounds use Sounds bus", sound_manager.sound_effects.bus == "Sounds")
		_check("ui uses UI bus", sound_manager.ui_sound_effects.bus == "UI")
		_check("ambient uses Ambient bus", sound_manager.ambient_sounds.bus == "Ambient")
		_check("music not shared with sounds", sound_manager.music.bus != sound_manager.sound_effects.bus)
		_check("music not shared with ui", sound_manager.music.bus != sound_manager.ui_sound_effects.bus)

	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)
