extends GlassModal
## settings_screen.gd — 设置模态（金棕玻璃风）
##
## 三个音量滑条（主/音乐/音效）+ 全屏开关，走 SettingsModule 落盘。
## 面板内提供"感谢"入口（菜单态显示，游戏内隐藏）与"返回"。
## 视觉由场景模板提供（玻璃模糊 + 扫描线/缺陷边框 VFX + 金棕描边）。

signal thanks_requested()

## 菜单态显示感谢入口；游戏内（暂停里打开）隐藏
@export var show_thanks: bool = true

@onready var _master_slider: HSlider = $Panel/Margin/VBox/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $Panel/Margin/VBox/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $Panel/Margin/VBox/SfxRow/SfxSlider
@onready var _master_value: Label = $Panel/Margin/VBox/MasterRow/MasterValue
@onready var _music_value: Label = $Panel/Margin/VBox/MusicRow/MusicValue
@onready var _sfx_value: Label = $Panel/Margin/VBox/SfxRow/SfxValue
@onready var _fullscreen_check: CheckButton = $Panel/Margin/VBox/DisplayRow/FullscreenCheck
@onready var _return_button: Button = $Panel/Margin/VBox/ButtonRow/ReturnButton
@onready var _thanks_button: Button = $Panel/Margin/VBox/ButtonRow/ThanksButton

var _suppress: bool = false


func _ready() -> void:
	super._ready()
	_master_slider.value_changed.connect(_on_master)
	_music_slider.value_changed.connect(_on_music)
	_sfx_slider.value_changed.connect(_on_sfx)
	_fullscreen_check.toggled.connect(_on_fullscreen)
	_return_button.pressed.connect(func(): close_modal())
	_thanks_button.pressed.connect(func(): thanks_requested.emit())


func set_show_thanks(value: bool) -> void:
	show_thanks = value
	if _thanks_button != null:
		_thanks_button.visible = value


func _on_before_open() -> void:
	_thanks_button.visible = show_thanks
	_refresh_from_settings()


func _refresh_from_settings() -> void:
	var s := _settings()
	if s == null:
		return
	_suppress = true
	_master_slider.value = float(s.get_value("master_volume", 0.8))
	_music_slider.value = float(s.get_value("music_volume", 0.8))
	_sfx_slider.value = float(s.get_value("sfx_volume", 0.8))
	_fullscreen_check.button_pressed = str(s.get_value("display_mode", "fullscreen")) == "fullscreen"
	_suppress = false
	_update_labels()


func _update_labels() -> void:
	_master_value.text = "%d%%" % roundi(_master_slider.value * 100.0)
	_music_value.text = "%d%%" % roundi(_music_slider.value * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx_slider.value * 100.0)


func _on_master(v: float) -> void: _apply("master_volume", v)
func _on_music(v: float) -> void: _apply("music_volume", v)
func _on_sfx(v: float) -> void: _apply("sfx_volume", v)

func _apply(key: String, value: Variant) -> void:
	_update_labels()
	if _suppress:
		return
	var s := _settings()
	if s != null:
		s.set_value(key, value)

func _on_fullscreen(pressed: bool) -> void:
	if _suppress:
		return
	var s := _settings()
	if s != null:
		s.set_value("display_mode", "fullscreen" if pressed else "windowed")


func _settings() -> Object:
	var ss := get_node_or_null("/root/SaveSystem")
	if ss != null and ss.has_method("get_module"):
		return ss.get_module("settings")
	return null
