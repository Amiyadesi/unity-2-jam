extends Area2D
class_name InteractNode
## interact_node.gd — 可交互连接节点（第 1 关教学用「互动」动词）
##
## 玩家进入范围 → 显示 "E" 提示；按 interact(E) → 激活一次，发出 activated。
## 与第 1 关的「走进即亮」开关不同：这个必须按键，用来教 E 这个动词。
##
## 放置：collision_mask=2 检测 player；子节点含 "Lit"(初始透明) 与可选 "Prompt"(初始隐藏)。

signal activated(node: Area2D)

## 激活后不可再次触发
@export var one_shot: bool = true

var _player_in_range: bool = false
var activated_done: bool = false
var _enabled: bool = true

@onready var _lit: CanvasItem = get_node_or_null("Lit") as CanvasItem
@onready var _prompt: CanvasItem = get_node_or_null("Prompt") as CanvasItem


## 初始化互动节点默认视觉状态和玩家检测信号。
func _ready() -> void:
	if not _require_authored_visuals():
		set_enabled(false)
		return
	add_to_group("interact_node")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(_enabled)
	monitoring = _enabled
	_set_lit(0.0, true)
	_set_prompt(false)


## 校验互动节点必须 authored 的视觉反馈节点。
func _require_authored_visuals() -> bool:
	var ok := true
	if _lit == null:
		push_error("%s requires authored Lit visual." % name)
		ok = false
	if _prompt == null:
		push_error("%s requires authored Prompt visual." % name)
		ok = false
	return ok


## 玩家在范围内按下 interact 时激活节点。
func _process(_delta: float) -> void:
	if not _enabled:
		return
	if not _player_in_range:
		return
	if activated_done and one_shot:
		return
	if Input.is_action_just_pressed("interact"):
		_activate()


## 玩家进入触发范围时显示按键提示。
func _on_body_entered(body: Node) -> void:
	if not _enabled:
		return
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	if not (activated_done and one_shot):
		_set_prompt(true)


## 玩家离开触发范围时隐藏按键提示。
func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = false
	_set_prompt(false)


## 开关教学门控：禁用时不响应输入也不显示提示。
func set_enabled(value: bool) -> void:
	_enabled = value
	set_process(value)
	monitoring = value
	if not value:
		_player_in_range = false
		_set_prompt(false)
		return
	_refresh_player_overlap.call_deferred()


## 重新启用后检查玩家是否已经站在触发范围内。
func _refresh_player_overlap() -> void:
	if not _enabled:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_player_in_range = true
			if not (activated_done and one_shot):
				_set_prompt(true)
			return


## 测试/脚本可直接调用（headless 下无 Input）
func activate() -> void:
	_activate()


## 执行一次互动激活并发出完成信号。
func _activate() -> void:
	if not _enabled:
		return
	if activated_done and one_shot:
		return
	activated_done = true
	_set_lit(1.0, false)
	_set_prompt(false)
	activated.emit(self)


## 更新点亮层透明度。
func _set_lit(a: float, instant: bool) -> void:
	if _lit == null:
		push_error("%s cannot update Lit because authored visual is missing." % name)
		return
	if instant:
		_lit.modulate.a = a
	else:
		var tw := create_tween()
		tw.tween_property(_lit, "modulate:a", a, 0.25)


## 控制 authored 提示标签显隐。
func _set_prompt(show_it: bool) -> void:
	if _prompt == null:
		push_error("%s cannot update Prompt because authored visual is missing." % name)
		return
	_prompt.visible = show_it
