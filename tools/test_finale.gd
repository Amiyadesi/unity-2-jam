extends SceneTree
## test_finale.gd — 终战 Boss 纵切 headless 自测。
## 运行：godot --headless --path . --script res://tools/test_finale.gd

var _failures: int = 0
var _checks: int = 0
var _phase_ids: Array[int] = []
var _phase_labels: Array[String] = []
var _boss_health: Array[int] = []
var _predecessor_done: bool = false
var _request_started_events: Array[StringName] = []
var _request_finished_events: Array[StringName] = []
var _dash_pierce_events: int = 0
var _dash_window_events: Array[bool] = []
var _dash_warning_events: Array[bool] = []
var _dash_aim_events: Array[bool] = []
var _dash_aim_origins: Array[Vector2] = []
var _dash_aim_targets: Array[Vector2] = []
var _dash_reject_events: int = 0
var _dash_rhythm_events: Array[StringName] = []
var _dash_rhythm_ratios: Array[float] = []
var _phase_three_pressure_names: Array[StringName] = []
var _phase_three_pressure_states: Array[StringName] = []
var _phase_three_pressure_ratios: Array[float] = []
var _boss_defeated_count: int = 0


## 延迟启动，等 autoload 与全局类可用。
func _init() -> void:
	call_deferred("_run")


## 记录检查结果。
func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  [PASS] " if cond else "  [FAIL] ") + label)
	if not cond:
		_failures += 1


