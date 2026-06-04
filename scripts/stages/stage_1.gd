extends StageBase
## stage_1.gd — 第 1 关
##
## 纯谜题：触碰 3 个节点点亮，全亮后解锁「关闭时刻」。
## 核心只有一个：把这里走到尽头，然后关掉游戏，才能继续。
## 旁白走 InfoFlow 面包屑（say）。

@export var required_switches: int = 3

var _lit_count: int = 0
var _switches: Array[Node] = []


func _on_stage_ready() -> void:
	_switches = get_tree().get_nodes_in_group("switch")
	for sw in _switches:
		if sw is Area2D and not sw.body_entered.is_connected(_on_switch_touched):
			sw.body_entered.connect(_on_switch_touched.bind(sw))
	if not _switches.is_empty():
		required_switches = _switches.size()
	say("点亮这里的每一个节点。", 3.0)


func _on_switch_touched(body: Node, switch: Node) -> void:
	if body != get_player():
		return
	if switch.get_meta("lit", false):
		return
	switch.set_meta("lit", true)
	_light_switch_visual(switch)
	_lit_count += 1
	say("%d / %d" % [_lit_count, required_switches], 1.6, "top_right+0,12@200x56")
	if _lit_count >= required_switches:
		_on_all_switches_lit()


func _light_switch_visual(switch: Node) -> void:
	var visual := switch.get_node_or_null("Lit")
	if visual is CanvasItem:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 1.0, 0.3)


func _on_all_switches_lit() -> void:
	say("都亮了。……现在，关掉游戏吧。", 2.6)
	await get_tree().create_timer(2.6).timeout
	trigger_close_moment()

