class_name InfoOverlay
extends CanvasLayer
## info_overlay.gd — 信息流 overlay（面包屑 toast + 常驻 hint），移植自 Booom hstory_runtime。
## 精简：去掉 popup 与 DialogueLabel 依赖；纯 GDScript + 固定模板场景。
## 紫色极简装置风。布局语法：anchor[+x,y][@WxH]，如 "top_right+0,12@360x84"。

@onready var _breadcrumb_feed: Control = %BreadcrumbFeed
@onready var _hint_feed: Control = %HintFeed
@onready var _breadcrumb_pool: Node = %BreadcrumbPool
@onready var _hint_pool: Node = %HintPool

var _hints: Dictionary = {}
var _breadcrumb_items: Array[Control] = []
var _breadcrumb_layout_specs: Dictionary = {}


## 初始化 authored 池，确保所有预放控件默认隐藏。
func _ready() -> void:
	_require_authored_pools()
	_reset_pool(_breadcrumb_pool)
	_reset_pool(_hint_pool)


## toast：限时通知，自动淡出，纵向堆叠。
func show_toast(seconds: float, title: String, text: String, layout_spec: String = "top_right") -> void:
	var item := _take_from_pool(_breadcrumb_pool, "breadcrumb") as Control
	if item == null:
		return
	_breadcrumb_items.append(item)
	_breadcrumb_layout_specs[item.get_instance_id()] = layout_spec
	_set_label_text(item, "BreadcrumbTitle", title)
	_set_label_text(item, "BreadcrumbText", text)
	item.show()
	_apply_breadcrumb_layouts()

	var life_bar := item.get_node_or_null("%LifeBar") as ProgressBar
	if life_bar != null:
		life_bar.value = 1.0
		var tween := item.create_tween()
		tween.tween_property(life_bar, "value", 0.0, maxf(seconds, 0.05))

	await get_tree().create_timer(maxf(seconds, 0.05)).timeout
	if is_instance_valid(item):
		_breadcrumb_items.erase(item)
		_breadcrumb_layout_specs.erase(item.get_instance_id())
		_release_to_pool(item)
		_apply_breadcrumb_layouts()


## hint：按 channel 常驻提示，mode="hide" 隐藏。
func show_hint(channel: String, text: String, mode: String = "show", layout_spec: String = "right") -> void:
	if mode == "hide":
		hide_hint(channel)
		return
	var item: Control = _hints.get(channel) as Control
	if item == null:
		item = _take_from_pool(_hint_pool, "hint") as Control
		if item == null:
			return
		_hints[channel] = item
	_set_label_text(item, "HintText", text)
	apply_canvas_layout_spec(item, layout_spec)
	item.show()


## 隐藏指定频道 hint 并归还池。
func hide_hint(channel: String) -> void:
	var item: Control = _hints.get(channel) as Control
	if item == null:
		return
	_release_to_pool(item)
	_hints.erase(channel)


## 隐藏全部 hint 并归还池。
func clear_hints() -> void:
	for item in _hints.values():
		if is_instance_valid(item):
			_release_to_pool(item)
	_hints.clear()


## 根据兼容 layout spec 摆放控件。
func apply_canvas_layout_spec(target: Control, layout_spec: String, stack_index: int = 0) -> void:
	var parsed := _parse_layout_spec(layout_spec, target.custom_minimum_size)
	var size: Vector2 = parsed["size"]
	var layout_offset: Vector2 = parsed["offset"]
	layout_offset.y += float(stack_index) * (size.y + 8.0)
	target.set_anchors_preset(Control.PRESET_TOP_LEFT)
	target.custom_minimum_size = size
	target.size = size
	var viewport_size := get_viewport().get_visible_rect().size
	var position := _anchor_to_position(parsed["anchor"], viewport_size, size) + layout_offset
	target.position = position


## 按每条 toast 自己的布局堆叠，避免新提示把旧提示迁移到另一个位置。
func _apply_breadcrumb_layouts() -> void:
	var stack_counts := {}
	for index in _breadcrumb_items.size():
		var item := _breadcrumb_items[index]
		if is_instance_valid(item):
			var layout_spec := String(_breadcrumb_layout_specs.get(item.get_instance_id(), "top_right"))
			var stack_index := int(stack_counts.get(layout_spec, 0))
			apply_canvas_layout_spec(item, layout_spec, stack_index)
			stack_counts[layout_spec] = stack_index + 1


