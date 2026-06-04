extends Control
class_name GlassModal
## glass_modal.gd — 金棕玻璃风模态基类（CloseAI 统一 UI 基调）
##
## 提供统一开合动画 + 玻璃遮罩。子类场景（设置/感谢/暂停）复用同一套视觉与开合：
## 约定子结构（fixed template，场景里摆好）：
##   Backdrop : ColorRect（带 glass_blur 着色器，全屏，作模糊+压暗遮罩）
##   Panel    : Control/Panel（面板根，开合动画作用对象；面板内含 Frame/ScanVFX/DefectVFX 等）
##
## 开合用 cubic + back 缓动 + 上浮，遮罩淡入淡出。process_mode 设 ALWAYS 以便暂停时仍可交互。

signal opened()
signal closed()

@export var open_duration: float = 0.28
@export var close_duration: float = 0.22
@export var rise_offset: float = 26.0
@export var backdrop_alpha: float = 1.0

@onready var _backdrop: Control = $Backdrop
@onready var _panel: Control = $Panel

var _is_open: bool = false
var _panel_home: Vector2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_panel_home = _panel.position
	_backdrop.modulate.a = 0.0
	_panel.modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func open_modal() -> Tween:
	visible = true
	_is_open = true
	_panel.position = _panel_home + Vector2(0, rise_offset)
	_panel.scale = Vector2(0.98, 0.98)
	_on_before_open()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", backdrop_alpha, open_duration)
	tween.tween_property(_panel, "modulate:a", 1.0, open_duration)
	tween.tween_property(_panel, "position", _panel_home, open_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, open_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): opened.emit())
	return tween


func close_modal() -> Tween:
	_is_open = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 0.0, close_duration)
	tween.tween_property(_panel, "modulate:a", 0.0, close_duration)
	tween.tween_property(_panel, "position", _panel_home + Vector2(0, rise_offset * 0.6), close_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		visible = false
		closed.emit())
	return tween


func is_open() -> bool:
	return _is_open


## [virtual] 打开前刷新内容（如从存档读取设置）
func _on_before_open() -> void:
	pass
