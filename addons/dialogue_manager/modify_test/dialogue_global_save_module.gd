class_name DialogueGlobalSaveModule
extends ISaveModule
## ════════════════════════════════════════════════════════════════
##  DialogueGlobalSaveModule — 全局对话存档模块（全局存档）
## ════════════════════════════════════════════════════════════════
##
## 这个模块与 `DialogueSaveModule` 类似，区别在于它保存的数据是跨"槽位"共享的。
## 适用于：
##    • 需要在不同存档间共享的对话状态（例如：全局剧情进度、NPC 记忆、解锁项）
##    • 无需按槽位单独保存的对话快照
##
## 说明：
##  1) 该模块会存入 SaveSystem 的 global 存档（global.json）。
##  2) 若你觉得当前只需槽位存档（不需要跨槽位共享），可以不用注册本模块。
##
## 使用方式：
##   SaveSystem.register_module(DialogueGlobalSaveModule.new())
##   var m := SaveSystem.get_module("dialogue_global") as DialogueGlobalSaveModule
##   m.save_progress(...)
##   SaveSystem.save_global()
##
## 读取：
##   var progress = m.load_progress()
##

## 单例引用（可选，方便外部直接获取）
static var instance: DialogueGlobalSaveModule

# ──────────────────────────────────────────────
# 数据字段
# ──────────────────────────────────────────────

## 最近一次对话资源（res:// 路径）
var dialogue_resource_path: String = ""

## 最近一次打开的 dialogue title（或 ID）
var dialogue_title: String = ""

## 最近一次对话的章节／场景名（用于 UI 展示）
var chapter_name: String = ""

## 最近一次发言角色（用于 UI 显示）
var character_name: String = ""

## 最近一次对话内容的摘要（用于 UI 显示）
var dialogue_snippet: String = ""

## 可选全局变量（可用于存储跨存档对话状态、flag、计数器）
var dialogue_variables: Dictionary = {}

# ──────────────────────────────────────────────
# 构造
# ──────────────────────────────────────────────

func _init() -> void:
	instance = self

# ──────────────────────────────────────────────
# ISaveModule 接口（必须实现）
# ──────────────────────────────────────────────

func get_module_key() -> String:
	return "dialogue_global"

func is_global() -> bool:
	return true

func collect_data() -> Dictionary:
	return {
		"dialogue_resource_path": dialogue_resource_path,
		"dialogue_title":         dialogue_title,
		"chapter_name":           chapter_name,
		"character_name":         character_name,
		"dialogue_snippet":       dialogue_snippet,
		"dialogue_variables":     dialogue_variables.duplicate(true),
	}

func apply_data(data: Dictionary) -> void:
	dialogue_resource_path = data.get("dialogue_resource_path", "")
	dialogue_title         = data.get("dialogue_title",         "")
	chapter_name           = data.get("chapter_name",           "")
	character_name         = data.get("character_name",         "")
	dialogue_snippet       = data.get("dialogue_snippet",       "")
	dialogue_variables     = (data.get("dialogue_variables", {}) as Dictionary).duplicate(true)

# ──────────────────────────────────────────────
# 业务 API
# ──────────────────────────────────────────────

## 保存对话进度快照到全局存档
func save_progress(
		resource: DialogueResource,
		title: String,
		chapter: String = "",
		character: String = "",
		snippet: String = "") -> void:
	dialogue_resource_path = resource.resource_path if is_instance_valid(resource) else ""
	dialogue_title         = title
	chapter_name           = chapter
	character_name         = character
	dialogue_snippet       = snippet.left(60)

## 设置自定义对话变量（跨存档共享）
func set_variable(key: String, value: Variant) -> void:
	dialogue_variables[key] = value

## 获取自定义对话变量
func get_variable(key: String, default: Variant = null) -> Variant:
	return dialogue_variables.get(key, default)

## 是否有保存的进度
func has_progress() -> bool:
	return not dialogue_resource_path.is_empty() and not dialogue_title.is_empty()

## 尝试加载对话资源（失败返回 null）
func load_dialogue_resource() -> DialogueResource:
	if dialogue_resource_path.is_empty():
		return null
	if not ResourceLoader.exists(dialogue_resource_path):
		push_warning("DialogueGlobalSaveModule: resource not found: %s" % dialogue_resource_path)
		return null
	return load(dialogue_resource_path) as DialogueResource
