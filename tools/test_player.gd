extends SceneTree
## test_player.gd — 验证玩家场景实例化 + 动画齐全
## 运行：godot --headless --path . --script res://tools/test_player.gd

var _failures := 0
var _checks := 0

## 延迟运行测试，等待引擎初始化。
func _init() -> void:
	call_deferred("_run")

## 记录一条检查结果。
func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  [PASS] " if cond else "  [FAIL] ") + label)
	if not cond:
		_failures += 1

## 实例化玩家并验证动画、能量、觉醒接口。
func _run() -> void:
	print("=== CloseAI player test ===")
	await process_frame
	var packed = load("res://scenes/player.tscn")
	_check("player.tscn loads", packed != null)
	if packed == null:
		_finish(); return
	var p = packed.instantiate()
	_check("player instantiates", p != null)
	root.add_child(p)
	await process_frame
	var anim = p.get_node_or_null("AnimationPlayer")
	_check("has AnimationPlayer", anim != null)
	var expected = ["idle","walk","jump","fall","crouch","standup","pickup",
		"transform","morph_idle","morph_move","untransform","cast_forward","cast_side","death"]
	for name in expected:
		_check("anim '%s' exists" % name, anim != null and anim.has_animation(name))
	var sprite = p.get_node_or_null("Body/Sprite2D")
	_check("sprite hframes=17", sprite != null and sprite.hframes == 17)
	_check("sprite vframes=16", sprite != null and sprite.vframes == 16)
	var camera := p.get_node_or_null("Camera2D") as Camera2D
	_check("has Camera2D", camera != null)
	_check("camera zoom is 2x", camera != null and camera.zoom == Vector2(2, 2))
	_check("cast forward release frame authored", _animation_has_method_key(anim, "cast_forward", &"release_cast_forward"))
	_check("cast side release frame authored", _animation_has_method_key(anim, "cast_side", &"release_cast_side"))
	_check("dash particles authored", p.get_node_or_null("Body/CombatVFX/DashSpeedParticles") is GPUParticles2D)
	_check("dash wind ring authored", p.get_node_or_null("Body/CombatVFX/DashWindRing") is Node2D)
	_check("dash afterimage authored", p.get_node_or_null("Body/CombatVFX/DashAfterimageTrail") is Node2D)
	_check("dash hit confirm authored", p.get_node_or_null("Body/CombatVFX/DashHitConfirm") is Node2D)
	_check("dash whiff read authored", p.get_node_or_null("Body/CombatVFX/DashWhiffRead") is Node2D)
	_check("cast particles authored", p.get_node_or_null("Body/CombatVFX/CastEnergyParticles") is GPUParticles2D)
	_check("cast impact ring authored", p.get_node_or_null("Body/CombatVFX/CastImpactRing") is Node2D)
	var script_property_names := _get_script_property_names(p)
	_check("has energy property", script_property_names.has("energy"))
	_check("has max_energy property", script_property_names.has("max_energy"))
	_check("energy starts within max", script_property_names.has("energy") and script_property_names.has("max_energy") and p.energy >= 0.0 and p.energy <= p.max_energy)
	_check("flight speed tuned slightly slower", p.FLY_SPEED <= 580.0)
	_check("dash speed tuned longer", p.dash_speed >= 1240.0 and p.dash_hitbox_duration >= 0.26 and p.camera_dash_hold_time >= 0.30)
	_check("awaken action exists", InputMap.has_action("awaken"))
	_check("dash action exists", InputMap.has_action("dash"))
	_check("dash action includes left mouse", _input_action_has_mouse_button("dash", MOUSE_BUTTON_LEFT))
	_check("dash_started signal exists", p.has_signal("dash_started"))
	_check("dash_hit_confirmed signal exists", p.has_signal("dash_hit_confirmed"))
	_check("dash_whiffed signal exists", p.has_signal("dash_whiffed"))
	_check_player_sfx_nodes(p)
	await _check_training_target_hit(p)
	_check_ability_gates(p)
	await _check_cast_release_frame(p)
	await _check_dash_vfx_and_camera(p)
	await _check_dash_hit_confirm(p)
	await _check_ability_release_vfx(p)
	# play_action runs without error
	if p.has_method("play_action"):
		p.play_action("pickup")
		await process_frame
		_check("play_action('pickup') runs", true)
		p.play_action("transform")
		await process_frame
		_check("play_action('transform') runs", true)
		_check("transform sfx plays", (p.get_node_or_null("Audio/TransformSfx") as AudioStreamPlayer2D).playing)
		p.play_action("untransform")
		await process_frame
		_check("play_action('untransform') runs", true)
		_check("untransform sfx plays", (p.get_node_or_null("Audio/UntransformSfx") as AudioStreamPlayer2D).playing)
	p.queue_free()
	_finish()


