# Plan: 能量槽 + 攻击系统 + 觉醒切换

## Goal

给现有 player (`scripts/player.gd` + `scenes/player.tscn`) 加上：
1. **能量槽**（0–100，觉醒/技能消耗，耗尽自动解除觉醒）
2. **攻击动作**（J = 水平攻击；S+J = 双向攻击；飞行态 = 冲刺攻击）
3. **觉醒切换**（独立键位触发 transform / untransform；消耗能量维持）

这是 stage 2/3 战斗和终战的前置。不做敌人 AI、不做关卡、不做 UI 美化——只做玩家的战斗能力骨架。

## Acceptance Criteria

- [ ] 能量槽：`energy` 属性 0–100，有 `@export` 的消耗/恢复速率
- [ ] 觉醒态持续消耗能量（每秒扣 N 点），耗尽自动 untransform
- [ ] J 键触发水平攻击（播 `cast_forward` 动画 + 发出一个短命 Area2D hitbox）
- [ ] S+J 触发双向攻击（播 `cast_side` 动画 + 左右各一个 hitbox）
- [ ] 飞行态下鼠标左键 = 冲刺（方向=鼠标方向，消耗能量，播 `morph_move` 加速）
- [ ] 攻击 hitbox 对 group "enemy" 造成 1 点 damage（调用 enemy 的 `take_hit()` 或类似）
- [ ] 攻击消耗能量（可配置，默认 J=10, S+J=15, 冲刺=20）
- [ ] 能量不足时攻击/冲刺不触发（或弱化版，可配置）
- [ ] 能量自然恢复（站立/移动时每秒 +N，可配置）
- [ ] 觉醒键位：新增 input action `awaken`（默认 Shift）
- [ ] 敌人接口：给 `scripts/stages/enemy.gd` 加 `take_hit(damage: int)` 方法（减 hp，hp<=0 → defeated signal + 消散）
- [ ] 测试：现有 `tools/test_player.gd` 仍通过（不 break 现有动画）
- [ ] 不改动关卡场景、不做 UI 能量条视觉（后续单独做）

## File Changes

### Modify: `scripts/player.gd`
- 新增 `energy`/`max_energy` 属性 + 消耗/恢复逻辑
- 新增 `_handle_attack()` in `_physics_ground` and `_physics_fly`
- 新增 `_handle_awaken()` toggle
- 飞行态增加鼠标左键冲刺
- 觉醒态每帧消耗能量，耗尽调 `play_action("untransform")`

### Modify: `scripts/stages/enemy.gd`
- 新增 `@export var hp: int = 1`
- 新增 `func take_hit(damage: int)` → hp -= damage; if hp <= 0: _die()
- 现有 `_die()` 已有消散逻辑，复用

### Modify: `project.godot` [input]
- 新增 `awaken` action (Shift left + Shift right)

### Modify: `tools/test_player.gd`
- 确认 energy 属性存在 + 觉醒触发不 crash

## Definition of Done

- `tools/test_player.gd` 通过（headless）
- `tools/test_stages.gd` 通过（stage scenes still instantiate）
- 能在实机运行中按 J 看到攻击动画 + hitbox + 打到 enemy 消散

## Build/Test Commands

```bash
godot --headless --path . --script res://tools/test_player.gd
godot --headless --path . --script res://tools/test_stages.gd
```
