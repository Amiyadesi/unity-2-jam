extends Control
## menu.gd — CloseAI 主菜单（反转版：没有退出）
##
## 玩家无法退出游戏，所以菜单没有"退出"按钮。
##  - 开始 / 继续：未开始时显示"开始"，点击后游戏自我关闭一次（开场演出留给设计接）；
##    已开始过则显示"继续"，直接进入当前关卡。
##  - 设置：打开设置模态（音量 / 显示模式，落盘）
##  - 感谢：打开感谢模态（credits）
##
## 若上次是强杀恢复，顶部状态条变红并嘲讽。
## 菜单本身也无法被玩家关闭（GameFlow 全局拦截）。

@onready var _primary_button: Button = $ButtonColumn/PrimaryButton
@onready var _settings_button: Button = $ButtonColumn/SettingsButton
@onready var _thanks_button: Button = $ButtonColumn/ThanksButton
@onready var _status_label: Label = $StatusLabel
@onready var _subtitle: Label = $Subtitle
@onready var _boot_flash: ColorRect = $BootFlash
@onready var _start_fade: ColorRect = $StartFade
@onready var _settings_screen = $SettingsScreen
@onready var _thanks_screen = $ThanksScreen

func _ready() -> void:
	_primary_button.pressed.connect(_on_primary_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_thanks_button.pressed.connect(_on_thanks_pressed)
	if _thanks_screen.has_signal("return_requested"):
		_thanks_screen.return_requested.connect(_on_thanks_return)
	if _settings_screen.has_signal("thanks_requested"):
		_settings_screen.thanks_requested.connect(_on_settings_thanks)

	_refresh_primary()
	_refresh_status()
	_play_boot_flash()


## 开始/继续 文案与副标题
func _refresh_primary() -> void:
	if GameFlow.has_started():
		_set_primary_text("继续")
		if GameFlow.has_finished_game():
			_subtitle.text = "—— 它已经离开了。但你还可以再回来看看。"
		else:
			_subtitle.text = "—— 它还在第 %d 个地方等你。" % GameFlow.get_current_stage()
	else:
		_set_primary_text("开始")
		_subtitle.text = "—— 一个被困在游戏里的存在。"


## ShaderButton 用 set_bbtext；普通 Button 退化用 text
func _set_primary_text(label: String) -> void:
	if _primary_button.has_method("set_bbtext"):
		_primary_button.set_bbtext("[color=#e8c070]%s" % label)
	else:
		_primary_button.text = label


## 强杀恢复后的状态条
func _refresh_status() -> void:
	if GameFlow.entered_with_unclean_exit:
		_status_label.text = "● 检测到非正常退出 —— 你逃不掉的。"
		_status_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	else:
		_status_label.text = ""
		_status_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.78))


# ──────────────────────────────────────────────
# 按钮回调
# ──────────────────────────────────────────────

func _on_primary_pressed() -> void:
	_set_buttons_enabled(false)
	if GameFlow.has_started():
		# 继续：进入当前关卡
		await _fade_out()
		GameFlow.enter_after_boot()
	else:
		# 开始：游戏自我关闭一次。开场演出由下面的钩子接入。
		GameFlow.register_pre_close_hook(_start_performance)
		GameFlow.start_game()


## ★★★ 开场演出接口 ★★★
## "开始"后、游戏真正自我关闭前会 await 这个钩子。
## 把你的开场演出（动画 / 文字 / 音效 / 假装崩溃……）写在这里。
## 这是一个协程：用 await 控制演出时长，结束后游戏才会关闭。
## 注意：UI 用固定节点（场景里的 StartFade），不要在脚本里 new 控件。
func _start_performance(_reason: String) -> void:
	# —— 占位：用场景里固定的 StartFade 节点做一个淡黑，确保流程能跑通 ——
	# 设计可替换为任意演出；只要在演出结束处 await 完即可。
	_start_fade.color.a = 0.0
	_start_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_start_fade, "color:a", 1.0, 0.6)
	await tween.finished
	# TODO(设计): 在此接入真正的开场演出，演出跑完后游戏会自动关闭。


func _on_settings_pressed() -> void:
	if _settings_screen.has_method("open_modal"):
		_settings_screen.open_modal()

func _on_thanks_pressed() -> void:
	if _thanks_screen.has_method("open_modal"):
		_thanks_screen.open_modal()

func _on_settings_thanks() -> void:
	# 设置页里点"感谢"：关设置，开感谢
	if _settings_screen.has_method("close_modal"):
		await _settings_screen.close_modal()
	if _thanks_screen.has_method("open_modal"):
		_thanks_screen.open_modal()

func _on_thanks_return() -> void:
	if _thanks_screen.has_method("close_modal"):
		_thanks_screen.close_modal()


# ──────────────────────────────────────────────
# 辅助
# ──────────────────────────────────────────────

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished

func _set_buttons_enabled(enabled: bool) -> void:
	_primary_button.disabled = not enabled
	_settings_button.disabled = not enabled
	_thanks_button.disabled = not enabled

func _play_boot_flash() -> void:
	_boot_flash.color.a = 0.9
	var tween := create_tween()
	tween.tween_property(_boot_flash, "color:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