## 验证终战核心节点与阶段逻辑。
func _run() -> void:
	print("=== CloseAI finale test ===")
	await process_frame
	await process_frame
	var gf: Node = root.get_node_or_null("GameFlow")
	if gf != null:
		gf.reset_progress()

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var boss_scene: PackedScene = load("res://scenes/final_boss.tscn")
	var gate_scene: PackedScene = load("res://scenes/internet_gate.tscn")
	var hud_scene: PackedScene = load("res://scenes/ui/boss_hud.tscn")
	_check("player scene loads", player_scene != null)
	_check("final boss scene loads", boss_scene != null)
	_check("internet gate scene loads", gate_scene != null)
	_check("boss hud scene loads", hud_scene != null)
	if player_scene == null or boss_scene == null or gate_scene == null:
		_finish()
		return

	var root_node := Node2D.new()
	root.add_child(root_node)
	var player: Node = player_scene.instantiate()
	var boss: Node = boss_scene.instantiate()
	var gate: Node = gate_scene.instantiate()
	root_node.add_child(player)
	root_node.add_child(boss)
	root_node.add_child(gate)
	await process_frame
	await process_frame

	_check("boss has activate", boss.has_method("activate"))
	_check("boss has take_hit", boss.has_method("take_hit"))
	_check("boss has typed player hit", boss.has_method("take_player_hit"))
	_check("boss has dash pierce signal", boss.has_signal("dash_pierce_confirmed"))
	_check("boss has dash window signal", boss.has_signal("dash_window_changed"))
	_check("boss has dash warning signal", boss.has_signal("dash_window_warning_changed"))
	_check("boss has dash aim signal", boss.has_signal("dash_window_aim_changed"))
	_check("boss has dash reject signal", boss.has_signal("dash_window_rejected"))
	_check("boss has dash rhythm signal", boss.has_signal("dash_window_rhythm_changed"))
	_check("boss has phase three pressure signal", boss.has_signal("phase_three_pressure_changed"))
	_check("boss authored impact burst", boss.get_node_or_null("CombatVFX/ImpactBurst") is Node2D)
	_check("boss authored shield crack", boss.get_node_or_null("CombatVFX/ShieldCrack") is Node2D)
	_check("boss authored phase burst", boss.get_node_or_null("CombatVFX/PhaseBurst") is GPUParticles2D)
	_check("boss authored dash window ring", boss.get_node_or_null("CombatVFX/DashWindowRing") is Node2D)
	_check("boss authored core open cue", boss.get_node_or_null("CombatVFX/CoreOpenCue") is Node2D)
	_check("boss authored closed window cue", boss.get_node_or_null("CombatVFX/ClosedWindowCue") is Node2D)
	_check("boss authored dash warning cue", boss.get_node_or_null("CombatVFX/DashWindowWarningCue") is Node2D)
	_check("boss authored dash reject cue", boss.get_node_or_null("CombatVFX/DashRejectCue") is Node2D)
	_check("boss authored dash pierce confirm", boss.get_node_or_null("CombatVFX/DashPierceConfirm") is Node2D)
	_check("boss authored predecessor spawn", boss.get_node_or_null("PredecessorSpawn") is Marker2D)
	_check("boss authored phase pressure", boss.has_method("_has_authored_phase_pressure") and boss._has_authored_phase_pressure())
	_check("boss authored request telegraphs", boss.has_method("_has_authored_request_telegraphs") and boss._has_authored_request_telegraphs())
	_check("boss authored phase three reads", boss.has_method("_has_authored_phase_three_reads") and boss._has_authored_phase_three_reads())
	_check("boss authored phase three pressure", boss.has_method("_has_authored_phase_three_pressure") and boss._has_authored_phase_three_pressure())
	_check_boss_texture_keyed("res://assets/generated/props/boss_core_body.png", true)
	_check_boss_texture_keyed("res://assets/generated/props/boss_core_shield.png", false)
	await _check_request_card_kind_reads(boss)
	await _check_request_card_energy_feedback(boss.get_node_or_null("RequestPool/RequestCard1"), player)
	_check("gate starts hidden", gate is CanvasItem and not (gate as CanvasItem).visible)
	_check("gate has activate", gate.has_method("activate"))
	if hud_scene != null:
		await _check_boss_hud_authored(hud_scene)

	boss.connect("phase_changed", Callable(self, "_on_phase_changed"))
	boss.connect("health_changed", Callable(self, "_on_boss_health_changed"))
	boss.connect("predecessor_defeated", Callable(self, "_on_predecessor_defeated"))
	boss.connect("request_telegraph_started", Callable(self, "_on_request_telegraph_started"))
	boss.connect("request_telegraph_finished", Callable(self, "_on_request_telegraph_finished"))
	boss.connect("dash_pierce_confirmed", Callable(self, "_on_dash_pierce_confirmed"))
	boss.connect("dash_window_changed", Callable(self, "_on_dash_window_changed"))
	boss.connect("dash_window_warning_changed", Callable(self, "_on_dash_window_warning_changed"))
	boss.connect("dash_window_aim_changed", Callable(self, "_on_dash_window_aim_changed"))
	boss.connect("dash_window_rejected", Callable(self, "_on_dash_window_rejected"))
	boss.connect("dash_window_rhythm_changed", Callable(self, "_on_dash_window_rhythm_changed"))
	boss.connect("phase_three_pressure_changed", Callable(self, "_on_phase_three_pressure_changed"))
	boss.connect("defeated", Callable(self, "_on_boss_defeated"))
	boss.activate(player)
	await process_frame
	_check("boss starts first combat state", _phase_ids.size() >= 1 and _phase_ids[0] == 1)
	_check("boss phase labels avoid explicit stage names", _phase_labels.all(func(label: String) -> bool: return _label_hides_stage_number(label)))
	await _check_phase_pressure_flow(boss, player)
	boss.request_good_pattern = PackedByteArray([0, 1])
	boss._spawn_index = 1
	_check("boss request pattern can author bad request", boss._next_request_is_good() == false)
	boss._spawn_index = 2
	_check("boss request pattern can author good request", boss._next_request_is_good() == true)
	boss.request_good_pattern = PackedByteArray([0, 1, 1])

	for _i in range(4):
		boss.take_hit(1)
		await process_frame
	_check("boss enters request state at threshold", _phase_ids.has(2))
	var phase_burst := boss.get_node_or_null("CombatVFX/PhaseBurst") as GPUParticles2D
	_check("boss phase burst emits on phase change", phase_burst != null and phase_burst.emitting)
	var hp_after_phase_two: int = _boss_health.back()
	var predecessor_spawn := boss.get_node_or_null("PredecessorSpawn") as Marker2D
	var predecessor := boss.get_node_or_null("PredecessorAI") as Node2D
	_check("predecessor uses authored spawn marker", predecessor != null and predecessor_spawn != null and predecessor.global_position.is_equal_approx(predecessor_spawn.global_position))
	await _check_predecessor_ai_readability(predecessor)
	await _check_player_hitbox_can_damage_predecessor(player, predecessor)
	await _check_request_telegraph_flow(boss)
	boss.take_hit(1)
	await process_frame
	_check("predecessor blocks boss damage", _boss_health.back() == hp_after_phase_two)
	var shield_crack := boss.get_node_or_null("CombatVFX/ShieldCrack") as CanvasItem
	_check("boss shield crack shows on blocked hit", shield_crack != null and shield_crack.visible)

	_check("predecessor exists", predecessor != null and predecessor.has_method("take_hit"))
	if predecessor != null:
		for _i in range(predecessor.max_hp + 1):
			if predecessor._dead:
				break
			predecessor.take_hit(1)
			await process_frame
	_check("predecessor defeated signal emitted", _predecessor_done)
	boss.take_hit(1)
	await process_frame
	_check("boss damage resumes after predecessor", _boss_health.back() < hp_after_phase_two)
	var impact_burst := boss.get_node_or_null("CombatVFX/ImpactBurst") as CanvasItem
	_check("boss impact burst shows on core hit", impact_burst != null and impact_burst.visible)
	for _i in range(4):
		boss.take_hit(1)
		await process_frame
	_check("boss enters dash-window state", _phase_ids.has(3))
	_check("all boss phase labels avoid explicit stage names", _phase_labels.all(func(label: String) -> bool: return _label_hides_stage_number(label)))
	var dash_window_ring := boss.get_node_or_null("CombatVFX/DashWindowRing") as CanvasItem
	var core_open_cue := boss.get_node_or_null("CombatVFX/CoreOpenCue") as CanvasItem
	var closed_window_cue := boss.get_node_or_null("CombatVFX/ClosedWindowCue") as CanvasItem
	var dash_warning_cue := boss.get_node_or_null("CombatVFX/DashWindowWarningCue") as CanvasItem
	var dash_reject_cue := boss.get_node_or_null("CombatVFX/DashRejectCue") as CanvasItem
	var dash_pierce_confirm := boss.get_node_or_null("CombatVFX/DashPierceConfirm") as CanvasItem
	_check("phase three closed hides dash cue", dash_window_ring != null and core_open_cue != null and dash_pierce_confirm != null and not dash_window_ring.visible and not core_open_cue.visible and not dash_pierce_confirm.visible)
	_check("phase three closed shows recharge cue", closed_window_cue != null and closed_window_cue.visible and closed_window_cue.modulate.a < 1.0)
	_check("phase three closed starts without warning cue", dash_warning_cue != null and not dash_warning_cue.visible)
	_check("phase three close emits dash window closed", _dash_window_events.size() >= 1 and _dash_window_events.back() == false)
	_check("phase three close emits rhythm closed", _dash_rhythm_events.size() >= 1 and _dash_rhythm_events.back() == &"closed")
	var closed_scale_before: Vector2 = closed_window_cue.scale if closed_window_cue != null else Vector2.ONE
	boss._animate_closed_window_cue(0.2)
	await process_frame
	_check("phase three closed cue breathes while waiting", closed_window_cue != null and closed_window_cue.visible and closed_window_cue.scale != closed_scale_before)
	await _check_phase_three_pressure_flow(boss, player)
	var hp_after_phase_three: int = _boss_health.back()
	_check("phase three requires three pierces", hp_after_phase_three == 3)
	boss.take_hit(1)
	await process_frame
	_check("phase three rejects legacy take_hit", _boss_health.back() == hp_after_phase_three)
	boss.take_player_hit(1, &"forward", player)
	await process_frame
	_check("phase three rejects non-dash boss hits", _boss_health.back() == hp_after_phase_three)
	boss.take_player_hit(1, &"dash", player)
	await process_frame
	_check("phase three rejects dash while core is closed", _boss_health.back() == hp_after_phase_three)
	_check("phase three rejected dash shows reject cue", dash_reject_cue != null and dash_reject_cue.visible)
	_check("phase three rejected dash emits reject signal", _dash_reject_events == 1)
	_check("phase three rejected dash does not show pierce confirm", dash_pierce_confirm != null and not dash_pierce_confirm.visible)
	_check("phase three rejected dash does not emit pierce signal", _dash_pierce_events == 0)
	player.morphed = true
	player._dash_attack_timer = player.dash_hitbox_duration
	player.velocity = Vector2(900.0, 0.0)
	var closed_body_velocity: Vector2 = player.velocity
	boss._on_body_entered(player)
	_check("phase three body dash rejected while closed", _boss_health.back() == hp_after_phase_three)
	_check("phase three closed body dash does not knock back player", player.velocity == closed_body_velocity)
	_check("phase three closed body dash emits reject signal", _dash_reject_events == 2)
	player._disable_all_hitboxes()
	boss._on_request_resolved(true)
	await process_frame
	_check("phase three good requests do not damage boss", _boss_health.back() == hp_after_phase_three)
	boss._set_dash_window(false)
	player.global_position = boss.global_position + Vector2(180.0, -74.0)
	var locked_dash_target: Vector2 = player.global_position
	boss._dash_window_timer = boss.phase_three_warning_seconds + 0.02
	boss._update_dash_window(0.03)
	await process_frame
	_check("phase three warns before dash window opens", dash_warning_cue != null and dash_warning_cue.visible and dash_warning_cue.modulate.a > 0.42 and dash_warning_cue.scale != Vector2.ONE)
	_check("phase three warning hides recharge cue", closed_window_cue != null and not closed_window_cue.visible)
	_check("phase three warning emits active", _dash_warning_events.size() >= 1 and _dash_warning_events.back() == true)
	_check("phase three warning emits rhythm warning", _dash_rhythm_events.size() >= 1 and _dash_rhythm_events.back() == &"warning")
	_check("phase three warning locks dash aim at player", _dash_aim_events.size() >= 1 and _dash_aim_events.back() == true and _dash_aim_targets.back().is_equal_approx(locked_dash_target))
	player.global_position = boss.global_position + Vector2(-220.0, 96.0)
	boss._update_dash_window(0.01)
	_check("phase three warning keeps locked dash target", _dash_aim_targets.size() >= 1 and _dash_aim_targets.back().is_equal_approx(locked_dash_target))
	boss._update_dash_window(boss.phase_three_warning_seconds + 0.01)
	await process_frame
	_check("phase three opens readable dash window", boss._dash_window_open == true)
	_check("phase three open shows dash cue", dash_window_ring != null and core_open_cue != null and dash_window_ring.visible and core_open_cue.visible)
	_check("phase three open hides recharge cue", closed_window_cue != null and not closed_window_cue.visible)
	_check("phase three open hides warning cue", dash_warning_cue != null and not dash_warning_cue.visible)
	_check("phase three open emits warning inactive", _dash_warning_events.size() >= 2 and _dash_warning_events.back() == false)
	_check("phase three open emits dash window open", _dash_window_events.size() >= 2 and _dash_window_events.back() == true)
	_check("phase three open emits rhythm open", _dash_rhythm_has_event(&"open", 0.99))
	_check("phase three open keeps locked dash aim", _dash_aim_events.size() >= 1 and _dash_aim_events.back() == true and _dash_aim_targets.back().is_equal_approx(locked_dash_target))
	var ring_rotation_before: float = dash_window_ring.rotation if dash_window_ring != null else 0.0
	var ring_scale_before: Vector2 = dash_window_ring.scale if dash_window_ring != null else Vector2.ONE
	boss._animate_dash_window_cue(0.1)
	await process_frame
	_check("phase three dash cue pulses while open", dash_window_ring != null and dash_window_ring.rotation != ring_rotation_before and dash_window_ring.scale != ring_scale_before)
	player._camera_dash_timer = player.camera_dash_hold_time
	player.velocity = Vector2(900.0, 0.0)
	var camera_tail_velocity: Vector2 = player.velocity
	boss._on_body_entered(player)
	_check("phase three open rejects camera-tail body contact", _boss_health.back() == hp_after_phase_three and player.velocity == camera_tail_velocity)
	player._dash_attack_timer = player.dash_hitbox_duration
	player.velocity = Vector2(900.0, 0.0)
	var open_body_velocity: Vector2 = player.velocity
	boss._on_body_entered(player)
	_check("phase three accepts body dash inside open window", _boss_health.back() < hp_after_phase_three)
	_check("phase three accepted body dash knocks player back", player.velocity != open_body_velocity)
	_check("phase three accepted dash shows pierce confirm", dash_pierce_confirm != null and dash_pierce_confirm.visible)
	_check("phase three accepted dash emits pierce signal", _dash_pierce_events == 1)
	_check("phase three first pierce does not defeat boss", _boss_defeated_count == 0 and _boss_health.back() == 2)
	boss._set_dash_window(true)
	boss.take_player_hit(1, &"dash", player)
	await process_frame
	_check("phase three second pierce does not defeat boss", _dash_pierce_events == 2 and _boss_defeated_count == 0 and _boss_health.back() == 1)
	boss._set_dash_window(true)
	boss.take_player_hit(1, &"dash", player)
	await process_frame
	_check("phase three third pierce starts defeat", _dash_pierce_events == 3 and boss._defeated and _boss_health.back() == 0)
	_check("phase three defeat clears dash aim", _dash_aim_events.size() >= 2 and _dash_aim_events.back() == false)
	await create_timer(0.9).timeout
	for _i in range(60):
		await process_frame
		if _boss_defeated_count > 0:
			break
	_check("phase three third pierce emits defeated after collapse", _boss_defeated_count == 1)
	boss._set_dash_window(false)
	await process_frame
	_check("phase three closed resets dash cue", dash_window_ring != null and not dash_window_ring.visible and dash_window_ring.scale == Vector2.ONE and is_equal_approx(dash_window_ring.rotation, 0.0))
	_check("phase three defeated stays clear of recharge cue", closed_window_cue != null and not closed_window_cue.visible and closed_window_cue.scale == Vector2.ONE and is_equal_approx(closed_window_cue.rotation, 0.0))
	_check("phase three closed resets warning cue", dash_warning_cue != null and not dash_warning_cue.visible and dash_warning_cue.scale == Vector2.ONE and is_equal_approx(dash_warning_cue.rotation, 0.0))
	_check("phase three manual close emits dash window closed", _dash_window_events.size() >= 3 and _dash_window_events.back() == false)
	if dash_warning_cue != null:
		dash_warning_cue.show()
	boss._hide_combat_vfx()
	_check("combat vfx reset hides dash warning", dash_warning_cue != null and not dash_warning_cue.visible)

	gate.activate()
	await process_frame
	_check("gate activates visible", gate is CanvasItem and (gate as CanvasItem).visible)

	root_node.queue_free()
	if gf != null:
		gf.reset_progress()
	_finish()


