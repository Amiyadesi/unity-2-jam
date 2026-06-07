extends Area2D
class_name EnergyPocket
## energy_pocket.gd — authored Stage2 air refill pocket.
##
## Players learn the dash loop by flying through visible refill pockets between
## authored dash targets. The scene owns visuals and collision; stage scripts
## only place instances.

@export var energy_amount: float = 44.0
@export var cooldown_seconds: float = 0.55

var _cooldown_left: float = 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: CanvasItem = $Visual
@onready var _pulse: CanvasItem = $Pulse


## Initializes authored overlap handling and verifies required children.
func _ready() -> void:
	if not _require_authored_nodes():
		monitoring = false
		return
	body_entered.connect(_on_body_entered)
	_set_ready_visual()


## Updates cooldown after a refill flash.
func _process(delta: float) -> void:
	if _cooldown_left <= 0.0:
		return
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left <= 0.0:
		_set_ready_visual()


## Validates authored collision and visual children.
func _require_authored_nodes() -> bool:
	var ok := true
	if _shape == null:
		push_error("%s requires authored CollisionShape2D." % name)
		ok = false
	if _visual == null:
		push_error("%s requires authored Visual." % name)
		ok = false
	if _pulse == null:
		push_error("%s requires authored Pulse." % name)
		ok = false
	return ok


## Applies a refill if the body is the player and the pocket is ready.
func _on_body_entered(body: Node) -> void:
	if _cooldown_left > 0.0:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("restore_energy"):
		body.restore_energy(energy_amount)
		_cooldown_left = cooldown_seconds
		_flash_used_visual()


## Restores the authored pocket to its readable idle state.
func _set_ready_visual() -> void:
	if _visual != null:
		_visual.modulate.a = 1.0
	if _pulse != null:
		_pulse.modulate.a = 0.72


## Briefly dims the authored pocket after a refill.
func _flash_used_visual() -> void:
	if _visual != null:
		_visual.modulate.a = 0.38
	if _pulse != null:
		_pulse.modulate.a = 0.24