## 确认玩家短音效全部由 authored AudioStreamPlayer2D 节点承载。
func _check_player_sfx_nodes(player: Node) -> void:
	var audio := player.get_node_or_null("Audio")
	_check("player authored Audio root", audio is Node2D)
	for node_name in ["JumpSfx", "MoveSfx", "AttackSfx", "DashSfx", "TransformSfx", "UntransformSfx", "HitConfirmSfx", "WhiffSfx"]:
		var sfx := player.get_node_or_null("Audio/" + node_name) as AudioStreamPlayer2D
		_check("player authored " + node_name, sfx != null)
		_check("player " + node_name + " has stream", sfx != null and sfx.stream != null)
		_check("player " + node_name + " uses Sounds bus", sfx != null and sfx.bus == "Sounds")

## 验证玩家 authored hitbox 真的能命中 typed 训练靶，而不只是场景节点存在。
func _check_training_target_hit(player: Node) -> void:
	var previous_gravity: float = player.gravity
	player.gravity = 0.0
	player.velocity = Vector2.ZERO
	var target_packed = load("res://scenes/training_target.tscn")
	_check("training target scene loads", target_packed != null)
	if target_packed == null:
		player.gravity = previous_gravity
		return
	var target = target_packed.instantiate()
	_check("training target instantiates", target != null)
	if target == null:
		player.gravity = previous_gravity
		return
	target.required_attack_kind = "forward"
	target.starts_enabled = true
	root.add_child(target)
	var completed_state := {"value": false}
	target.completed.connect(func(_target: Area2D, _kind: StringName) -> void:
		completed_state["value"] = true
	)
	await physics_frame
	var forward_hitbox := player.get_node_or_null("Body/CombatHitboxes/ForwardHitbox") as Area2D
	_check("forward hitbox available for target test", forward_hitbox != null)
	if forward_hitbox != null:
		target.global_position = forward_hitbox.global_position
		await physics_frame
		var hitboxes: Array[Area2D] = [forward_hitbox]
		player._start_hitbox_window(hitboxes, player.attack_hitbox_duration)
		for _i in range(4):
			await physics_frame
		_check("forward attack completes training target", completed_state["value"] and target.is_completed())
		target.reset_target()
		_check("training target reset restores visibility", not target.is_completed() and is_equal_approx(target.modulate.a, 1.0))
	target.queue_free()
	player.gravity = previous_gravity

