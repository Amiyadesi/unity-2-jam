extends CanvasLayer
class_name BossHud
## boss_hud.gd — 终战 Boss 血条 HUD。
##
## authored UI 模板，外部只推送血量与状态；阶段名不直接展示。

@onready var _boss_fill: ColorRect = $Root/BossFrame/FillClip/Fill
@onready var _phase_two_tick: ColorRect = $Root/BossFrame/FillClip/PhaseTwoTick
@onready var _phase_three_tick: ColorRect = $Root/BossFrame/FillClip/PhaseThreeTick
@onready var _boss_label: Label = $Root/BossFrame/Name
@onready var _phase_label: Label = $Root/BossFrame/Phase
@onready var _shield_badge: Panel = $Root/BossFrame/ShieldBadge
@onready var _shield_label: Label = $Root/BossFrame/ShieldBadge/Label
@onready var _pierce_read: Label = $Root/BossFrame/PierceRead
@onready var _hit_flash: ColorRect = $Root/BossFrame/HitFlash
@onready var _predecessor_frame: Panel = $Root/PredecessorFrame
@onready var _predecessor_fill: ColorRect = $Root/PredecessorFrame/FillClip/Fill
@onready var _predecessor_label: Label = $Root/PredecessorFrame/Name

var _boss_full_width: float = 1.0
var _predecessor_full_width: float = 1.0
var _boss_tween: Tween
var _predecessor_tween: Tween


## 读取 authored 尺寸并隐藏前辈 AI 血条。
func _ready() -> void:
	_boss_full_width = maxf(_boss_fill.custom_minimum_size.x, _boss_fill.size.x)
	_predecessor_full_width = maxf(_predecessor_fill.custom_minimum_size.x, _predecessor_fill.size.x)
	_predecessor_frame.hide()
	_shield_badge.hide()
	_pierce_read.hide()
	_hit_flash.hide()
	_phase_label.text = ""
	_phase_label.hide()


## 更新 Boss 血量和名字。
func set_boss_health(current: int, max_value: int) -> void:
	_boss_label.text = "窗口核心"
	_tween_bar(_boss_fill, "_boss_tween", _boss_full_width, current, max_value)
	_pulse_hit_flash()


## 根据 Boss 阶段阈值定位 authored 分段线。
func set_thresholds(max_value: int, phase_two: int, phase_three: int) -> void:
	_position_threshold_tick(_phase_two_tick, max_value, phase_two)
	_position_threshold_tick(_phase_three_tick, max_value, phase_three)


## 保留阶段接口给 Stage3 使用，但不把“一/二/三阶段”明示到 HUD。
func set_phase(label: String) -> void:
	_phase_label.text = ""
	_phase_label.hide()


## 显示 Boss 护盾/弱点状态。
func set_shield_state(active: bool, label: String) -> void:
	_shield_label.text = label
	_shield_badge.visible = active


## 更新三阶段冲刺穿透次数读法。
func set_pierce_progress(current: int, max_value: int) -> void:
	if max_value <= 0:
		_pierce_read.hide()
		return
	_pierce_read.text = "穿透 %d/%d" % [clampi(current, 0, max_value), max_value]
	_pierce_read.visible = current > 0


## 显示并更新前辈 AI 血量。
func set_predecessor_health(current: int, max_value: int) -> void:
	_predecessor_frame.show()
	_predecessor_label.text = "前辈 AI"
	_tween_bar(_predecessor_fill, "_predecessor_tween", _predecessor_full_width, current, max_value)


## 隐藏前辈 AI 血条。
func hide_predecessor() -> void:
	_predecessor_frame.hide()


## 按目标比例缓动血条宽度。
func _tween_bar(fill: ColorRect, tween_property: String, full_width: float, current: int, max_value: int) -> void:
	var ratio := 0.0 if max_value <= 0 else clampf(float(current) / float(max_value), 0.0, 1.0)
	var target_w := full_width * ratio
	var active_tween: Tween = get(tween_property)
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	active_tween.tween_property(fill, "custom_minimum_size:x", target_w, 0.16)
	active_tween.parallel().tween_property(fill, "size:x", target_w, 0.16)
	set(tween_property, active_tween)


## 播放 authored HUD 命中闪光。
func _pulse_hit_flash() -> void:
	_hit_flash.show()
	_hit_flash.modulate.a = 0.52
	var tween := create_tween()
	tween.tween_property(_hit_flash, "modulate:a", 0.0, 0.18)
	tween.tween_callback(_hit_flash.hide)


## 把血量阈值换算成血条内 x 坐标。
func _position_threshold_tick(tick: ColorRect, max_value: int, threshold: int) -> void:
	if tick == null:
		return
	var ratio := 0.0 if max_value <= 0 else clampf(float(threshold) / float(max_value), 0.0, 1.0)
	var x := _boss_full_width * ratio
	tick.offset_left = x - 1.0
	tick.offset_right = x + 1.0
