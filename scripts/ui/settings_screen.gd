extends ModalScreen
## settings_screen.gd — 设置模态
##
## 三个音量滑条（主/音乐/音效）+ 显示模式切换（全屏/窗口），全部走 SettingsModule 落盘。
## 面板内提供"感谢"入口（emit thanks_requested）与"返回"。
##
## 所有改动即时 apply（SettingsModule.set_value 内部 apply + 防抖落盘）。

signal thanks_requested()

@onready var _master_slider: HSlider = $Panel/Margin/VBox/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $Panel/Margin/VBox/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $Panel/Margin/VBox/SfxRow/SfxSlider
@onready var _master_value: Label = $Panel/Margin/VBox/MasterRow/MasterValue
@onready var _music_value: Label = $Panel/Margin/VBox/MusicRow/MusicValue
@onready var _sfx_value: Label = $Panel/Margin/VBox/SfxRow/SfxValue
@onready var _fullscreen_check: CheckButton = $Panel/Margin/VBox/DisplayRow/FullscreenCheck
@onready var _return_button: Button = $Panel/Margin/VBox/ButtonRow/ReturnButton
@onready var _thanks_button: Button = $Panel/Margin/VBox/ButtonRow/ThanksButton

var _suppress_signals: bool = false


func _ready() -> void:
	super._ready()
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_return_button.pressed.connect(func(): close_modal())
	_thanks_button.pressed.connect(func(): thanks_requested.emit())


## 打开前从存档同步当前设置
func _on_before_open() -> void:
	_refresh_from_settings()


func _refresh_from_settings() -> void:
	var s := _settings()
	if s == null:
		return
	_suppress_signals = true
	_master_slider.value = float(s.get_value("master_volume", 0.8))
	_music_slider.value = float(s.get_value("music_volume", 0.8))
	_sfx_slider.value = float(s.get_value("sfx_volume", 0.8))
	_fullscreen_check.button_pressed = str(s.get_value("display_mode", "fullscreen")) == "fullscreen"
	_suppress_signals = false
	_update_value_labels()


func _update_value_labels() -> void:
	_master_value.text = "%d%%" % roundi(_master_slider.value * 100.0)
	_music_value.text = "%d%%" % roundi(_music_slider.value * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx_slider.value * 100.0)


# ──────────────────────────────────────────────
# 回调 —— 即时写入 SettingsModule
# ──────────────────────────────────────────────

func _on_master_changed(v: float) -> void:
	_apply_setting("master_volume", v)

func _on_music_changed(v: float) -> void:
	_apply_setting("music_volume", v)

func _on_sfx_changed(v: float) -> void:
	_apply_setting("sfx_volume", v)

func _apply_setting(key: String, value: Variant) -> void:
	_update_value_labels()
	if _suppress_signals:
		return
	var s := _settings()
	if s != null:
		s.set_value(key, value)

func _on_fullscreen_toggled(pressed: bool) -> void:
	if _suppress_signals:
		return
	var s := _settings()
	if s != null:
		s.set_value("display_mode", "fullscreen" if pressed else "windowed")


## 通过 SaveSystem 取已注册的 settings 模块（运行时单例）
func _settings() -> Object:
	var ss := get_node_or_null("/root/SaveSystem")
	if ss != null and ss.has_method("get_module"):
		return ss.get_module("settings")
	return null
