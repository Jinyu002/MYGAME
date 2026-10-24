# 原创 RPG · 战斗垂直切片

长期原创 RPG 项目。第一阶段为研究和规划，尚无可玩的战斗 Demo。当前交付日期：2026-10-25。

## 从这里开始

1. [第一阶段成果与现状](docs/PROJECT_STATUS.md)
2. [参考资料研究、证据与缺口](docs/research/REFERENCE_RESEARCH.md)
3. [战斗设计与初始数值](docs/GAME_DESIGN.md)
4. [技术架构与接口](docs/ARCHITECTURE.md)
5. [原创美术规范与分批需求](docs/ART_SPEC.md)
6. [路线图](docs/ROADMAP.md)、[TODO](docs/TODO.md)、[测试与验收](docs/TESTING.md)
7. [架构决策](docs/adr/0001-foundation.md)、[长期代理规则](AGENTS.md)

## 工程边界

`study/` 是绝对只读参考库，禁止导入、改写或提交到正式资源库。现有根 `project.godot` 是空工程且包含 study 在扫描范围内，保留原文件，但不要用它启动导入。后续正式工程将在 `game/project.godot` 独立建立；该路径目前尚未创建。研究输出在 `docs/research/`，脚本在 `tools/`。

已核实本机 Godot：`E:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`，版本 `4.7.2.stable.steam.ed1daf0bf`。Git：`D:/Git/cmd/git.exe`。当前无主场景，所以暂无游戏启动命令；不要将规划文档当成已实现功能。

在工作区运行只读资料审计：

```powershell
& ./tools/audit-study.ps1 -Verify
```

`study-manifest.csv` 是资料路径/大小/SHA256 索引，不包含素材或配置正文。首次生成后不得静默重建。若用户更新参考资料，先记录差异及授权，再单独建立新版本基线。

第一阶段不需要用户立即制作资源。下一步自主实现确定性战斗规则与测试，再接入演出和 UI；一个原创角色的试制规格见美术文档。第三方参考素材尚未获准集成，使用独立程序占位。
