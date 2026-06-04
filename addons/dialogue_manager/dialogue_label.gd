@icon("./assets/icon.svg")

@tool

## A RichTextLabel specifically for use with [b]Dialogue Manager[/b] dialogue.
##
## 文本特效接入说明：
## 1. `addons/dialogue_manager/text_effects/dmfx_*.gd` 中的本地对白特效会优先注册
## 2. `addons/richtext2/text_effects/effects` 与 `anims` 中的自定义标签会自动补入
## 3. `enabled_text_effects` 设为 `[]`、`null` 或包含 `"*"` 时，默认启用全部可用标签
## 4. 其他系统如需“去掉 BBCode/特效标签后的纯文本”，统一调用
##    `DialogueLabel.bbcode_to_plain_text(...)`
class_name DialogueLabel extends RichTextLabel

const LOCAL_EFFECTS_DIRECTORY := "res://addons/dialogue_manager/text_effects"
const RICHTEXT2_EFFECT_DIRECTORIES := [
	"res://addons/richtext2/text_effects/effects",
	"res://addons/richtext2/text_effects/anims"
]
const BBCode_ESCAPE_SENTINEL := "\uFFF0"
const EFFECT_FADE_IN_SPEED := 12.0

static var _bbcode_tag_regex: RegEx
static var _effect_bbcode_regex: RegEx
static var _supported_effect_scripts: Dictionary = {}
static var _available_effect_names: PackedStringArray = []
static var _effect_registry_ready := false

## Emitted for each letter typed out.
signal spoke(letter: String, letter_index: int, speed: float)

## Emitted when the player skips the typing of dialogue.
signal skipped_typing()

## Emitted when typing starts
signal started_typing()

## Emitted when typing finishes.
signal finished_typing()

## [Deprecated] No longer emitted.
signal paused_typing(duration: float)


## The action to press to skip typing.
@export var skip_action: StringName = &"ui_cancel"

## The speed with which the text types out.
@export var seconds_per_step: float = 0.02

## Automatically have a brief pause when these characters are encountered.
@export var pause_at_characters: String = ".?!"

## Don't auto pause if the character after the pause is one of these.
@export var skip_pause_at_character_if_followed_by: String = ")\""

## Don't auto pause after these abbreviations (only if "." is in `pause_at_characters`).[br]
## Abbreviations are limitted to 5 characters in length [br]
## Does not support multi-period abbreviations (ex. "p.m.")
@export var skip_pause_at_abbreviations: PackedStringArray = ["Mr", "Mrs", "Ms", "Dr", "etc", "eg", "ex"]

## 默认启用哪些对话特效标签。
## 设为 `[]`、`null` 或包含 `"*"` 时，会自动启用当前已发现的全部标签。
@export var enabled_text_effects: Array[String] = ["*"]

## The amount of time to pause when exposing a character present in `pause_at_characters`.
@export var seconds_per_pause_step: float = 0.3

var _already_mutated_indices: PackedInt32Array = []
var _installed_effect_names: Dictionary = {}
var _character_random_cache: PackedInt64Array = []
var _character_random_source: String = ""
var _transforms: Array[Transform2D] = []
var _char_size: Array[Vector2] = []
var _effect_character_alpha: Array[float] = []
var _effect_character_alpha_goal: Array[float] = []
var fade_out := false

var progress: float:
	get:
		var total := get_total_character_count()
		if total <= 0:
			return 1.0
		return clampf(float(visible_character) / float(total), 0.0, 1.0)

var visible_character: int:
	get:
		return _get_effect_visible_count()

var font_size: int:
	get:
		return int(round(get_effect_font_size()))


## The current line of dialogue.
var dialogue_line:
	set(value):
		if value != dialogue_line:
			dialogue_line = value
			_update_text()
	get:
		return dialogue_line

## Whether the label is currently typing itself out.
var is_typing: bool = false:
	set(value):
		var is_finished: bool = _is_typing != value and value == false and visible_characters == get_total_character_count()
		_is_typing = value
		if is_finished:
			finished_typing.emit()
	get:
		return _is_typing and not _is_awaiting_mutation
var _is_typing: bool = false

var _last_wait_index: int = -1
var _last_mutation_index: int = -1
var _waiting_seconds: float = 0
var _is_awaiting_mutation: bool = false


func _ready() -> void:
	bbcode_enabled = true
	_ensure_bbcode_tag_regex()
	_install_enabled_text_effects()


func _process(delta: float) -> void:
	_update_effect_animation_state(delta)
	if _is_typing:
		if visible_ratio < 1:
			if _waiting_seconds > 0:
				_waiting_seconds -= delta
			if _waiting_seconds <= 0:
				_type_next(delta, _waiting_seconds)
		else:
			_mutate_inline_mutations(get_total_character_count())
			is_typing = false