## 验证觉醒冲刺触发速度、VFX、相机前移和不翻图。
func _check_dash_vfx_and_camera(player: Node) -> void:
	player.morphed = true
	player.frozen = false
	player._action_playing = false
	player._transform_motion_locked = false
	player.allow_dash = true
	player.energy = player.max_energy
	player.velocity = Vector2.ZERO
	var body := player.get_node_or_null("Body") as Node2D
	var lines := player.get_node_or_null("Body/CombatVFX/DashSpeedLines") as CanvasItem
	var wind_ring := player.get_node_or_null("Body/CombatVFX/DashWindRing") as CanvasItem
	var trail := player.get_node_or_null("Body/CombatVFX/DashAfterimageTrail") as CanvasItem
	var confirm_vfx := player.get_node_or_null("Body/CombatVFX/DashHitConfirm") as CanvasItem
	var whiff_vfx := player.get_node_or_null("Body/CombatVFX/DashWhiffRead") as CanvasItem
	var particles := player.get_node_or_null("Body/CombatVFX/DashSpeedParticles") as GPUParticles2D
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	_check("dash vfx prerequisites available", body != null and lines != null and wind_ring != null and trail != null and confirm_vfx != null and whiff_vfx != null and particles != null and camera != null)
	if body == null or lines == null or wind_ring == null or trail == null or confirm_vfx == null or whiff_vfx == null or particles == null or camera == null:
		return
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	player._input(left_click)
	player._physics_fly(0.016)
	_check("left mouse input buffers dash before UI can consume it", player.is_dashing() and player.velocity.length() > player.FLY_SPEED)
	_check("left mouse dash sfx plays", (player.get_node_or_null("Audio/DashSfx") as AudioStreamPlayer2D).playing)
	player._disable_all_hitboxes()
	player._hide_combat_vfx()
	player.energy = player.max_energy
	player.velocity = Vector2.ZERO
	var expected_dir: Vector2 = player.get_global_mouse_position() - player.global_position
	player._fly_angle = PI * 0.5
	if expected_dir.length() <= 0.01:
		expected_dir = Vector2.RIGHT.rotated(player._fly_angle)
	expected_dir = expected_dir.normalized()
	var whiff_state := {"count": 0, "dir": Vector2.ZERO}
	var whiff_handler := func(direction: Vector2) -> void:
		whiff_state["count"] += 1
		whiff_state["dir"] = direction
	player.dash_whiffed.connect(whiff_handler)
	player._start_dash_attack()
	var expected_visual_rotation: float = player._fly_visual_angle(expected_dir)
	var expected_local_rotation: float = wrapf(expected_dir.angle() - body.global_rotation, -PI, PI)
	_check("dash velocity follows aim direction", player.velocity.normalized().dot(expected_dir) > 0.95)
	_check("dash velocity is fast", player.velocity.length() >= player.dash_speed - 1.0)
	_check("dash keeps body scale positive", body.scale.x > 0.0)
	_check("dash rotates body to visual flight angle", absf(wrapf(body.rotation - expected_visual_rotation, -PI, PI)) < 0.02)
	_check("dash hitboxes keep true aim angle", absf(wrapf(player.get_node("Body/CombatHitboxes").global_rotation - expected_dir.angle(), -PI, PI)) < 0.02)
	_check("dash speed lines align to body-local dash", absf(wrapf(lines.rotation - expected_local_rotation, -PI, PI)) < 0.02)
	_check("dash wind ring expands from small scale", wind_ring.scale.x < 1.0 and wind_ring.scale.y < 1.0)
	_check("dash particles emit backward locally", absf(wrapf(particles.rotation - (expected_local_rotation + PI), -PI, PI)) < 0.02)
	_check("dash speed lines show", lines.visible)
	_check("dash wind ring shows", wind_ring.visible)
	_check("dash afterimage shows", trail.visible)
	_check("dash particles emit", particles.emitting)
	await process_frame
	_check("dash attack window active", player.is_dashing())
	player._update_camera_lookahead(0.016)
	_check("dash camera looks ahead", camera.offset.length() > 1.0)
	_check("dash camera opens view", camera.zoom.x < player.camera_zoom_ground.x and camera.zoom.x > player.camera_zoom_dash.x)
	for _i in range(28):
		player._update_active_hitboxes(0.016)
	_check("dash attack window ends before camera tail", not player.is_dashing() and player._camera_dash_timer > 0.0)
	_check("dash whiff read shows when window misses", whiff_vfx.visible and not confirm_vfx.visible)
	_check("dash whiff sfx plays", (player.get_node_or_null("Audio/WhiffSfx") as AudioStreamPlayer2D).playing)
	_check("dash whiff signal emits miss direction", whiff_state["count"] == 1 and (whiff_state["dir"] as Vector2).dot(expected_dir) > 0.95)
	if player.dash_whiffed.is_connected(whiff_handler):
		player.dash_whiffed.disconnect(whiff_handler)
	player._camera_dash_timer = 0.0
	player.morphed = true
	player._update_motion_mode()
	player._action_playing = false
	player.frozen = false
	var collision_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_check("flight uses floating collision mode", player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING)
	_check("flight root collision stays upright", collision_shape != null and is_equal_approx(collision_shape.rotation, 0.0))
	_check("flight visual angle right is world angle", absf(wrapf(player._fly_visual_angle(Vector2.RIGHT) - 0.0, -PI, PI)) < 0.02)
	_check("flight visual angle down is world angle", absf(wrapf(player._fly_visual_angle(Vector2.DOWN) - PI * 0.5, -PI, PI)) < 0.02)
	_check("flight visual angle left is world angle", absf(absf(wrapf(player._fly_visual_angle(Vector2.LEFT), -PI, PI)) - PI) < 0.02)
	_check("flight visual angle up is world angle", absf(wrapf(player._fly_visual_angle(Vector2.UP) + PI * 0.5, -PI, PI)) < 0.02)
	player.velocity = Vector2(player.FLY_SPEED, 0.0)
	player._update_camera_lookahead(0.12)
	_check("flight camera opens view lightly", camera.zoom.x < player.camera_zoom_ground.x and camera.zoom.x > player.camera_zoom_dash.x)
	body.rotation = 0.0
	player._fly_angle = 0.0
	player._last_fly_input = Vector2.RIGHT
	player.velocity = Vector2(player.FLY_SPEED, 0.0)
	player._update_facing_fly(0.2)
	var right_rotation := body.rotation
	_check("active right flight faces right", absf(wrapf(right_rotation, -PI, PI)) < 0.02)
	body.rotation = 0.0
	player._fly_angle = PI
	player._last_fly_input = Vector2.LEFT
	player.velocity = Vector2(-player.FLY_SPEED, 0.0)
	player._update_facing_fly(0.2)
	var left_rotation := body.rotation
	_check("active left flight faces left", absf(absf(wrapf(left_rotation, -PI, PI)) - PI) < 0.02)
	_check("left/right flight rotations oppose", absf(absf(wrapf(left_rotation - right_rotation, -PI, PI)) - PI) < 0.02)
	body.rotation = 0.0
	player._fly_angle = 0.0
	player._last_fly_input = Vector2.ZERO
	player.velocity = Vector2.UP * player.FLY_SPEED
	player._update_facing_fly(0.2)
	_check("released high-speed flight follows velocity visually", absf(wrapf(body.rotation - player._fly_visual_angle(Vector2.UP), -PI, PI)) < 0.02)
	body.rotation = PI * 0.75
	player._fly_angle = PI * 0.75
	player._last_fly_input = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player._update_facing_fly(0.2)
	_check("idle flight returns upright", absf(body.rotation) < 0.02)
	body.rotation = -PI * 0.5
	player.correct_flight_pose()
	_check("pause correction forces upright hover", is_equal_approx(body.rotation, 0.0) and body.scale.x > 0.0)
	player.morphed = false
	player._update_motion_mode()
	_check("ground uses grounded collision mode", player.motion_mode == CharacterBody2D.MOTION_MODE_GROUNDED)
	player.velocity = Vector2.ZERO
	for _i in range(12):
		player._update_camera_lookahead(0.12)
	_check("camera returns to 2x after speed state", camera.zoom.distance_to(player.camera_zoom_ground) < 0.05)

