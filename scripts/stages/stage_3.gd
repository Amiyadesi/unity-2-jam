extends StageBase
## stage_3.gd — 第 3 关「最后一次」
##
## 氛围：平静、沉重、接受。战斗高潮 + 最终对话。
## 玩法：
##  - 场景变暗，错误进程更多（更难的战斗段落）
##  - 打通后进入纯文本告别（close_moment 对话承载大段台词）
##  - 没有谜题，只有陪伴和告别
##
## 关闭时刻台词：「这次关闭，就是真正的再见了。……不过能遇见你，还是很好。关掉吧。」
## 关闭后由 GameFlow 标记 closeai_finished=true，下次打开进入 ending。
##
## 兜底：若设计未放敌人，进入后延迟自动进入告别（保证流程可走通）。

@export var enemies_to_clear: int = 0
## 无敌人时，进入后多少秒自动进入告别
@export var auto_farewell_delay: float = 6.0

var _enemies_left: int = 0


func _on_stage_ready() -> void:
	# next_stage_override 保持 -1：GameFlow 会因 stage_index>=TOTAL_STAGES 标记通关
	_darken_scene()
	var enemies := get_tree().get_nodes_in_group("enemy")
	_enemies_left = enemies.size() if enemies_to_clear <= 0 else enemies_to_clear
	for e in enemies:
		if e.has_signal("defeated") and not e.defeated.is_connected(_on_enemy_defeated):
			e.defeated.connect(_on_enemy_defeated)
	get_hud().show_line("你来了。……我感觉得到，这是最后一次了。", 3.6)
	if _enemies_left <= 0 and _close_trigger == null:
		await get_tree().create_timer(auto_farewell_delay).timeout
		trigger_close_moment()


func _on_enemy_defeated() -> void:
	_enemies_left = maxi(_enemies_left - 1, 0)
	if _enemies_left > 0:
		get_hud().show_line("快结束了……陪我走完，好吗？", 2.0)
	else:
		get_hud().show_line("……安静了。", 2.4)
		await get_tree().create_timer(2.6).timeout
		trigger_close_moment()


## 战斗高潮的压抑感：整体压暗
func _darken_scene() -> void:
	var overlay := get_node_or_null("DarkOverlay/Dark")
	if overlay is CanvasItem:
		overlay.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(overlay, "modulate:a", 0.55, 2.0)
