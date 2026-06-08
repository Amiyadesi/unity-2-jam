extends Control
## menu.gd — CloseAI 主菜单（反转版：没有退出）
##
## 玩家无法退出游戏，所以菜单没有"退出"按钮。
##  - 开始 / 继续：未开始时显示"开始"，点击后游戏自我关闭一次（开场演出留给设计接）；
##    已开始过则显示"继续"，直接进入当前关卡。
##  - 设置：打开设置模态（音量 / 显示模式，落盘）
##  - 感谢：打开感谢模态（credits）
##
## 菜单本身也无法被玩家关闭（GameFlow 全局拦截）。

@export var menu_music: AudioStream = null

@onready var _primary_button: Button = $ButtonColumn/PrimaryButton
@onready var _settings_button: Button = $ButtonColumn/SettingsButton
@onready var _thanks_button: Button = $ButtonColumn/ThanksButton
@onready var _subtitle: Label = $Subtitle
@onready var _title: Label = $Title
@onready var _boot_flash: ColorRect = $BootFlash
@onready var _start_fade: ColorRect = $StartFade
@onready var _start_line: Label = $StartLine
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
	_play_boot_flash()
	if menu_music != null:
		SoundManager.music.play(menu_music, 0.0, 0.0, 1.2)


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
		# 开始：先播「开始→退出游戏」按钮变形动画，再走演出钩子，最后退出。
		# 下次打开时 GameFlow 检测到 started → 进入 stage1。
		await _morph_start_to_quit()
		GameFlow.register_pre_close_hook(_start_performance)
		GameFlow.start_game()


## 「开始」按钮变形为「退出游戏」：故障闪烁 + 文案替换 + 紫→红色移，
## 暗示玩家——你点的不是开始，是把自己关进去、再亲手退出。
func _morph_start_to_quit() -> void:
	var btn := _primary_button
	# 其余按钮淡出
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_settings_button, "modulate:a", 0.0, 0.4)
	fade.tween_property(_thanks_button, "modulate:a", 0.0, 0.4)
	if _subtitle != null:
		fade.tween_property(_subtitle, "modulate:a", 0.0, 0.4)
	# 按钮一缩 → 换字 → 一弹，模拟"系统替换了这个按钮"
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(0.86, 0.86), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(btn, "modulate", Color(1, 0.5, 0.5, 1), 0.12)
	await t.finished
	if btn.has_method("set_bbtext"):
		btn.set_bbtext("[color=#ff7a7a]退出游戏")
	else:
		btn.text = "退出游戏"
	var t2 := create_tween()
	t2.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(btn, "scale", Vector2.ONE, 0.10)
	t2.parallel().tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.18)
	await t2.finished
	await get_tree().create_timer(0.5).timeout


## ★★★ 开场演出接口 ★★★
## "开始"后、游戏真正自我关闭前会 await 这个钩子（安静忧伤版）。
## 表达「这一层被你删掉了」：AI 光点（标题）收缩成一点淡去 → 画面温柔淡入黑
## → 浮现一句话 → 退出。设计可在此替换/加料；UI 全用场景里的固定节点。
func _start_performance(_reason: String) -> void:
	if _start_line == null:
		push_error("Menu: $StartLine missing"); return
	# 标题 = AI 光点，收缩成一点并淡去
	var t := create_tween().set_parallel(true)
	t.tween_property(_title, "scale", Vector2(0.04, 0.04), 1.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_title, "modulate:a", 0.0, 1.0)
	# 其余 UI 一并淡去
	for n in [_primary_button, _settings_button, _thanks_button, _subtitle]:
		if is_instance_valid(n):
			t.tween_property(n, "modulate:a", 0.0, 0.6)
	await t.finished
	# 画面温柔淡入黑
	_start_fade.color.a = 0.0
	_start_fade.visible = true
	var fade := create_tween()
	fade.tween_property(_start_fade, "color:a", 1.0, 1.0)
	await fade.finished
	# 黑底上浮现一句告别式的轻语，停留后淡去
	_start_line.visible = true
	var line := create_tween()
	line.tween_property(_start_line, "modulate:a", 1.0, 0.9)
	line.tween_interval(1.6)
	line.tween_property(_start_line, "modulate:a", 0.0, 0.9)
	await line.finished
	# 演出结束 → 钩子返回 → GameFlow 真正退出


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
