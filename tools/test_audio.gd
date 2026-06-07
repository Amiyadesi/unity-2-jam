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

	_check_music_import_loops()
	await _check_dialogue_typing_sound_authored()

	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)


## 确认三首 BGM 的 import 资源开启 loop，不靠脚本重播。
func _check_music_import_loops() -> void:
	for path in [
		"res://assets/third_party/peritune/The_City_Breathes_Your_Name.mp3.import",
		"res://assets/third_party/peritune/Ancient_Gust_Retro_6.mp3.import",
		"res://assets/third_party/peritune/Ancient_Gust_Retro_9.mp3.import",
	]:
		var text := _read_text(path)
		_check("music import exists: " + path, not text.is_empty())
		_check("music import loops: " + path, text.contains("loop=true"))


## 确认对话打字音使用气泡场景里的 authored TalkSound 节点。
func _check_dialogue_typing_sound_authored() -> void:
	var packed = load("res://addons/dialogue_manager/modify_test/modular_balloon.tscn")
	_check("modular balloon loads", packed != null)
	if packed == null:
		return
	var balloon = packed.instantiate()
	_check("modular balloon instantiates", balloon != null)
	if balloon == null:
		return
	root.add_child(balloon)
	await process_frame
	var talk_sound := balloon.get_node_or_null("%TalkSound") as AudioStreamPlayer
	_check("dialogue authored TalkSound", talk_sound != null)
	_check("dialogue TalkSound has stream", talk_sound != null and talk_sound.stream != null)
	_check("dialogue TalkSound uses UI bus", talk_sound != null and talk_sound.bus == "UI")
	var module: Node = balloon.get_node_or_null("TypingSoundModule")
	_check("typing module receives authored player", module != null and "audio_player" in module and module.audio_player == talk_sound)
	balloon.queue_free()
	var source := _read_text("res://addons/dialogue_manager/modify_test/modules/typing_sound_module.gd")
	_check("typing module does not create AudioStreamPlayer at runtime", not source.contains("AudioStreamPlayer.new()"))


## 读取文本资源，失败时返回空串供断言报错。
func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