## Sets the label's text from the current dialogue line. Override if you want
## to do something more interesting in your subclass.
func _update_text() -> void:
	_install_enabled_text_effects()
	text = dialogue_line.text if dialogue_line != null else ""
	_refresh_effect_runtime_state()


## 供特效脚本读取当前默认字号。
## 如果你想让特效跟随别的字号规则变化，可以重写这个方法。
func get_effect_font_size() -> float:
	var theme_size := get_theme_font_size(&"normal_font_size")
	if theme_size > 0:
		return float(theme_size)
	return 16.0


func get_normal_font() -> Font:
	return get_theme_font(&"normal_font")


func get_effect_character_size(character: String) -> Vector2:
	var font := get_normal_font()
	if font == null or character.is_empty():
		return Vector2(get_effect_font_size(), get_effect_font_size())
	return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


func _get_character_random(index: int) -> int:
	var parsed_text := get_parsed_text()
	if parsed_text != _character_random_source:
		_character_random_source = parsed_text
		_character_random_cache.resize(parsed_text.length())
		var rng := RandomNumberGenerator.new()
		rng.seed = abs(int(hash(parsed_text)))
		for i in range(parsed_text.length()):
			_character_random_cache[i] = rng.randi()
	if index >= 0 and index < _character_random_cache.size():
		return int(_character_random_cache[index])
	return 0


func _get_character_alpha(index: int) -> float:
	if index < 0 or index >= _effect_character_alpha.size():
		return 1.0 if index < _get_effect_visible_count() else 0.0
	return _effect_character_alpha[index]


func _refresh_effect_runtime_state() -> void:
	var parsed_text := get_parsed_text()
	_sync_effect_character_buffers(parsed_text.length())
	_reset_effect_alpha_state(_get_effect_visible_count())
	for effect in custom_effects:
		if effect == null:
			continue
		effect.set_meta(&"rt", get_instance_id())
		effect.set_meta(&"text", parsed_text)


func _sync_effect_character_buffers(character_count: int) -> void:
	if character_count < 0:
		character_count = 0
	_transforms.resize(character_count)
	_char_size.resize(character_count)
	_effect_character_alpha.resize(character_count)
	_effect_character_alpha_goal.resize(character_count)
	_transforms.fill(Transform2D.IDENTITY)
	_char_size.fill(Vector2.ZERO)


func _reset_effect_alpha_state(visible_count: int) -> void:
	var clamped_visible := clampi(visible_count, 0, _effect_character_alpha.size())
	for i in range(_effect_character_alpha.size()):
		var alpha := 1.0 if i < clamped_visible else 0.0
		_effect_character_alpha[i] = alpha
		_effect_character_alpha_goal[i] = alpha


func _sync_effect_alpha_targets() -> void:
	var clamped_visible := clampi(_get_effect_visible_count(), 0, _effect_character_alpha_goal.size())
	for i in range(_effect_character_alpha_goal.size()):
		_effect_character_alpha_goal[i] = 1.0 if i < clamped_visible else 0.0


func _update_effect_animation_state(delta: float) -> void:
	if _effect_character_alpha.is_empty():
		return
	var step := maxf(delta * EFFECT_FADE_IN_SPEED, 0.0)
	var changed := false
	for i in range(_effect_character_alpha.size()):
		var current: float = _effect_character_alpha[i]
		var goal: float = _effect_character_alpha_goal[i]
		var next_value: float = current
		if current < goal:
			next_value = minf(goal, current + step)
		elif current > goal:
			next_value = maxf(goal, current - step)
		if not is_equal_approx(next_value, current):
			_effect_character_alpha[i] = next_value
			changed = true
	if changed:
		queue_redraw()


func _get_effect_visible_count() -> int:
	var total := get_total_character_count()
	if total <= 0:
		return 0
	if visible_characters < 0:
		return total
	return min(visible_characters, total)


## 获取当前对白去掉所有 BBCode / 自定义特效标签后的纯文本。
## 历史记录、自动推进、摘要存档等逻辑应该优先使用它，而不是直接使用 `dialogue_line.text`。
func get_dialogue_plain_text() -> String:
	var source_text := text
	if dialogue_line != null:
		source_text = dialogue_line.text
	return DialogueLabel.bbcode_to_plain_text(source_text)


## 获取当前真正可见文本长度。
## 作用：避免 `[sparkle]...[]` 这类标签把自动推进时间错误拉长。
func get_display_character_count() -> int:
	var parsed_count := get_total_character_count()
	if parsed_count > 0:
		return parsed_count
	return get_dialogue_plain_text().length()


