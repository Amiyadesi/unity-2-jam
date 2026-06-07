extends Area2D
class_name CloseAITrainingTarget
## training_target.gd — authored combat tutorial target.
##
## The player hitboxes call take_player_hit() with an attack kind. Stage scripts
## listen to completed to advance tutorials without guessing input state.

signal completed(target: Area2D, attack_kind: StringName)

@export_enum("any", "forward", "side", "dash") var required_attack_kind: String = "any"
@export_range(1, 5, 1) var hits_required: int = 1
@export var starts_enabled: bool = false
@export var reward_energy: float = 0.0

var _hits_left: int = 1
var _enabled: bool = false
var _completed: bool = false
var _flash_tween: Tween
var _complete_tween: Tween

@onready var _visual: CanvasItem = $Visual
@onready var _core: CanvasItem = $Core
@onready var _prompt: CanvasItem = $Prompt
@onready var _shape: CollisionShape2D = $CollisionShape2D


## Initializes authored visuals and collision state.
func _ready() -> void:
	if not _require_authored_nodes():
		return
	add_to_group("training_target")
	_hits_left = hits_required
	set_enabled(starts_enabled)


## Validates required scene children so missing authored content is visible.
func _require_authored_nodes() -> bool:
	var ok := true
	if _visual == null:
		push_error("%s requires authored Visual." % name)
		ok = false
	if _core == null:
		push_error("%s requires authored Core." % name)
		ok = false
	if _prompt == null:
		push_error("%s requires authored Prompt." % name)
		ok = false
	if _shape == null:
		push_error("%s requires authored CollisionShape2D." % name)
		ok = false
	return ok


## Enables or disables this target for the current tutorial step.
func set_enabled(value: bool) -> void:
	_enabled = value and not _completed
	monitoring = _enabled
	if _shape != null:
		_shape.disabled = not _enabled
	if _visual != null:
		_visual.modulate.a = 1.0 if _enabled else 0.22
	if _core != null:
		_core.modulate.a = 0.85 if _enabled else 0.16
	if _prompt != null:
		_prompt.visible = _enabled


## Resets this target for tests or soft tutorial retries.
func reset_target() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	if _complete_tween != null:
		_complete_tween.kill()
	_completed = false
	_hits_left = hits_required
	modulate.a = 1.0
	set_enabled(starts_enabled)


## Reports whether this target has already accepted its required hit.
func is_completed() -> bool:
	return _completed


## Accepts typed player hits and reports whether this target consumed the hit.
func take_player_hit(damage: int, attack_kind: StringName, source: Node = null) -> bool:
	if _completed or not _enabled:
		return false
	if required_attack_kind != "any" and String(attack_kind) != required_attack_kind:
		_flash_reject()
		return false
	_hits_left -= maxi(damage, 1)
	if _hits_left <= 0:
		_complete(attack_kind, source)
	else:
		_flash_accept()
	return true


## Fallback for legacy damage callers; only any-targets accept it.
func take_hit(damage: int) -> bool:
	if required_attack_kind == "any":
		return take_player_hit(damage, &"any", null)
	return false


## Plays a small white pulse for a correct but non-final hit.
func _flash_accept() -> void:
	_restart_flash(Color(0.86, 0.92, 1.0, 1.0))


## Plays a muted red pulse when the wrong attack kind hits this target.
func _flash_reject() -> void:
	_restart_flash(Color(1.0, 0.28, 0.32, 1.0))


## Restarts the authored core flash tween.
func _restart_flash(color: Color) -> void:
	if _core == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	_core.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_core, "modulate", Color(0.62, 0.48, 1.0, 0.85), 0.16)


## Completes the target, rewards energy if requested, and fades out.
func _complete(attack_kind: StringName, source: Node) -> void:
	_completed = true
	_enabled = false
	monitoring = false
	if _shape != null:
		_shape.disabled = true
	if source != null and reward_energy > 0.0 and source.has_method("restore_energy"):
		source.restore_energy(reward_energy)
	completed.emit(self, attack_kind)
	if _prompt != null:
		_prompt.visible = false
	if _complete_tween != null:
		_complete_tween.kill()
	_complete_tween = create_tween()
	_complete_tween.tween_property(self, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
