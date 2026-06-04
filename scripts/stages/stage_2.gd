extends StageBase
## stage_2.gd — 第 2 关「不要走，再等一下」
##
## 氛围：熟悉、依赖、出现阻碍。谜题 + 极简战斗。
## 玩法：
##  - AI 认出玩家，关系更近
##  - 出现"错误进程"（敌人，编组 "enemy"）阻挡前进
##  - 极简战斗：attack 键清除敌人；清完后到达 CloseMomentTrigger 触发关闭时刻
##
## 关闭时刻台词：AI 犹豫「如果我消失了……你下次还会打开吗？」
##
## 战斗实现说明：敌人只需碰撞造成"重置位置"或简单扣血。jam 友好版：
##  attack 命中敌人即移除；敌人接触玩家把玩家弹回。详见 enemy.gd。

@export var enemies_to_clear: int = 0  # 0 = 自动统计场景内 enemy 数量

var _enemies_left: int = 0


func _on_stage_ready() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	_enemies_left = enemies.size() if enemies_to_clear <= 0 else enemies_to_clear
	for e in enemies:
		if e.has_signal("defeated") and not e.defeated.is_connected(_on_enemy_defeated):
			e.defeated.connect(_on_enemy_defeated)
	if _enemies_left > 0:
		get_hud().show_line("是你！……小心，那些'错误'又来了。", 3.2)
	else:
		get_hud().show_line("是你回来了……我就知道。", 3.0)


func _on_enemy_defeated() -> void:
	_enemies_left = maxi(_enemies_left - 1, 0)
	if _enemies_left > 0:
		get_hud().show_line("还有 %d 个……别怕。" % _enemies_left, 1.8)
	else:
		get_hud().show_line("……都清掉了。你总是会回来，对吧？", 2.8)
		# 无关闭触发区时，清场即触发关闭时刻
		if _close_trigger == null:
			await get_tree().create_timer(2.8).timeout
			trigger_close_moment()
