extends Node
class_name WindowUiScaler
## 窗口 UI 缩放器（移植自 Booom，纯 GDScript）
##
## 把目标 Control 按窗口尺寸相对 base_size 缩放，保持 1280x720 设计基准。
## STRETCH：拉伸填满；FIT：等比内缩居中；COVER：等比外扩居中。

enum ScaleMode { STRETCH, FIT, COVER }

@export var target_path: NodePath = ^".."
@export var base_size := Vector2(1280.0, 720.0)
@export var scale_mode := ScaleMode.STRETCH

var _target: Control
var _window: Window


func _ready() -> void:
	_target = get_node_or_null(target_path) as Control
	if _target == null:
		push_warning("WindowUiScaler target must be a Control.")
		return
	_window = _target.get_window()
	if _window != null and not _window.size_changed.is_connected(_apply_scale):
		_window.size_changed.connect(_apply_scale)
	call_deferred("_apply_scale")


func _exit_tree() -> void:
	if _window != null and _window.size_changed.is_connected(_apply_scale):
		_window.size_changed.disconnect(_apply_scale)


func _apply_scale() -> void:
	if _target == null:
		return
	var window_size := _get_window_size()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or base_size.x <= 0.0 or base_size.y <= 0.0:
		return

	var ratio := Vector2(window_size.x / base_size.x, window_size.y / base_size.y)
	var ui_scale := ratio
	var offset := Vector2.ZERO
	match scale_mode:
		ScaleMode.FIT:
			var uniform_fit := minf(ratio.x, ratio.y)
			ui_scale = Vector2.ONE * uniform_fit
			offset = (window_size - base_size * uniform_fit) * 0.5
		ScaleMode.COVER:
			var uniform_cover := maxf(ratio.x, ratio.y)
			ui_scale = Vector2.ONE * uniform_cover
			offset = (window_size - base_size * uniform_cover) * 0.5
		_:
			ui_scale = ratio

	_target.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_target.position = offset
	_target.size = base_size
	_target.custom_minimum_size = base_size
	_target.pivot_offset = Vector2.ZERO
	_target.scale = ui_scale
	if _target is Container:
		(_target as Container).queue_sort()


func _get_window_size() -> Vector2:
	if _window != null:
		return Vector2(_window.size)
	var viewport := get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size
	return base_size
