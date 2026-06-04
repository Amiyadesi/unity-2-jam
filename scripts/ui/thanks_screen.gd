extends GlassModal
## thanks_screen.gd — 感谢/制作名单 模态（金棕玻璃风）
##
## 纯展示：标题 + 致谢正文 + 返回按钮。返回时 emit return_requested。

signal return_requested()

@onready var _return_button: Button = $Panel/Margin/VBox/ReturnButton

func _ready() -> void:
	super._ready()
	_return_button.pressed.connect(func(): return_requested.emit())
