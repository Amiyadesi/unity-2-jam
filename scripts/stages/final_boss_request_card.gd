extends Area2D
class_name FinalBossRequestCard
## final_boss_request_card.gd — 终战信息流请求卡。
##
## 这是 authored 弹幕模板：Boss 只激活场景里预放的卡片，不运行时手搓节点。
## 善意请求触碰后给玩家能量；恶意请求触碰后扣能量并记一次失误。

signal resolved(was_good: bool, body: Node)
signal hurt_player(body: Node)

@export var good_energy_reward: float = 18.0
@export var bad_energy_damage: float = 16.0
@export var bad_knockback: float = 360.0
@export var lifetime: float = 5.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $Visual
@onready var _label: Label = $Label
@onready var _good_swatch: ColorRect = $Palette/Good
@onready var _bad_swatch: ColorRect = $Palette/Bad
@onready var _good_halo: CanvasItem = $KindRead/GoodHalo
@onready var _bad_hazard: CanvasItem = $KindRead/BadHazard
@onready var _travel_trail: Node2D = $TravelTrail

var _active: bool = false
var _was_good: bool = true
var _velocity: Vector2 = Vector2.ZERO
var _life_left: float = 0.0


## 初始化碰撞回调，并保持卡片池默认休眠。
func _ready() -> void:
	if not _has_authored_kind_reads():
		push_error("FinalBossRequestCard requires authored KindRead good/bad cues.")
	body_entered.connect(_on_body_entered)
	deactivate()


## 激活一张请求卡，从 authored Marker 位置飞向目标方向。
func activate(start_position: Vector2, velocity: Vector2, was_good: bool) -> void:
	global_position = start_position
	_velocity = velocity
	_was_good = was_good
	_life_left = lifetime
	_active = true
	_apply_kind_style()
	show()
	monitoring = true
	_shape.disabled = false
	set_physics_process(true)


## 关闭请求卡并放回池里。
func deactivate() -> void:
	_active = false
	hide()
	monitoring = false
	if _shape != null:
		_shape.disabled = true
	set_physics_process(false)


## 推进飞行与寿命，到期自动回收。
func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position += _velocity * delta
	_life_left -= delta
	if _life_left <= 0.0:
		deactivate()


## 应用善恶请求的 authored 色板和文字。
func _apply_kind_style() -> void:
	_visual.color = _good_swatch.color if _was_good else _bad_swatch.color
	_label.text = "回应" if _was_good else "避开"
	_good_halo.visible = _was_good
	_bad_hazard.visible = not _was_good
	if _velocity.length() > 0.01 and _travel_trail != null:
		_travel_trail.rotation = _velocity.angle()


## 确认善恶请求读法来自 authored 线条，而不是只靠颜色和文字。
func _has_authored_kind_reads() -> bool:
	for node_path in [
		"KindRead/GoodHalo/PulseA",
		"KindRead/GoodHalo/CheckMark",
		"KindRead/BadHazard/SlashA",
		"KindRead/BadHazard/SlashB",
		"TravelTrail/TrailA",
		"TravelTrail/TrailB",
	]:
		var line := get_node_or_null(node_path) as Line2D
		if line == null or line.points.size() < 2:
			return false
	return true


## 玩家碰到请求卡时，按善恶执行不同反馈。
func _on_body_entered(body: Node) -> void:
	if not _active or not body.is_in_group("player"):
		return
	if _was_good:
		if body.has_method("restore_energy"):
			body.restore_energy(good_energy_reward)
		resolved.emit(true, body)
	else:
		if body.has_method("drain_energy"):
			body.drain_energy(bad_energy_damage)
		if body.has_method("apply_knockback"):
			var body_2d := body as Node2D
			if body_2d != null:
				var dir: Vector2 = (body_2d.global_position - global_position).normalized()
				body.apply_knockback(dir * bad_knockback)
		hurt_player.emit(body)
		resolved.emit(false, body)
	deactivate()
