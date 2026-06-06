extends Button
class_name ShaderButton
## 着色器风格按钮（CloseAI 自足版，移植自 Booom）
##
## 职责：纯视觉交互——shader 涟漪/悬停辉光 + 轻微缩放抖动。
## 不依赖 Booom 的 ComponentBase；hover 抖动内联；音效经 SoundManager 守卫调用。
## 用法：实例化 ui_kit/components/shader_button.tscn，设 bb_text。pressed 信号同 Button。

const BUTTON_SHADER := preload("res://ui_kit/shaders/shader_button.gdshader")
const PRESS_SFX_PATH := "res://assets/sfx/ui/button_press.wav"
const HOVER_SFX_PATH := "res://assets/sfx/ui/button_hover.wav"

@export var h_expend: float = 12
@export var v_expend: float = 8
@export var panel_style_box: StyleBox
## hover 抖动幅度
@export var scale_amount: Vector2 = Vector2.ONE * 1.06
@export var rotation_amount: float = 2.0
@export_group("BBcode")
@export_multiline var bb_text: String

@onready var text_label: RichTextLabel = $Label
@onready var panel: Panel = $Panel

var _exit_tween: Tween
var _wiggle_tween: Tween
var _is_mouse_over: bool = false
var _original_label_modulate: Color = Color.WHITE
var _center_click: Vector2 = Vector2(0.5, 0.5)
var _center_hover: Vector2 = Vector2(0.5, 0.5)


func _ready() -> void:
	pivot_offset = size / 2.0
	if panel_style_box != null:
		panel.add_theme_stylebox_override("panel", panel_style_box)

	text_label.text = bb_text if not bb_text.is_empty() else text
	text_label.add_theme_font_size_override("normal_font_size", get_theme_font_size("font_size"))
	text = ""

	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = BUTTON_SHADER
	material.set("shader_parameter/size", size)
	material.set("shader_parameter/time1", 1.0)
	material.set("shader_parameter/time2", 0.0)
	material.set("shader_parameter/glow", 0.0)
	material.set("shader_parameter/center1", _center_click)
	material.set("shader_parameter/center2", _center_hover)
	var normal_style := get_theme_stylebox("normal")
	if normal_style is StyleBoxFlat and size.y > 0:
		material.set("shader_parameter/corner_radius", (normal_style as StyleBoxFlat).corner_radius_top_left / size.y * 2)
	material.set("shader_parameter/color", modulate)

	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_original_label_modulate = text_label.modulate
	await get_tree().process_frame
	_center_label()


func _process(_delta: float) -> void:
	if material == null:
		return
	if disabled:
		modulate.a = 0.5
		return
	if size.x <= 0:
		return
	var local_mouse := (get_global_transform().affine_inverse() * get_global_mouse_position()) / size
	if _is_mouse_over:
		_center_hover = local_mouse
		material.set("shader_parameter/center2", _center_hover)
	material.set("shader_parameter/center1", _center_click)


# ── 公开 API ──

func set_bbtext(bbtext: String) -> void:
	bb_text = bbtext
	if text_label != null:
		text_label.text = bbtext
		await get_tree().process_frame
		_center_label()


# ── 信号处理 ──

func _on_pressed() -> void:
	_play_sfx(PRESS_SFX_PATH, -9.0)
	if size.x > 0:
		_center_click = (get_global_transform().affine_inverse() * get_global_mouse_position()) / size
	create_tween().tween_property(material, "shader_parameter/time1", 1.0, 0.5).from(0.0)
	_wiggle()


func _on_mouse_entered() -> void:
	if disabled:
		return
	_play_sfx(HOVER_SFX_PATH, -13.0)
	_is_mouse_over = true
	if _exit_tween:
		_exit_tween.kill()
	create_tween().tween_property(material, "shader_parameter/glow", 2.0, 0.2)
	create_tween().tween_property(material, "shader_parameter/time2", 0.35, 0.2)
	text_label.modulate = _original_label_modulate * 1.6
	_wiggle()


func _on_mouse_exited() -> void:
	if disabled:
		return
	_is_mouse_over = false
	var exit_target := Vector2(0.5, 0.5) + (_center_hover - Vector2(0.5, 0.5)).normalized() * 2.0
	_exit_tween = create_tween()
	_exit_tween.parallel().tween_property(self, "_center_hover", exit_target, 0.3)
	_exit_tween.parallel().tween_property(material, "shader_parameter/time2", 0.0, 0.3)
	_exit_tween.parallel().tween_property(material, "shader_parameter/glow", 0.0, 0.2)
	_exit_tween.tween_callback(func(): _center_hover = Vector2(0.5, 0.5))
	text_label.modulate = _original_label_modulate
	if _wiggle_tween:
		_wiggle_tween.kill()
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.12)
	create_tween().tween_property(self, "rotation_degrees", 0.0, 0.12)


# ── 内部 ──

func _wiggle() -> void:
	pivot_offset = size / 2.0
	if _wiggle_tween:
		_wiggle_tween.kill()
	_wiggle_tween = create_tween().set_parallel()
	_wiggle_tween.tween_property(self, "scale", scale_amount, 0.08)
	_wiggle_tween.tween_property(self, "rotation_degrees", rotation_amount * [-1, 1].pick_random(), 0.08)


func _center_label() -> void:
	if text_label != null and size.x > 0:
		text_label.position.x = (size.x / 2.0 - text_label.size.x / 2.0)


func _on_label_resized() -> void:
	if text_label != null and size < text_label.size:
		size = text_label.size + Vector2(h_expend, v_expend)


## 守卫式音效：文件不存在或 SoundManager 缺失则静默跳过
func _play_sfx(path: String, volume_db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var sm := get_node_or_null("/root/SoundManager")
	if sm == null or not sm.has_method("play_ui_sound"):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player = sm.play_ui_sound(stream)
	if player != null:
		player.volume_db += volume_db
