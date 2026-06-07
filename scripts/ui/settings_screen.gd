extends GlassModal
## settings_screen.gd — 设置模态（金棕玻璃风）
##
## 音频滑条（Master/Music/Sounds/UI/Ambient）+ 核心键位重映射，走 SettingsModule/KeybindingModule 落盘。
## 面板内提供"感谢"入口（菜单态显示，游戏内隐藏）与"返回"。
## 视觉由场景模板提供（玻璃模糊 + 扫描线/缺陷边框 VFX + 金棕描边）。

signal thanks_requested()

## 菜单态显示感谢入口；游戏内（暂停里打开）隐藏
@export var show_thanks: bool = true

@onready var _master_slider: HSlider = $Panel/Margin/VBox/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $Panel/Margin/VBox/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $Panel/Margin/VBox/SfxRow/SfxSlider
@onready var _ui_slider: HSlider = $Panel/Margin/VBox/UiRow/UiSlider
@onready var _ambient_slider: HSlider = $Panel/Margin/VBox/AmbientRow/AmbientSlider
@onready var _master_value: Label = $Panel/Margin/VBox/MasterRow/MasterValue
@onready var _music_value: Label = $Panel/Margin/VBox/MusicRow/MusicValue
@onready var _sfx_value: Label = $Panel/Margin/VBox/SfxRow/SfxValue
@onready var _ui_value: Label = $Panel/Margin/VBox/UiRow/UiValue
@onready var _ambient_value: Label = $Panel/Margin/VBox/AmbientRow/AmbientValue
@onready var _keybinding_ui: KeybindingUI = $Panel/Margin/VBox/KeybindPanel/KeybindingUI
@onready var _return_button: Button = $Panel/Margin/VBox/ButtonRow/ReturnButton
@onready var _thanks_button: Button = $Panel/Margin/VBox/ButtonRow/ThanksButton

const KEY_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "awaken", "interact", "pause", "dialogue_advance"]
const KEY_LABELS := {
	"move_left": "向左",
	"move_right": "向右",
	"move_up": "向上 / 飞行上升",
	"move_down": "向下 / 双向攻击辅助",
	"jump": "跳跃",
	"attack": "攻击",
	"awaken": "觉醒",
	"interact": "互动",
	"pause": "暂停",
	"dialogue_advance": "推进对话",
}

var _suppress: bool = false


## 连接 authored 控件并配置核心键位列表。
func _ready() -> void:
	super._ready()
	_master_slider.value_changed.connect(_on_master)
	_music_slider.value_changed.connect(_on_music)
	_sfx_slider.value_changed.connect(_on_sfx)
	_ui_slider.value_changed.connect(_on_ui)
	_ambient_slider.value_changed.connect(_on_ambient)
	_setup_keybinding_ui()
	_return_button.pressed.connect(func(): close_modal())
	_thanks_button.pressed.connect(func(): thanks_requested.emit())


## 切换菜单态感谢入口可见性。
func set_show_thanks(value: bool) -> void:
	show_thanks = value
	if _thanks_button != null:
		_thanks_button.visible = value


## 打开前刷新设置值和键位显示。
func _on_before_open() -> void:
	_thanks_button.visible = show_thanks
	_refresh_from_settings()
	if _keybinding_ui != null:
		_keybinding_ui.refresh_all()


## 读取 SettingsModule 当前值到 authored 控件。
func _refresh_from_settings() -> void:
	var s := _settings()
	if s == null:
		return
	_suppress = true
	_master_slider.value = float(s.get_value("master_volume", 0.8))
	_music_slider.value = float(s.get_value("music_volume", 0.8))
	_sfx_slider.value = float(s.get_value("sfx_volume", 0.8))
	_ui_slider.value = float(s.get_value("ui_volume", 0.8))
	_ambient_slider.value = float(s.get_value("ambient_volume", 0.8))
	_suppress = false
	_update_labels()


## 同步所有百分比文本。
func _update_labels() -> void:
	_master_value.text = "%d%%" % roundi(_master_slider.value * 100.0)
	_music_value.text = "%d%%" % roundi(_music_slider.value * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx_slider.value * 100.0)
	_ui_value.text = "%d%%" % roundi(_ui_slider.value * 100.0)
	_ambient_value.text = "%d%%" % roundi(_ambient_slider.value * 100.0)


## 应用 Master 音量。
func _on_master(v: float) -> void: _apply("master_volume", v)

## 应用 Music 音量。
func _on_music(v: float) -> void: _apply("music_volume", v)

## 应用 Sounds 音量。
func _on_sfx(v: float) -> void: _apply("sfx_volume", v)

## 应用 UI 音量。
func _on_ui(v: float) -> void: _apply("ui_volume", v)

## 应用 Ambient 音量。
func _on_ambient(v: float) -> void: _apply("ambient_volume", v)

## 将单项设置写回 SettingsModule。
func _apply(key: String, value: Variant) -> void:
	_update_labels()
	if _suppress:
		return
	var s := _settings()
	if s != null:
		s.set_value(key, value)


## 配置核心键位 UI 的显示范围和中文标签。
func _setup_keybinding_ui() -> void:
	if _keybinding_ui == null:
		return
	_keybinding_ui.action_allowlist = PackedStringArray(KEY_ACTIONS)
	_keybinding_ui.label_map = KEY_LABELS.duplicate(true)
	if _keybinding_ui.is_node_ready():
		_keybinding_ui.refresh_all()


## 获取全局 SettingsModule。
func _settings() -> Object:
	var ss := get_node_or_null("/root/SaveSystem")
	if ss != null and ss.has_method("get_module"):
		return ss.get_module("settings")
	return null
