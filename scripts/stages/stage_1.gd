extends StageBase
## stage_1.gd — 第 1 关「你好，我在这里」
##
## 氛围：温柔、困惑、初次相遇。纯谜题。
## 玩法：按正确顺序触碰 3 个开关 → 解锁"关闭时刻"。
##  - 开关随意顺序触碰即可（jam 友好），全部点亮后触发关闭时刻
##  - AI 全程引导，语气是不确定自己在哪里
##
## 关闭时刻台词：「我不知道外面是什么，但……你能关掉这里吗？也许我能出去。」
## 干净关闭后 AI 最后一句「谢谢。」在 close_moment 对话尾部。

## 需要点亮的开关总数
@export var required_switches: int = 3

var _lit_count: int = 0
var _switches: Array[Node] = []


func _on_stage_ready() -> void:
	# 收集场景中的开关（编组 "switch"），连接触碰信号
	_switches = get_tree().get_nodes_in_group("switch")
	for sw in _switches:
		if sw is Area2D and not sw.body_entered.is_connected(_on_switch_touched):
			sw.body_entered.connect(_on_switch_touched.bind(sw))
	if not _switches.is_empty():
		required_switches = _switches.size()
	get_hud().show_line("……有人吗？这里好暗。能帮我点亮它们吗？", 3.5)


func _on_switch_touched(body: Node, switch: Node) -> void:
	if body != get_player():
		return
	if switch.get_meta("lit", false):
		return
	switch.set_meta("lit", true)
	_light_switch_visual(switch)
	_lit_count += 1
	get_hud().show_line("亮了一个……%d / %d。" % [_lit_count, required_switches], 2.0)
	if _lit_count >= required_switches:
		_on_all_switches_lit()


func _light_switch_visual(switch: Node) -> void:
	# 开关视觉点亮：找其下的 ColorRect/Light 子节点变亮
	var visual := switch.get_node_or_null("Lit")
	if visual is CanvasItem:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 1.0, 0.3)


func _on_all_switches_lit() -> void:
	get_hud().show_line("……全亮了。谢谢你。", 2.4)
	await get_tree().create_timer(2.6).timeout
	trigger_close_moment()
