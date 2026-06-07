extends Node
## info_flow.gd — 信息流全局入口（AutoLoad: "InfoFlow"），移植精简自 Booom hstory_runtime。
##
## 非阻塞信息提示，与对话气球并存：
##   InfoFlow.toast(秒, 标题, 正文, 布局)   —— 限时通知，自动消失，纵向堆叠
##   InfoFlow.hint(频道, 文本, 模式, 布局)   —— 常驻提示（按频道唯一），mode="hide" 隐藏
##   InfoFlow.hide_hint(频道) / clear_hints()
##
## overlay 由 authored autoload scene 提供。AI 的非阻塞旁白走这里，阻塞对白走气球。

var _overlay: InfoOverlay


## 缓存 authored overlay 子节点。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = get_node_or_null("InfoOverlay") as InfoOverlay
	if _overlay == null and DisplayServer.get_name() != "headless":
		push_error("InfoFlow requires authored child InfoOverlay.")


## 显示一条池化 toast。
func toast(seconds: float, title: String, text: String, layout_spec: String = "top_right") -> void:
	var o := _ensure_overlay()
	if o != null:
		o.show_toast(seconds, _localize(title), _localize(text), layout_spec)


## 显示或隐藏一个按频道唯一的池化 hint。
func hint(channel: String, text: String, mode: String = "show", layout_spec: String = "right") -> void:
	var o := _ensure_overlay()
	if o != null:
		o.show_hint(channel, _localize(text), mode, layout_spec)


## 隐藏指定频道 hint。
func hide_hint(channel: String) -> void:
	var o := _ensure_overlay()
	if o != null:
		o.hide_hint(channel)


## 隐藏全部 hint。
func clear_hints() -> void:
	if is_instance_valid(_overlay):
		_overlay.clear_hints()


## 返回 authored overlay；headless 下保持空操作。
func _ensure_overlay() -> InfoOverlay:
	if DisplayServer.get_name() == "headless":
		return null
	if is_instance_valid(_overlay):
		return _overlay
	_overlay = get_node_or_null("InfoOverlay") as InfoOverlay
	if _overlay == null:
		push_error("InfoFlow requires authored child InfoOverlay.")
	return _overlay


## 翻译提示文案，优先普通域，兜底 dialogue 域。
func _localize(value: String) -> String:
	var translated := tr(value)
	if translated == value:
		translated = tr(value, &"dialogue")
	return translated
