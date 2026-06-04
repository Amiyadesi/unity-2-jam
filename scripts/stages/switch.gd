extends Area2D
## switch.gd — 第 1 关谜题开关
##
## 玩家碰到即"点亮"。点亮逻辑由 stage_1.gd 统一管理（监听 body_entered）。
## 本脚本只负责自身视觉默认态与编组登记。
## 放置：加入编组 "switch"，子节点含名为 "Lit" 的 CanvasItem（初始透明）。

func _ready() -> void:
	add_to_group("switch")
	set_meta("lit", false)
	var lit := get_node_or_null("Lit")
	if lit is CanvasItem:
		lit.modulate.a = 0.0