## 验证高速冲撞只有在目标接受命中时才给玩家确认、续速和 VFX。
func _check_dash_hit_confirm(player: Node) -> void:
	var target_packed = load("res://scenes/training_target.tscn")
	_check("dash-confirm target scene loads", target_packed != null)
	if target_packed == null:
		return
	var target = target_packed.instantiate()
	_check("dash-confirm target instantiates", target != null)
	if target == null:
		return
	target.required_attack_kind = "dash"
	target.starts_enabled = true
	root.add_child(target)
	await physics_frame
	player.morphed = false
	player.frozen = false
	player.energy = player.max_energy
	player.velocity = Vector2(180.0, 0.0)
	var confirm_state := {"count": 0, "dir": Vector2.ZERO}
	var confirm_handler := func(_target: Node, direction: Vector2) -> void:
		confirm_state["count"] += 1
		confirm_state["dir"] = direction
	player.dash_hit_confirmed.connect(confirm_handler)
	var confirm_vfx := player.get_node_or_null("Body/CombatVFX/DashHitConfirm") as CanvasItem
	var whiff_vfx := player.get_node_or_null("Body/CombatVFX/DashWhiffRead") as CanvasItem
	var forward_hitbox := player.get_node_or_null("Body/CombatHitboxes/ForwardHitbox") as Area2D
	_check("dash-confirm prerequisites available", confirm_vfx != null and whiff_vfx != null and forward_hitbox != null)
	if confirm_vfx == null or whiff_vfx == null or forward_hitbox == null:
		target.queue_free()
		return
	player._hide_combat_vfx()
	var hitboxes: Array[Area2D] = [forward_hitbox]
	player._active_hitboxes = hitboxes
	player._hit_targets.clear()
	player._try_damage_target(target)
	_check("dash-confirm rejects non-dash hit on dash target", confirm_state["count"] == 0 and not confirm_vfx.visible and not target.is_completed())
	target.reset_target()
	player.morphed = true
	player.velocity = Vector2(320.0, 0.0)
	player._active_hitboxes = hitboxes
	player._hit_targets.clear()
	player._try_damage_target(target)
	_check("dash-confirm emits on accepted dash target", confirm_state["count"] == 1 and target.is_completed())
	_check("dash-confirm vfx shows on accepted hit", confirm_vfx.visible)
	player._dash_attack_timer = 0.01
	player._update_active_hitboxes(0.02)
	_check("dash-confirm suppresses whiff read", not whiff_vfx.visible)
	_check("dash-confirm keeps chain speed", player.velocity.length() >= player.dash_speed * player.dash_hit_confirm_keep_speed_ratio - 1.0)
	_check("dash-confirm reports forward hit direction", (confirm_state["dir"] as Vector2).dot(Vector2.RIGHT) > 0.95)
	if player.dash_hit_confirmed.is_connected(confirm_handler):
		player.dash_hit_confirmed.disconnect(confirm_handler)
	target.queue_free()