## 记录 Boss 阶段。
func _on_phase_changed(phase: int, label: String) -> void:
	_phase_ids.append(phase)
	_phase_labels.append(label)


## 确认 Boss 状态文本不把“一/二/三阶段”直接摆给玩家。
func _label_hides_stage_number(label: String) -> bool:
	for token in ["一阶段", "二阶段", "三阶段", "阶段"]:
		if label.contains(token):
			return false
	return true


## 记录 Boss 血量。
func _on_boss_health_changed(current: int, _max_value: int) -> void:
	_boss_health.append(current)


## 记录前辈 AI 倒下。
func _on_predecessor_defeated() -> void:
	_predecessor_done = true


## 确认请求卡善恶不只靠颜色，坏请求文案不诱导玩家去撞。
func _check_request_card_kind_reads(boss: Node) -> void:
	var card := boss.get_node_or_null("RequestPool/RequestCard1")
	if card == null:
		_check("request card kind read prerequisites", false)
		return
	_check("request card authored kind reads", card.has_method("_has_authored_kind_reads") and card._has_authored_kind_reads())
	card.activate(Vector2.ZERO, Vector2.RIGHT * 100.0, true)
	await process_frame
	var good_halo := card.get_node_or_null("KindRead/GoodHalo") as CanvasItem
	var bad_hazard := card.get_node_or_null("KindRead/BadHazard") as CanvasItem
	var good_sprite := card.get_node_or_null("Visual/GoodCard") as Sprite2D
	var bad_sprite := card.get_node_or_null("Visual/BadCard") as Sprite2D
	_check("request card has no crude text label", card.get_node_or_null("Label") == null)
	_check("good request shows check read", good_halo != null and good_halo.visible and bad_hazard != null and not bad_hazard.visible and good_sprite != null and good_sprite.visible and bad_sprite != null and not bad_sprite.visible)
	card.deactivate()
	card.activate(Vector2.ZERO, Vector2.RIGHT * 100.0, false)
	await process_frame
	_check("bad request shows hazard read", good_halo != null and not good_halo.visible and bad_hazard != null and bad_hazard.visible and good_sprite != null and not good_sprite.visible and bad_sprite != null and bad_sprite.visible)
	card.deactivate()


