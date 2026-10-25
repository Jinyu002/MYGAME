# 原创 RPG · 战斗垂直切片

长期原创 RPG 项目。当前已实现本地可测试战斗 Demo v0.3。交付日期：2026-10-25。

## 立即体验

双击工作区根目录 **[Start-Demo.cmd](Start-Demo.cmd)**。启动器使用本机Godot 4.7.2，只导入/运行 `game/`。也可在Godot项目管理器中导入 `game/project.godot` 后按F6/F5运行主场景。

四名英雄对四名敌人：选技能 → 点击角色 → 确认。`1–3`技能、`Q/E`换位、`G`坚守、空格确认、Esc设置/暂停、F11全屏。可自动战斗、切换速度/震动/声音，在设置中切换守卫外观验证素材替换。支持胜负、撤退、重试和返回标题。

这是使用参考美术的功能与表现测试版，非正式发行版。待机暂用完整防御姿态，背景为程序绘制；正式美术、复杂动画与数值难度还需迭代。参考素材按用户本次明确授权用于本地测试，原文件不变。

开发者运行自动回归：`powershell -ExecutionPolicy Bypass -File tools/test-demo.ps1`。图形演出验收：`powershell -ExecutionPolicy Bypass -File tools/test-render.ps1 -Resolution 3840x2160`。测试结果和当前限制见 [Demo交付记录](docs/DEMO_DELIVERY.md)。

## 从这里开始

1. [第一阶段成果与现状](docs/PROJECT_STATUS.md)
2. [参考资料研究、证据与缺口](docs/research/REFERENCE_RESEARCH.md)
3. [战斗设计与初始数值](docs/GAME_DESIGN.md)
4. [技术架构与接口](docs/ARCHITECTURE.md)
5. [原创美术规范与分批需求](docs/ART_SPEC.md)
6. [路线图](docs/ROADMAP.md)、[TODO](docs/TODO.md)、[测试与验收](docs/TESTING.md)
7. [架构决策](docs/adr/0001-foundation.md)、[长期代理规则](AGENTS.md)

## 工程边界

`study/` 是绝对只读参考库，禁止原地导入或改写。根 `project.godot` 是旧空工程且包含 study 在扫描范围内，保留原文件，但不要用它启动导入。正式工程已建立于 `game/project.godot`；研究输出在 `docs/research/`，脚本在 `tools/`。美术处理脚本只读取study并在game写出PNG副本，不复制业务配置或脚本。

已核实本机 Godot：`E:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`，版本 `4.7.2.stable.steam.ed1daf0bf`。Git：`D:/Git/cmd/git.exe`。启动脚本支持用 `-GodotPath` 覆盖路径。中文字体使用系统字体，不复制Windows字体到项目。

在工作区运行只读资料审计：

```powershell
& ./tools/audit-study.ps1 -Verify
```

`study-manifest.csv` 是资料路径/大小/SHA256 索引，不包含素材或配置正文。首次生成后不得静默重建。若用户更新参考资料，先记录差异及授权，再单独建立新版本基线。

目前不需要用户立即制作资源。请先体验战斗节奏、阵位、技能与界面；原创角色试制规格仍见美术文档。v0.1研究文档是历史设计基线，v0.2切片实现见ADR 0002，v0.3原作式特写演出见 [ADR 0003](docs/adr/0003-action-tableau.md)。
