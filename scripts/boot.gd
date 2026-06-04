extends Control
## boot.gd — CloseAI 启动场景（主场景）
##
## 职责：
##  ① 等待 SaveSystem 完成全局存档读取（StatsModule 锁存上次退出状态）
##  ② 极简启动画面（黑底 + 一行字淡入淡出）
##  ③ 路由到主菜单
##
## 不在这里做关卡判断——菜单负责"开始/继续"。boot 只是把控制权交给菜单。

@onready var _boot_label: Label = $BootLabel

## 启动画面停留时长（秒）
@export var boot_duration: float = 1.1

func _ready() -> void:
	_boot_label.modulate.a = 0.0
	await _play_boot_intro()
	# 根据进度路由：未开始→菜单；通关→结局；游玩中→当前关卡
	GameFlow.enter_after_boot()


## 黑屏 → 标题淡入 → 短暂停留 → 淡出
func _play_boot_intro() -> void:
	var tween := create_tween()
	tween.tween_property(_boot_label, "modulate:a", 1.0, boot_duration * 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(boot_duration * 0.3)
	tween.tween_property(_boot_label, "modulate:a", 0.0, boot_duration * 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