## 确认请求卡碰撞会真实改变玩家能量，而不只发 Boss 信号。
func _check_request_card_energy_feedback(card: Node, player: Node) -> void:
	if card == null or player == null:
		_check("request card energy prerequisites", false)
		return
	player.energy = 20.0
	card.activate(Vector2.ZERO, Vector2.RIGHT * 100.0, true)
	card._on_body_entered(player)
	await process_frame
	await physics_frame
	_check("good request restores player energy", player.energy > 20.0)
	_check("request card collision disables deferred after good hit", "monitoring" in card and not card.monitoring)
	player.energy = 70.0
	card.activate(Vector2.ZERO, Vector2.RIGHT * 100.0, false)
	card._on_body_entered(player)
	await process_frame
	await physics_frame
	_check("bad request drains player energy", player.energy < 70.0)
	_check("request card collision disables deferred after bad hit", "monitoring" in card and not card.monitoring)


## 确认前辈 AI 用主角同图变黑，并有可读冲刺状态。
func _check_predecessor_ai_readability(predecessor: Node) -> void:
	if predecessor == null:
		_check("predecessor readability prerequisites", false)
		return
	var pred_sprite := predecessor.get_node_or_null("Body/Sprite2D") as Sprite2D
	_check("predecessor uses player spritesheet", pred_sprite != null and pred_sprite.texture != null and pred_sprite.hframes == 17 and pred_sprite.vframes == 16)
	_check("predecessor sprite is black recolor", pred_sprite != null and pred_sprite.modulate.r < 0.08 and pred_sprite.modulate.g < 0.08 and pred_sprite.modulate.b < 0.1)
	_check("predecessor accepts player typed hit", predecessor.has_method("take_player_hit") and predecessor.take_player_hit(1, &"dash", null))
	_check("predecessor exposes dash state", "_dash_state" in predecessor and predecessor._dash_state == &"chase")
	predecessor._spawn_hold_left = 0.0
	predecessor._dash_timer = 0.0
	predecessor._physics_process(0.016)
	_check("predecessor dash has windup", predecessor._dash_state == &"windup")
	predecessor._physics_process(predecessor.dash_windup_seconds + 0.01)
	_check("predecessor dash becomes active", predecessor._dash_state == &"active")


