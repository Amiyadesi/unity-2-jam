extends GlassModal
## pause_screen.gd — 游戏内暂停（金棕玻璃风）
##
## ESC 切换 get_tree().paused。只有 继续 / 设置 两个按钮（玩家退不了游戏，
## 主题上也不该提供"返回菜单"这种逃离方式）。
## 设置从暂停里打开时隐藏"感谢"入口（in-game 规则）。
## process_mode=ALWAYS（GlassModal 已设），暂停时仍能响应输入与动画。

@onready var _continue_button: Button = $Panel/Margin/VBox/ButtonRow/ContinueButton
@onready var _settings_button: Button = $Panel/Margin/VBox/ButtonRow/SettingsButton
@onready var _settings_screen = $SettingsScreen


func _ready() -> void:
	super._ready()
	_continue_button.pressed.connect(_resume)
	_settings_button.pressed.connect(_open_settings)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	# 设置开着时，ESC 先关设置
	if _settings_screen.is_open():
		_settings_screen.close_modal()
		return
	if is_open():
		_resume()
	else:
		_pause()


func _pause() -> void:
	get_tree().paused = true
	open_modal()


func _resume() -> void:
	get_tree().paused = false
	close_modal()


func _open_settings() -> void:
	# 游戏内设置隐藏"感谢"
	if _settings_screen.has_method("set_show_thanks"):
		_settings_screen.set_show_thanks(false)
	_settings_screen.open_modal()
