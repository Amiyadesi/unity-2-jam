# AGENT.md — CloseAI 项目 AI 协作规则

最后更新：2026-06-04

## 协作原则

这个项目以作者自己的能力和判断为主。AI 的角色是教、解释、诊断、代做重复性技术活，而不是替作者夺走设计控制权。

- 除非用户明确说"帮我实现 / 写代码 / 修复 / 继续执行计划"，否则默认先讲思路、结构和最小实现路径。
- 用户明确要求实现时，直接完成并验证，不停下来问"要不要继续"。
- 对重要改动要解释核心逻辑，让作者知道以后该在哪里维护。
- 保留作者的设计决定；如果技术实现会冲突，先指出冲突，再给可执行替代方案。
- 不要为了"像 AI 做的"而重做整套结构；优先在现有场景和脚本上小步迭代。
- 场景文件以作者当前手调版本为准。即使 AI 之前生成过某个场景状态，后续也必须在用户已经调整过的基础上继续改，不要把场景回归到 AI 旧版本或"整理"掉用户微调。

## 项目概况

- 引擎：Godot 4.6（**纯 GDScript**，本项目没有 C# 工程；addons 里的 `.gd` autoload 自足）。
- 游戏名：`CloseAI` — 一个关于关闭的游戏。
- 核心机制（**反转式**）：玩家永远无法自己关闭窗口；剧情推进到"关闭时刻"后窗口关闭被**解锁**，AI 引导玩家亲手关闭以推进/告别。玩家中途任何关闭尝试（× / 任务栏）都被拦截并嘲讽；任务管理器强杀 = 脏关闭，下次启动被狠狠嘲讽并戳穿"没用的"。
- 主入口（主场景）：`scenes/boot.tscn`
- 流程：`boot → menu → stage_1/2/3 → ending`
- Godot 验证二进制：`D:\Hopes_and_Dream\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe`

## 当前架构入口

- 全局编排（autoload）：`scripts/autoload/game_flow.gd`（GameFlow）— 关闭拦截/嘲讽、self_close 唯一退出口、pre_self_close 演出钩子、关卡进度、对话辅助。
- 启动：`scripts/boot.gd`；菜单：`scripts/menu.gd`
- 关卡基类与关卡：`scripts/stages/stage_base.gd`、`scripts/stages/stage_1.gd`/`stage_2.gd`/`stage_3.gd`
- 玩家：`scripts/player.gd` + `scenes/player.tscn`（Sprite2D hframes=17 vframes=16，AnimationPlayer 驱动 64x64 帧动画）
- UI：`scripts/ui/`（modal_screen 基类、settings_screen、thanks_screen、ai_hud、close_mock）
- 存档模块（复用 enhance_save_system）：`stats_module`（干净/脏关闭检测）、`app_state_module`（关卡进度 closeai_started/stage/finished）、`settings_module`（音量/显示，默认全屏）、`player_module`、`level_module`。
- 对话：`dialogue/closeai_stage{1,2,3}.dialogue`（锚点 start / dirty_return / close_moment），Dialogue Manager 自定义气球播放。

## 当前稳定约定（重要！）

- **固定脚本、固定资源、固定场景优先。不要把主要功能做成运行时动态生成结构，调试会变困难。**
- **UI / 对话也遵守固定模板原则**：overlay、气球、按钮、提示标签都必须优先来自 `.tscn` 模板；确实需要重复项时只能实例化固定模板场景，**不要在脚本里手搓 UI 节点**（包括临时 ColorRect 闪屏、临时 Label 等——都应做成场景里的固定节点，用代码控制其可见/动画）。
- 对话与提示信息流走 **Dialogue Manager 自定义气球**（toast/hint 非阻塞 + 阻塞对白），不要自己另写一套对话 UI。
- 设置页 / 感谢页 / 暂停页 UI 沿用统一的玻璃/监视器风模板与动效，**不要做成一堆小卡片**；用前端审美（层次、留白、统一描边/圆角/光效）。
- UI 基准分辨率 `1280x720`；默认全屏（SettingsModule display_mode 默认 fullscreen + project.godot window/size/mode=3）。
- 菜单入口打开设置时显示"感谢"入口；游戏内打开设置时隐藏。
- 关闭机制唯一真出口是 `GameFlow.self_close(reason)`；开场/关卡关闭时刻/结局都走它。开场演出接 `GameFlow.register_pre_close_hook()` 或 `pre_self_close` 信号。
- 干净/脏关闭检测复用 `StatsModule.clean_exit` / `had_unclean_exit()`，不要另写 save.dat。

## 验证命令

```powershell
& 'D:\Hopes_and_Dream\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe' --headless --import --path .
& 'D:\Hopes_and_Dream\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe' --headless --path . --script res://tools/test_flow.gd
& 'D:\Hopes_and_Dream\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe' --headless --path . --script res://tools/test_stages.gd
& 'D:\Hopes_and_Dream\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe' --headless --path . --script res://tools/test_mock.gd
& 'D:\Hopes_and_Dream\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe' --headless --path . --script res://tools/test_player.gd
```

已知噪声：
- PhantomCameraManager 编辑器插件在 headless 导入时报 singleton 错误（运行时无关）。
- 测试打印 OK / RESULT 后仍可能因 Godot 资源泄漏清理警告返回非零；判断时看 RESULT 行而非退出码。

## 精灵图

- 主角精灵：`assets/super character spritesheet.png`（uid://0fpwwyonv1c6），17列×16行，每帧 64×64px，每行左对齐。
- 行→动作（frame = 行索引*17 + 列；行索引 = 用户行号-1）：
  idle(行2,frames17-28) / idle_raise(行3,34-45) / walk_raise(行4,51-58) / walk(行5,68-75) /
  crouch(行6,85-87) / standup(行8,119-121) / pickup(行9,136-148) / transform(行10,153-162) /
  morph_idle(行11,170-175) / morph_move=dash(行12,187-195) / untransform(行13,204-212) /
  cast_forward(行14,221-228) / cast_side(行15,238-245) / death(行16,255-271)。
- `art/generated/*` 是全不透明的 AI 概念参考图，不是可用精灵表。