## 给池内模板控件写入 Label/RichTextLabel 文案。
func _set_label_text(root: Node, node_name: String, value: String) -> void:
	var node := root.get_node_or_null("%" + node_name)
	if node is RichTextLabel:
		node.text = value
	elif node is Label:
		node.text = value


## 校验 authored 池节点存在。
func _require_authored_pools() -> void:
	if _breadcrumb_feed == null or _breadcrumb_pool == null:
		push_error("InfoOverlay requires authored BreadcrumbFeed/BreadcrumbPool.")
	if _hint_feed == null or _hint_pool == null:
		push_error("InfoOverlay requires authored HintFeed/HintPool.")


## 将池内控件隐藏并清空运行时文本。
func _reset_pool(pool: Node) -> void:
	if pool == null:
		return
	for child in pool.get_children():
		if child is Control:
			_release_to_pool(child)


## 从 authored 池中租用一个隐藏控件；池不够时显式报错。
func _take_from_pool(pool: Node, label: String) -> Control:
	if pool == null:
		push_error("InfoOverlay missing authored %s pool." % label)
		return null
	for child in pool.get_children():
		if child is Control and not (child as Control).visible:
			return child
	push_error("InfoOverlay %s pool exhausted; add more authored pool items." % label)
	return null


## 归还控件到池并隐藏。
func _release_to_pool(item: Control) -> void:
	if item == null:
		return
	item.hide()
	item.modulate.a = 1.0
	if item is PanelContainer:
		item.scale = Vector2.ONE
	_set_label_text(item, "BreadcrumbTitle", "")
	_set_label_text(item, "BreadcrumbText", "")
	_set_label_text(item, "HintText", "")
	var life_bar := item.get_node_or_null("%LifeBar") as ProgressBar
	if life_bar != null:
		life_bar.value = 1.0


## 解析兼容布局 DSL。
func _parse_layout_spec(layout_spec: String, fallback_size: Vector2) -> Dictionary:
	var spec := layout_spec.strip_edges()
	if spec.is_empty():
		spec = "center"
	var anchor_part := spec
	var size := fallback_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(360, 84)
	var at_index := spec.find("@")
	if at_index >= 0:
		anchor_part = spec.substr(0, at_index)
		size = _parse_size(spec.substr(at_index + 1), size)
	var anchor := anchor_part
	var layout_offset := Vector2.ZERO
	var plus_index := anchor_part.find("+")
	if plus_index >= 0:
		anchor = anchor_part.substr(0, plus_index)
		layout_offset = _parse_offset(anchor_part.substr(plus_index + 1))
	elif anchor_part.find("-") > 0:
		var minus_index := anchor_part.find("-")
		anchor = anchor_part.substr(0, minus_index)
		layout_offset = -_parse_offset(anchor_part.substr(minus_index + 1))
	return {"anchor": anchor.strip_edges(), "offset": layout_offset, "size": size}


## 解析 "WxH" 尺寸片段。
func _parse_size(value: String, fallback: Vector2) -> Vector2:
	var parts := value.to_lower().split("x", false)
	if parts.size() != 2:
		return fallback
	var w := parts[0].to_float()
	var h := parts[1].to_float()
	return Vector2(w, h) if w > 0.0 and h > 0.0 else fallback


## 解析 "x,y" 偏移片段。
func _parse_offset(value: String) -> Vector2:
	var parts := value.split(",", false)
	if parts.size() != 2:
		return Vector2.ZERO
	return Vector2(parts[0].to_float(), parts[1].to_float())


## 将布局锚点名转换为屏幕位置。
func _anchor_to_position(anchor: String, vp: Vector2, size: Vector2) -> Vector2:
	match anchor:
		"top": return Vector2((vp.x - size.x) * 0.5, 24)
		"bottom": return Vector2((vp.x - size.x) * 0.5, vp.y - size.y - 24)
		"left": return Vector2(24, (vp.y - size.y) * 0.5)
		"right": return Vector2(vp.x - size.x - 24, (vp.y - size.y) * 0.5)
		"top_left": return Vector2(24, 24)
		"top_right": return Vector2(vp.x - size.x - 24, 24)
		"bottom_left": return Vector2(24, vp.y - size.y - 24)
		"bottom_right": return Vector2(vp.x - size.x - 24, vp.y - size.y - 24)
		_: return (vp - size) * 0.5