## 将任意对白文本（可能包含颜色、链接、DialogueLabel 特效标签）转成纯文本。
## 推荐所有“非渲染用途”的逻辑都统一走这里，避免重复写标签清理逻辑。
static func bbcode_to_plain_text(source_text: String) -> String:
	if source_text.is_empty():
		return ""

	_ensure_bbcode_tag_regex()
	var normalized := source_text.replace("[[", BBCode_ESCAPE_SENTINEL)
	normalized = _bbcode_tag_regex.sub(normalized, "", true)
	return normalized.replace(BBCode_ESCAPE_SENTINEL, "[")


## Start typing out the text
func type_out() -> void:
	_update_text()
	visible_characters = 0
	visible_ratio = 0
	_waiting_seconds = 0
	_last_wait_index = -1
	_last_mutation_index = -1
	_already_mutated_indices.clear()
	_reset_effect_alpha_state(0)

	is_typing = true
	started_typing.emit()

	await get_tree().process_frame

	if get_total_character_count() == 0:
		is_typing = false
	elif seconds_per_step == 0:
		_mutate_remaining_mutations()
		visible_characters = get_total_character_count()
		_reset_effect_alpha_state(get_total_character_count())
		is_typing = false


## Stop typing out the text and jump right to the end
func skip_typing() -> void:
	_mutate_remaining_mutations()
	visible_characters = get_total_character_count()
	_reset_effect_alpha_state(get_total_character_count())
	is_typing = false
	skipped_typing.emit()


# Type out the next character(s)
func _type_next(delta: float, seconds_needed: float) -> void:
	if _is_awaiting_mutation:
		return

	if visible_characters == get_total_character_count():
		return

	if _last_mutation_index != visible_characters:
		_last_mutation_index = visible_characters
		_mutate_inline_mutations(visible_characters)
		if _is_awaiting_mutation:
			return

	var waiting_seconds: float = seconds_per_pause_step if _should_auto_pause() else 0
	if _last_wait_index != visible_characters and waiting_seconds > 0:
		_last_wait_index = visible_characters
		_waiting_seconds += waiting_seconds
	else:
		visible_characters += 1
		_sync_effect_alpha_targets()
		if visible_characters <= get_total_character_count():
			spoke.emit(get_parsed_text()[visible_characters - 1], visible_characters - 1, _get_speed(visible_characters))
		seconds_needed += seconds_per_step * (1.0 / _get_speed(visible_characters))
		if seconds_needed > delta:
			_waiting_seconds += seconds_needed
		else:
			_type_next(delta, seconds_needed)


# Get the speed for the current typing position
func _get_speed(at_index: int) -> float:
	var speed: float = 1
	for index in dialogue_line.speeds:
		if index > at_index:
			return speed
		speed = dialogue_line.speeds[index]
	return speed


# Run any inline mutations that haven't been run yet
func _mutate_remaining_mutations() -> void:
	for i in range(visible_characters, get_total_character_count() + 1):
		_mutate_inline_mutations(i)


# Run any mutations at the current typing position
func _mutate_inline_mutations(index: int) -> void:
	for inline_mutation in dialogue_line.inline_mutations:
		if inline_mutation[0] > index:
			return
		if inline_mutation[0] == index and not _already_mutated_indices.has(index):
			_is_awaiting_mutation = true
			await Engine.get_singleton("DialogueManager")._mutate(inline_mutation[1], dialogue_line.extra_game_states, true)
			_is_awaiting_mutation = false

	_already_mutated_indices.append(index)


# Install selected custom effects into this RichTextLabel instance.
func _install_enabled_text_effects() -> void:
	for effect_name in _get_requested_effect_names():
		if _installed_effect_names.has(effect_name) or _has_custom_effect(effect_name):
			_installed_effect_names[effect_name] = true
			continue
		var effect := _create_effect_instance(effect_name)
		if effect == null:
			push_warning("DialogueLabel: unknown effect '%s' was skipped." % effect_name)
			continue
		install_effect(effect)
		_installed_effect_names[effect_name] = true
	_refresh_effect_runtime_state()


func _create_effect_instance(effect_name: String) -> RichTextEffect:
	_ensure_effect_registry()
	if not _supported_effect_scripts.has(effect_name):
		return null
	var script_path := str(_supported_effect_scripts[effect_name])
	var script := load(script_path) as GDScript
	if script == null:
		push_warning("DialogueLabel: failed to load effect script '%s'." % script_path)
		return null
	var effect := script.new() as RichTextEffect
	if effect == null:
		return null
	effect.resource_name = effect_name
	effect.set_meta(&"rt", get_instance_id())
	effect.set_meta(&"text", get_parsed_text())
	return effect


func _has_custom_effect(effect_name: String) -> bool:
	for effect in custom_effects:
		if effect != null and effect.resource_name == effect_name:
			return true
	return false


