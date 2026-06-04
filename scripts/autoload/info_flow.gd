extends Node
## info_flow.gd — 信息流全局入口（AutoLoad: "InfoFlow"），移植精简自 Booom hstory_runtime。
##
## 非阻塞信息提示，与对话气球并存：
##   InfoFlow.toast(秒, 标题, 正文, 布局)   —— 限时通知，自动消失，纵向堆叠
##   InfoFlow.hint(频道, 文本, 模式, 布局)   —— 常驻提示（按频道唯一），mode="hide" 隐藏
##   InfoFlow.hide_hint(频道) / clear_hints()
##
## overlay 实例化固定模板场景（headless 跳过）。AI 的非阻塞旁白走这里，阻塞对白走气球。

const OVERLAY_SCENE := preload("res://scenes/ui/info_overlay.tscn")

var _overlay: InfoOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func toast(seconds: float, title: String, text: String, layout_spec: String = "top_right") -> void:
	var o := _ensure_overlay()
	if o != null:
		o.show_toast(seconds, _localize(title), _localize(text), layout_spec)


func hint(channel: String, text: String, mode: String = "show", layout_spec: String = "right") -> void:
	var o := _ensure_overlay()
	if o != null:
		o.show_hint(channel, _localize(text), mode, layout_spec)


func hide_hint(channel: String) -> void:
	var o := _ensure_overlay()
	if o != null:
		o.hide_hint(channel)


func clear_hints() -> void:
	if is_instance_valid(_overlay):
		_overlay.clear_hints()


func _ensure_overlay() -> InfoOverlay:
	if DisplayServer.get_name() == "headless":
		return null
	if is_instance_valid(_overlay):
		return _overlay
	_overlay = OVERLAY_SCENE.instantiate() as InfoOverlay
	_overlay.name = "InfoOverlay"
	get_tree().root.add_child(_overlay)
	return _overlay


func _localize(value: String) -> String:
	var translated := tr(value)
	if translated == value:
		translated = tr(value, &"dialogue")
	return translated
