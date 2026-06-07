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

## 根据 post-game 状态跳过启动黑屏，否则播放普通启动演出。
func _ready() -> void:
	if GameFlow.has_openai_flag() or GameFlow.has_finished_game():
		await get_tree().process_frame
		GameFlow.enter_after_boot()
		return
	_enforce_display_mode()
	_boot_label.modulate.a = 0.0
	await _play_boot_intro()
	# 根据进度路由：未开始→菜单；游玩中→当前关卡。
	GameFlow.enter_after_boot()


## 启动时按存档设置应用窗口模式（默认全屏）。
## SettingsModule 在 global_loaded 时已 apply，但此处再确认一次，
## 兜底窗口管理器/时序问题，保证默认全屏生效。
func _enforce_display_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := "fullscreen"
	var ss := get_node_or_null("/root/SaveSystem")
	if ss != null and ss.has_method("get_module"):
		var settings = ss.get_module("settings")
		if settings != null and settings.has_method("get_value"):
			mode = str(settings.get_value("display_mode", "fullscreen"))
	if mode == "fullscreen":
		get_window().mode = Window.MODE_FULLSCREEN


## 黑屏 → 标题淡入 → 短暂停留 → 淡出
func _play_boot_intro() -> void:
	var tween := create_tween()
	tween.tween_property(_boot_label, "modulate:a", 1.0, boot_duration * 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(boot_duration * 0.3)
	tween.tween_property(_boot_label, "modulate:a", 0.0, boot_duration * 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