## 验证觉醒/超载释放会触发 authored 粒子和冲击圈。
func _check_ability_release_vfx(player: Node) -> void:
	var particles := player.get_node_or_null("AwakenCenterVFX/AwakenCenterParticles") as GPUParticles2D
	var ring := player.get_node_or_null("AwakenCenterVFX/AwakenCenterRing") as CanvasItem
	_check("ability-release prerequisites available", particles != null and ring != null)
	if particles == null or ring == null:
		return
	player.morphed = false
	particles.emitting = false
	ring.hide()
	player.start_overload(0.5)
	await process_frame
	_check("overload enters morph state", player.morphed)
	_check("overload release particles emit", particles.emitting)
	_check("overload release ring shows", ring.visible and ring.scale.x < 1.0)
	player.morphed = false


## 验证 authored/export 能力门控能阻止第 1 关提前觉醒或冲撞。
func _check_ability_gates(player: Node) -> void:
	player.allow_awaken = false
	player.morphed = false
	player._awaken_pressed_buffered = true
	player._handle_awaken()
	_check("allow_awaken=false blocks transform", not player.morphed)
	player.allow_awaken = true
	player.allow_dash = false
	player.morphed = true
	player.energy = player.max_energy
	player._disable_all_hitboxes()
	var before_energy: float = player.energy
	player._start_dash_attack()
	_check("allow_dash=false blocks dash window", not player.is_dashing())
	_check("allow_dash=false preserves energy", is_equal_approx(player.energy, before_energy))
	player.allow_dash = true
	player.morphed = false