func _get_requested_effect_names() -> Array[String]:
	_ensure_effect_registry()
	var configured_effects: Variant = enabled_text_effects
	if configured_effects == null:
		return _copy_available_effect_names()
	var requested_effects: Array[String] = []
	if configured_effects is Array or configured_effects is PackedStringArray:
		for effect_name_variant in configured_effects:
			var effect_name := str(effect_name_variant).to_lower().strip_edges()
			if effect_name.is_empty() or effect_name == "*":
				return _copy_available_effect_names()
			if not requested_effects.has(effect_name):
				requested_effects.append(effect_name)
	if requested_effects.is_empty():
		return _copy_available_effect_names()
	return requested_effects


static func _copy_available_effect_names() -> Array[String]:
	var effect_names: Array[String] = []
	for effect_name in _available_effect_names:
		effect_names.append(effect_name)
	return effect_names


static func get_available_effect_names() -> PackedStringArray:
	_ensure_effect_registry()
	return _available_effect_names


static func _ensure_effect_registry() -> void:
	if _effect_registry_ready:
		return
	_effect_registry_ready = true
	_supported_effect_scripts.clear()
	for script_path in _collect_effect_script_paths(LOCAL_EFFECTS_DIRECTORY, "dmfx_"):
		_register_effect_script(script_path, true)
	for directory in RICHTEXT2_EFFECT_DIRECTORIES:
		for script_path in _collect_effect_script_paths(directory, "rte_"):
			_register_effect_script(script_path, false)
	var effect_names: Array[String] = []
	for effect_name in _supported_effect_scripts.keys():
		effect_names.append(str(effect_name))
	effect_names.sort()
	_available_effect_names = PackedStringArray(effect_names)


static func _collect_effect_script_paths(directory: String, prefix: String) -> Array[String]:
	var paths: Array[String] = []
	for file_name in DirAccess.get_files_at(directory):
		if not file_name.begins_with(prefix):
			continue
		if not (file_name.ends_with(".gd") or file_name.ends_with(".gdc")):
			continue
		paths.append(directory.path_join(file_name))
	paths.sort()
	return paths


static func _register_effect_script(script_path: String, prefer_overrides: bool) -> void:
	var effect_name := _extract_effect_name_from_script(script_path)
	if effect_name.is_empty():
		return
	if prefer_overrides or not _supported_effect_scripts.has(effect_name):
		_supported_effect_scripts[effect_name] = script_path


static func _extract_effect_name_from_script(script_path: String) -> String:
	_ensure_effect_bbcode_regex()
	var source_code := FileAccess.get_file_as_string(script_path)
	if source_code.is_empty():
		return ""
	var match := _effect_bbcode_regex.search(source_code)
	if match == null:
		return ""
	return match.get_string(1).to_lower().strip_edges()


static func _ensure_effect_bbcode_regex() -> void:
	if _effect_bbcode_regex != null:
		return
	_effect_bbcode_regex = RegEx.new()
	_effect_bbcode_regex.compile("(?m)^\\s*(?:const|var)\\s+bbcode(?:\\s*:\\s*[A-Za-z0-9_]+)?\\s*(?::=|=)\\s*\"([^\"]+)\"")


static func _ensure_bbcode_tag_regex() -> void:
	if _bbcode_tag_regex != null:
		return
	_bbcode_tag_regex = RegEx.new()
	_bbcode_tag_regex.compile("\\[[^\\]]*\\]")


# Determine if the current autopause character at the cursor should qualify to pause typing.
func _should_auto_pause() -> bool:
	if visible_characters == 0:
		return false

	var parsed_text: String = get_parsed_text()
	if visible_characters >= parsed_text.length():
		return false

	if parsed_text[visible_characters] in skip_pause_at_character_if_followed_by.split():
		return false

	if visible_characters > 3 and parsed_text[visible_characters - 1] == ".":
		var possible_number: String = parsed_text.substr(visible_characters - 2, 3)
		if str(float(possible_number)).pad_decimals(1) == possible_number:
			return false

	if "." in pause_at_characters and parsed_text[visible_characters - 1] == ".":
		for abbreviation in skip_pause_at_abbreviations:
			if visible_characters >= abbreviation.length():
				var previous_characters: String = parsed_text.substr(visible_characters - abbreviation.length() - 1, abbreviation.length())
				if previous_characters == abbreviation:
					return false

	var other_pause_characters: PackedStringArray = pause_at_characters.replace(".", "").split()
	if visible_characters > 1 and parsed_text[visible_characters - 1] in other_pause_characters and parsed_text[visible_characters] in other_pause_characters:
		return false

	return parsed_text[visible_characters - 1] in pause_at_characters.split()
