extends Control
class_name ModalScreen
## modal_screen.gd — 模态面板基类（玻璃/监视器风）
##
## 提供统一的 open_modal() / close_modal() 动画与背景遮罩。
## 子类（设置 / 感谢）在场景里摆放自己的内容节点，复用这里的开合表现。
##
## 结构约定（子类场景需有）：
##   Backdrop  : ColorRect  半透明黑遮罩
##   Panel     : Control     面板根（缩放+位移动画作用对象）
##
## 设计：开合用 cubic 缓动 + 轻微缩放/上浮，遮罩淡入淡出，质感统一。

signal opened()
signal closed()

@export var open_duration: float = 0.28
@export var close_duration: float = 0.22
## 面板从下方上浮的初始偏移
@export var rise_offset: float = 28.0

@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel: Control = $Panel

var _is_open: bool = false
var _panel_home: Vector2


func _ready() -> void:
	visible = false
	_panel_home = _panel.position
	_backdrop.color.a = 0.0
	_panel.modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP


## 打开模态：返回 Tween 以便调用方 await
func open_modal() -> Tween:
	visible = true
	_is_open = true
	_panel.position = _panel_home + Vector2(0, rise_offset)
	_panel.scale = Vector2(0.98, 0.98)
	_on_before_open()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "color:a", _backdrop_target_alpha(), open_duration)
	tween.tween_property(_panel, "modulate:a", 1.0, open_duration)
	tween.tween_property(_panel, "position", _panel_home, open_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, open_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): opened.emit())
	return tween


## 关闭模态：返回 Tween 以便调用方 await
func close_modal() -> Tween:
	_is_open = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "color:a", 0.0, close_duration)
	tween.tween_property(_panel, "modulate:a", 0.0, close_duration)
	tween.tween_property(_panel, "position", _panel_home + Vector2(0, rise_offset * 0.6), close_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		visible = false
		closed.emit())
	return tween


func is_open() -> bool:
	return _is_open


## 遮罩目标透明度（子类可调）
func _backdrop_target_alpha() -> float:
	return 0.7

## [virtual] 打开前刷新内容（如从存档读取设置）
func _on_before_open() -> void:
	pass