## 验证普通释放不会在按下瞬间命中，而是在动画释放帧打开 hitbox。
func _check_cast_release_frame(player: Node) -> void:
	var previous_gravity: float = player.gravity
	player.gravity = 0.0
	player.velocity = Vector2.ZERO
	var target_packed = load("res://scenes/training_target.tscn")
	_check("release-frame target scene loads", target_packed != null)
	if target_packed == null:
		player.gravity = previous_gravity
		return
	var target = target_packed.instantiate()
	target.required_attack_kind = "forward"
	target.starts_enabled = true
	root.add_child(target)
	if player.has_method("_disable_all_hitboxes"):
		player._disable_all_hitboxes()
	var completed_state := {"value": false}
	target.completed.connect(func(_target: Area2D, _kind: StringName) -> void:
		completed_state["value"] = true
	)
	await physics_frame
	await physics_frame
	var forward_hitbox := player.get_node_or_null("Body/CombatHitboxes/ForwardHitbox") as Area2D
	_check("forward hitbox available for release-frame test", forward_hitbox != null)
	if forward_hitbox != null:
		target.global_position = forward_hitbox.global_position
		player._start_cast_attack("cast_forward", 0.0)
		await process_frame
		await physics_frame
		_check("cast target not hit before release frame", not completed_state["value"])
		var shockwave := player.get_node_or_null("Body/CombatVFX/ForwardShockwave") as CanvasItem
		var particles := player.get_node_or_null("Body/CombatVFX/CastEnergyParticles") as GPUParticles2D
		var ring := player.get_node_or_null("Body/CombatVFX/CastImpactRing") as CanvasItem
		for _i in range(30):
			await process_frame
			await physics_frame
			if completed_state["value"]:
				break
		_check("cast target hit at animation release frame", completed_state["value"] and target.is_completed())
		_check("cast forward shockwave shows at release", shockwave != null and shockwave.visible)
		_check("cast release particles emit", particles != null and particles.emitting)
		_check("cast impact ring expands from small scale", ring != null and ring.visible and ring.scale.x < 1.0)
		_check("cast attack sfx plays at release", (player.get_node_or_null("Audio/AttackSfx") as AudioStreamPlayer2D).playing)
	target.queue_free()
	player.gravity = previous_gravity

## 读取脚本导出的/声明的属性名，避免测试依赖私有实现。
func _get_script_property_names(node: Object) -> Array[String]:
	var names: Array[String] = []
	for property in node.get_property_list():
		var property_name := str(property.get("name", ""))
		if property_name != "":
			names.append(property_name)
	return names

## 查找 AnimationPlayer 中指定动画的 authored 方法轨。
func _animation_has_method_key(anim_player: AnimationPlayer, animation_name: String, method_name: StringName) -> bool:
	if anim_player == null or not anim_player.has_animation(animation_name):
		return false
	var animation := anim_player.get_animation(animation_name)
	if animation == null:
		return false
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_METHOD:
			continue
		for key_index in range(animation.track_get_key_count(track_index)):
			var value = animation.track_get_key_value(track_index, key_index)
			if value is Dictionary and value.get("method", &"") == method_name and animation.track_get_key_time(track_index, key_index) >= 0.25:
				return true
	return false


## 检查某个动作是否包含指定鼠标按钮绑定。
func _input_action_has_mouse_button(action_name: String, button_index: int) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button_index:
			return true
	return false

## 输出测试汇总并设置退出码。
func _finish() -> void:
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)