## 确认玩家 authored dash hitbox 真的能打到前辈 AI。
func _check_player_hitbox_can_damage_predecessor(player: Node, predecessor: Node) -> void:
	if player == null or predecessor == null:
		_check("player hitbox predecessor prerequisites", false)
		return
	var forward_hitbox := player.get_node_or_null("Body/CombatHitboxes/ForwardHitbox") as Area2D
	_check("player hitbox predecessor forward hitbox exists", forward_hitbox != null)
	if forward_hitbox == null:
		return
	var old_player_position: Vector2 = player.global_position
	var old_player_velocity: Vector2 = player.velocity
	var old_predecessor_process: bool = predecessor.is_physics_processing()
	predecessor.set_physics_process(false)
	player.global_position = Vector2.ZERO
	player.morphed = true
	player.velocity = Vector2.RIGHT * player.dash_speed
	player._camera_dash_dir = Vector2.RIGHT
	player._action_playing = false
	player.frozen = false
	player._dash_attack_timer = player.dash_hitbox_duration
	var hitboxes: Array[Area2D] = [forward_hitbox]
	player._hit_targets.clear()
	var hp_before: int = predecessor._hp
	predecessor.global_position = forward_hitbox.global_position + Vector2(84.0, 0.0)
	await physics_frame
	player._start_hitbox_window(hitboxes, player.dash_hitbox_duration)
	player._dash_attack_timer = player.dash_hitbox_duration
	for _i in range(12):
		player._physics_process(0.016)
		await physics_frame
		if predecessor._hp < hp_before:
			break
	_check("player dash hitbox damages predecessor", predecessor._hp < hp_before)
	player._disable_all_hitboxes()
	player.global_position = old_player_position
	player.velocity = old_player_velocity
	predecessor.set_physics_process(old_predecessor_process)

