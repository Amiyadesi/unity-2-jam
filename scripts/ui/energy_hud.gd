extends CanvasLayer
## energy_hud.gd — 能量条 HUD（固定模板）
##
## 监听玩家的 energy_changed / morph_changed 信号，画一条紫色能量条。
## 觉醒态时条变亮/描边强调；能量低时变红警示。
## 由有战斗的关卡 authored 为子节点（第一关教学可不挂）。
##
## 约定：场景含 BarFrame / FillClip / Fill / Label / Palette。脚本只控制状态。

@export var player_path: NodePath = ^"../Player"

@onready var _fill_clip: Control = $Root/BarFrame/FillClip
@onready var _fill: ColorRect = $Root/BarFrame/FillClip/Fill
@onready var _frame: Panel = $Root/BarFrame
@onready var _label: Label = $Root/BarFrame/Label
@onready var _normal_swatch: ColorRect = $Root/Palette/Normal
@onready var _low_swatch: ColorRect = $Root/Palette/Low
@onready var _morph_swatch: ColorRect = $Root/Palette/Morphed

const LOW_RATIO := 0.25

var _player: CloseAIPlayer
var _fill_tween: Tween
var _normal_color: Color
var _low_color: Color
var _morph_color: Color
var _full_width: float = 1.0


func _ready() -> void:
	_cache_authored_style()
	_find_and_bind_player()


## 读取场景 authored 的尺寸和色板。
func _cache_authored_style() -> void:
	_normal_color = _normal_swatch.color
	_low_color = _low_swatch.color
	_morph_color = _morph_swatch.color
	_full_width = maxf(maxf(_fill.custom_minimum_size.x, _fill.size.x), _fill_clip.size.x)


## 找到场景 authored 的玩家并连接信号；找不到则显式报错。
func _find_and_bind_player() -> void:
	_player = get_node_or_null(player_path) as CloseAIPlayer
	if _player == null:
		push_error("EnergyHud requires authored player_path pointing to CloseAIPlayer: %s" % player_path)
		return
	if _player.has_signal("energy_changed"):
		_player.energy_changed.connect(_on_energy_changed)
	if _player.has_signal("morph_changed"):
		_player.morph_changed.connect(_on_morph_changed)
	# 用当前值初始化
	_on_energy_changed(_player.energy, _player.max_energy)
	_on_morph_changed(_player.morphed)


## 根据当前能量缩放填充条并更新数字。
func _on_energy_changed(current: float, max_value: float) -> void:
	var ratio := 0.0 if max_value <= 0.0 else clampf(current / max_value, 0.0, 1.0)
	var target_w := _full_width * ratio
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	_fill_tween = create_tween()
	_fill_tween.tween_property(_fill, "custom_minimum_size:x", target_w, 0.12)
	_fill_tween.parallel().tween_property(_fill, "size:x", target_w, 0.12)
	# 低能量警示色（觉醒态不覆盖其专属色）
	if not (_player != null and _player.morphed):
		_fill.color = _low_color if ratio <= LOW_RATIO else _normal_color
	if _label != null:
		_label.text = "%d" % roundi(current)


## 根据觉醒形态切换填充颜色和框体强调。
func _on_morph_changed(is_morphed: bool) -> void:
	_fill.color = _morph_color if is_morphed else _normal_color
	# 觉醒态描边强调
	if _frame != null:
		_frame.modulate = Color(1.1, 1.1, 1.2, 1.0) if is_morphed else Color.WHITE
