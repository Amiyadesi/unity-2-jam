extends Node
class_name DesktopReveal
## desktop_reveal.gd — 终局「透出真实桌面」工具（移植/验证用）
##
## 把游戏窗口变成真·逐像素透明，让玩家看到自己真实的桌面——
## 「它真的逃出来了」。前提：project.godot 已开 per_pixel_transparency/allowed=true。
##
## 用法（终局关 / 验证场景）：
##   DesktopReveal.reveal(self)        # 隐藏传入节点树里编组 "opaque_bg" 的背景 + 开窗口透明
##   DesktopReveal.restore()           # 复原（关掉透明、显示背景）
##
## 约定：每一层场景的铺满窗口背景层加入编组 "opaque_bg"，reveal 时统一隐藏。
## headless 下安全跳过窗口操作。

const BG_GROUP := "opaque_bg"


## 透出桌面：开窗口逐像素透明 + 透明 viewport + 隐藏所有不透明背景。
## fade_seconds>0 时背景渐隐。
static func reveal(scene_root: Node, fade_seconds: float = 1.2) -> void:
	if scene_root == null:
		return
	var tree := scene_root.get_tree()
	if tree == null:
		return
	# 窗口 + viewport 透明（headless 下 DisplayServer 仍可调用，但无可见效果；做个保护）
	if DisplayServer.get_name() != "headless":
		var win := scene_root.get_window()
		if win != null:
			# 全屏模式下逐像素透明无效，切到无边框窗口
			if win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
				win.borderless = true
				win.mode = Window.MODE_WINDOWED
			win.transparent_bg = true
		get_viewport_of(scene_root).transparent_bg = true
		RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))

	# 隐藏背景（渐隐或瞬隐）
	var backgrounds := tree.get_nodes_in_group(BG_GROUP)
	for bg in backgrounds:
		if bg is CanvasItem:
			if fade_seconds > 0.0:
				var tween := scene_root.create_tween()
				tween.tween_property(bg, "modulate:a", 0.0, fade_seconds)
				tween.tween_callback(bg.hide)
			else:
				(bg as CanvasItem).hide()


## 复原：关闭透明、显示背景、恢复清屏色。
static func restore(scene_root: Node) -> void:
	if scene_root == null:
		return
	if DisplayServer.get_name() != "headless":
		var win := scene_root.get_window()
		if win != null:
			win.transparent_bg = false
		get_viewport_of(scene_root).transparent_bg = false
		RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))
	var tree := scene_root.get_tree()
	if tree != null:
		for bg in tree.get_nodes_in_group(BG_GROUP):
			if bg is CanvasItem:
				(bg as CanvasItem).show()
				(bg as CanvasItem).modulate.a = 1.0


static func get_viewport_of(node: Node) -> Viewport:
	return node.get_viewport()