## 记录 Boss 请求预告启动。
func _on_request_telegraph_started(spawn_name: StringName, _good: bool) -> void:
	_request_started_events.append(spawn_name)


## 记录 Boss 请求预告收束。
func _on_request_telegraph_finished(spawn_name: StringName, _good: bool) -> void:
	_request_finished_events.append(spawn_name)


## 记录三阶段冲刺穿透命中确认。
func _on_dash_pierce_confirmed(_source: Node) -> void:
	_dash_pierce_events += 1


## 记录三阶段冲刺窗口开合。
func _on_dash_window_changed(open: bool) -> void:
	_dash_window_events.append(open)


## 记录三阶段冲刺窗口预告开合。
func _on_dash_window_warning_changed(active: bool) -> void:
	_dash_warning_events.append(active)


## 记录三阶段冲刺路线瞄准锁定。
func _on_dash_window_aim_changed(active: bool, origin: Vector2, target: Vector2) -> void:
	_dash_aim_events.append(active)
	_dash_aim_origins.append(origin)
	_dash_aim_targets.append(target)


## 记录三阶段冲刺撞到关闭窗口。
func _on_dash_window_rejected(_source: Node) -> void:
	_dash_reject_events += 1


## 记录三阶段冲刺窗口节奏拍点。
func _on_dash_window_rhythm_changed(beat: StringName, ratio: float) -> void:
	_dash_rhythm_events.append(beat)
	_dash_rhythm_ratios.append(ratio)


## 记录三阶段闭窗扫压读法同步事件。
func _on_phase_three_pressure_changed(sweep_name: StringName, state: StringName, ratio: float) -> void:
	_phase_three_pressure_names.append(sweep_name)
	_phase_three_pressure_states.append(state)
	_phase_three_pressure_ratios.append(ratio)


## 确认三阶段节奏事件出现过指定拍点。
func _dash_rhythm_has_event(beat: StringName, min_ratio: float) -> bool:
	for index: int in range(_dash_rhythm_events.size()):
		if _dash_rhythm_events[index] == beat and _dash_rhythm_ratios[index] >= min_ratio:
			return true
	return false


## 确认三阶段闭窗扫压读法事件出现过指定扫线和状态。
func _phase_three_pressure_has_event(sweep_name: StringName, state: StringName, min_ratio: float) -> bool:
	for index: int in range(_phase_three_pressure_names.size()):
		if _phase_three_pressure_names[index] == sweep_name and _phase_three_pressure_states[index] == state and _phase_three_pressure_ratios[index] >= min_ratio:
			return true
	return false


## 记录 Boss 被三次穿透击败。
func _on_boss_defeated() -> void:
	_boss_defeated_count += 1


## 确认 Boss 生图素材已抠掉深色底，避免终战出现黑色方块背景。
func _check_boss_texture_keyed(path: String, requires_opaque_center: bool) -> void:
	var image := Image.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	var loaded := image.load_png_from_buffer(bytes)
	_check("boss texture loads: " + path, loaded == OK)
	if loaded != OK:
		return
	var edge_alpha: float = maxf(
		maxf(image.get_pixel(0, 0).a, image.get_pixel(image.get_width() - 1, 0).a),
		maxf(image.get_pixel(0, image.get_height() - 1).a, image.get_pixel(image.get_width() - 1, image.get_height() - 1).a)
	)
	_check("boss texture transparent keyed edge: " + path, edge_alpha < 0.01)
	if requires_opaque_center:
		var center_alpha := image.get_pixel(image.get_width() / 2, image.get_height() / 2).a
		_check("boss texture keeps opaque core: " + path, center_alpha > 0.8)


