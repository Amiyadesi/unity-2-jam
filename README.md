# unity2jam

## 这是什么

4 天 Unity2 Game Jam 项目。当前仓库是 Godot 4.6 项目骨架，后续会围绕 Unity2.Ai API 做一个可试玩的小游戏原型。

一句话描述：玩家在短时间循环里和自己的残影协作/对抗，利用 Unity2.Ai 生成关卡提示、失败吐槽或动态谜题文本。

## 怎么跑

1. clone 仓库

   ```bash
   git clone https://github.com/Amiyadesi/unity-2-jam.git
   cd unity-2-jam
   ```

2. 安装 Python 辅助脚本依赖

   ```bash
   pip install -r requirements.txt
   ```

   当前辅助脚本只用 Python 标准库，所以这一步不会安装额外包。

3. 配置 Unity2.Ai API key

   ```bash
   cp .env.example .env
   ```

   然后编辑 `.env`。你有两个 key 时都填上：

   ```env
   UNITY2_PROFILE=codex
   UNITY2_BASE_URL=https://api.unity2.ai/v1

   UNITY2_CODEX_API_KEY=你的_Codex_Key
   UNITY2_CODEX_MODEL=你的_Codex_可用模型名

   UNITY2_CLAUDE_CODE_API_KEY=你的_Claude_Code_Key
   UNITY2_CLAUDE_CODE_MODEL=你的_Claude_Code_可用模型名
   ```

   如果 Unity2.Ai 控制台显示的 API Base URL 不同，以控制台为准。

4. 验证 API 配置

   ```bash
   python tools/unity2_smoke_test.py --profile codex --dry-run
   python tools/unity2_smoke_test.py --profile claude_code --dry-run
   python tools/unity2_smoke_test.py --profile codex
   python tools/unity2_smoke_test.py --profile claude_code
   ```

5. 运行游戏

   - 安装 Godot 4.6 或兼容版本。
   - 打开 Godot，导入本仓库的 `project.godot`。
   - 点击运行。游戏主体完成后会在这里补充具体入口场景和操作说明。

## 用了什么

- 引擎：Godot 4.6
- Unity2.Ai API：计划使用 OpenAI-compatible Chat Completions 风格接口
- API key profiles：`codex`、`claude_code`
- 主要功能规划：
  - 动态关卡提示
  - 失败后的短句反馈
  - 可选的关卡种子/谜题文本生成

## AI 使用说明

- AI 辅助：
  - README、环境模板、Unity2.Ai smoke test 脚本由 AI 辅助起草。
  - 后续会把使用 AI 生成或辅助修改的代码/素材继续记录在本节。
- 自己完成：
  - 游戏设计取舍、玩法调参、最终关卡内容、提交版本验收。

## 提交信息

- GitHub Public 链接：https://github.com/Amiyadesi/unity-2-jam
- Unity2.Ai 官网：https://unity2.ai/

## 参赛备注

- 真实 API key 不会提交到仓库，`.env` 已加入 `.gitignore`。
- 作品提交前会补充：
  - 游戏截图或演示视频链接
  - 完整操作说明
  - 已使用的 Unity2.Ai 模型名
  - AI 辅助范围说明