## 确认 Boss 请求先亮 authored 预告，再从池中发射卡片。
func _check_request_telegraph_flow(boss: Node) -> void:
	var spawn := boss.get_node_or_null("RequestSpawns/Top") as Marker2D
	var telegraph := boss.get_node_or_null("RequestSpawns/Top/Telegraph") as CanvasItem
	var good_cue := boss.get_node_or_null("RequestSpawns/Top/Telegraph/GoodCue") as CanvasItem
	var bad_cue := boss.get_node_or_null("RequestSpawns/Top/Telegraph/BadCue") as CanvasItem
	var card := boss.get_node_or_null("RequestPool/RequestCard1") as CanvasItem
	if spawn == null or telegraph == null or good_cue == null or bad_cue == null or card == null:
		_check("boss request telegraph flow prerequisites", false)
		return
	boss.request_good_pattern = PackedByteArray([1])
	boss._request_timer = 0.0
	boss._spawn_index = 0
	boss._update_requests(0.01)
	await process_frame
	_check("boss request telegraph shows before card", telegraph.visible and good_cue.visible and not bad_cue.visible and not card.visible and boss._pending_request_card == card)
	_check("boss request telegraph emits start", _request_started_events.has(&"Top"))
	boss._update_requests(boss.request_telegraph_seconds + 0.01)
	_check("boss request fires at spawn after telegraph", not telegraph.visible and card.visible and card.global_position.is_equal_approx(spawn.global_position))
	_check("boss request telegraph emits finish", _request_finished_events.has(&"Top"))
	var card_velocity := card.get("_velocity") as Vector2
	_check("boss request leaves spawn with velocity", card.visible and card_velocity.length() > 0.1)
	card.call("_physics_process", 0.1)
	_check("boss request flies after simulated physics", card.visible and card.global_position.distance_to(spawn.global_position) > 0.1)
	card.hide()
	if card.has_method("deactivate"):
		card.deactivate()


## 确认一阶段 authored 扫线先预告无伤，再短暂开启碰撞惩罚玩家。
func _check_phase_pressure_flow(boss: Node, player: Node) -> void:
	var horizontal := boss.get_node_or_null("PhasePressure/HorizontalSweep") as Area2D
	var vertical := boss.get_node_or_null("PhasePressure/VerticalSweep") as Area2D
	if horizontal == null or vertical == null:
		_check("boss phase pressure flow prerequisites", false)
		return
	_check("phase pressure starts hidden", not horizontal.visible and not vertical.visible and not horizontal.monitoring and not vertical.monitoring)
	boss._update_phase_one_pressure(boss.phase_one_pressure_interval + 0.01)
	await process_frame
	var active_sweep := boss._active_pressure_sweep as Area2D
	var active_shape := active_sweep.get_node_or_null("CollisionShape2D") as CollisionShape2D if active_sweep != null else null
	_check("phase pressure telegraph is visible but harmless", active_sweep != null and active_sweep.visible and not active_sweep.monitoring and active_shape != null and active_shape.disabled)
	var energy_before_telegraph: float = player.energy
	boss._on_pressure_sweep_body_entered(player, active_sweep)
	_check("phase pressure telegraph does not drain energy", is_equal_approx(player.energy, energy_before_telegraph))
	boss._update_phase_one_pressure(boss.phase_one_pressure_telegraph_seconds + 0.01)
	await process_frame
	active_sweep = boss._active_pressure_sweep as Area2D
	active_shape = active_sweep.get_node_or_null("CollisionShape2D") as CollisionShape2D if active_sweep != null else null
	_check("phase pressure active enables collision", active_sweep != null and active_sweep.visible and active_sweep.monitoring and active_shape != null and not active_shape.disabled)
	var energy_before_active: float = player.energy
	player.velocity = Vector2.ZERO
	boss._on_pressure_sweep_body_entered(player, active_sweep)
	_check("phase pressure active drains energy", player.energy < energy_before_active)
	_check("phase pressure active knocks player", player.velocity.length() > 0.0)
	boss._update_phase_one_pressure(boss.phase_one_pressure_active_seconds + 0.01)
	await process_frame
	_check("phase pressure hides after active window", active_sweep != null and not active_sweep.visible and not active_sweep.monitoring and active_shape != null and active_shape.disabled)


## 确认三阶段闭窗 authored 扫压只在等待窗口时施压。
func _check_phase_three_pressure_flow(boss: Node, player: Node) -> void:
	var top := boss.get_node_or_null("PhaseThreePressure/TopClampSweep") as Area2D
	var bottom := boss.get_node_or_null("PhaseThreePressure/BottomClampSweep") as Area2D
	var center := boss.get_node_or_null("PhaseThreePressure/CenterCutSweep") as Area2D
	if top == null or bottom == null or center == null:
		_check("phase three pressure flow prerequisites", false)
		return
	_check("phase three pressure starts hidden", not top.visible and not bottom.visible and not center.visible and not top.monitoring and not bottom.monitoring and not center.monitoring)
	boss._dash_window_open = false
	boss._dash_window_warning_active = false
	boss._dash_window_timer = boss.phase_three_warning_seconds + boss.phase_three_pressure_interval + 0.5
	boss._update_phase_three_pressure(boss.phase_three_pressure_interval + 0.01)
	await process_frame
	var active_sweep := boss._active_phase_three_pressure_sweep as Area2D
	var active_shape := active_sweep.get_node_or_null("CollisionShape2D") as CollisionShape2D if active_sweep != null else null
	_check("phase three pressure telegraph visible but harmless", active_sweep != null and active_sweep.visible and not active_sweep.monitoring and active_shape != null and active_shape.disabled)
	_check("phase three pressure telegraph emits top read", _phase_three_pressure_has_event(&"TopClampSweep", &"telegraph", 0.6))
	var energy_before_telegraph: float = player.energy
	boss._on_phase_three_pressure_body_entered(player, active_sweep)
	_check("phase three pressure telegraph does not drain energy", is_equal_approx(player.energy, energy_before_telegraph))
	boss._update_phase_three_pressure(boss.phase_three_pressure_telegraph_seconds + 0.01)
	await process_frame
	active_sweep = boss._active_phase_three_pressure_sweep as Area2D
	active_shape = active_sweep.get_node_or_null("CollisionShape2D") as CollisionShape2D if active_sweep != null else null
	_check("phase three pressure active enables collision", active_sweep != null and active_sweep.visible and active_sweep.monitoring and active_shape != null and not active_shape.disabled)
	_check("phase three pressure active emits top read", _phase_three_pressure_has_event(&"TopClampSweep", &"active", 1.0))
	var energy_before_active: float = player.energy
	player.velocity = Vector2.ZERO
	boss._on_phase_three_pressure_body_entered(player, active_sweep)
	_check("phase three pressure active drains energy", player.energy < energy_before_active)
	_check("phase three pressure active knocks player", player.velocity.length() > 0.0)
	boss._update_phase_three_pressure(boss.phase_three_pressure_active_seconds + 0.01)
	await process_frame
	_check("phase three pressure hides after active window", active_sweep != null and not active_sweep.visible and not active_sweep.monitoring and active_shape != null and active_shape.disabled)
	_check("phase three pressure finish emits clear read", _phase_three_pressure_has_event(&"", &"clear", 0.0))
	boss._start_phase_three_pressure_telegraph()
	await process_frame
	active_sweep = boss._active_phase_three_pressure_sweep as Area2D
	_check("phase three pressure cycles to bottom read", _phase_three_pressure_has_event(&"BottomClampSweep", &"telegraph", 0.6))
	boss._finish_phase_three_pressure_sweep()
	boss._start_phase_three_pressure_telegraph()
	await process_frame
	_check("phase three pressure cycles to center read", _phase_three_pressure_has_event(&"CenterCutSweep", &"telegraph", 0.6))
	boss._finish_phase_three_pressure_sweep()
	boss._dash_window_timer = boss.phase_three_warning_seconds
	boss._update_phase_three_pressure(0.01)
	await process_frame
	_check("phase three pressure hides before dash warning", center != null and not center.visible and not center.monitoring)
	boss._dash_window_timer = boss.phase_three_warning_seconds + boss.phase_three_pressure_interval + 0.5
	boss._start_phase_three_pressure_telegraph()
	await process_frame
	active_sweep = boss._active_phase_three_pressure_sweep as Area2D
	_check("phase three pressure can start before open reset", active_sweep != null and active_sweep.visible)
	boss._set_dash_window(true)
	await process_frame
	_check("phase three pressure hides when dash window opens", active_sweep != null and not active_sweep.visible and not active_sweep.monitoring)
	boss._set_dash_window(false)
	boss._dash_window_timer = boss.phase_three_closed_seconds
	boss._dash_window_warning_active = false
	boss._hide_dash_window_warning()
	boss._reset_phase_three_pressure()
	boss._hide_phase_three_pressure_sweeps()


## 确认 Boss HUD 的分段线和护盾徽标由 authored UI 承载。
func _check_boss_hud_authored(hud_scene: PackedScene) -> void:
	var hud := hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	_check("boss hud authored phase two tick", hud.get_node_or_null("Root/BossFrame/FillClip/PhaseTwoTick") is ColorRect)
	_check("boss hud authored phase three tick", hud.get_node_or_null("Root/BossFrame/FillClip/PhaseThreeTick") is ColorRect)
	_check("boss hud authored shield badge", hud.get_node_or_null("Root/BossFrame/ShieldBadge/Label") is Label)
	_check("boss hud authored pierce read", hud.get_node_or_null("Root/BossFrame/PierceRead") is Label)
	_check("boss hud supports shield state", hud.has_method("set_shield_state"))
	_check("boss hud supports pierce progress", hud.has_method("set_pierce_progress"))
	if hud.has_method("set_pierce_progress"):
		hud.set_pierce_progress(1, 3)
	var pierce_read := hud.get_node_or_null("Root/BossFrame/PierceRead") as Label
	_check("boss hud pierce progress shows text", pierce_read != null and pierce_read.visible and pierce_read.text == "穿透 1/3")
	hud.queue_free()


## 打印测试总结并退出。
func _finish() -> void:
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)
