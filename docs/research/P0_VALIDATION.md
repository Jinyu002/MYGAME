# P0 验证记录

日期：2026-10-25（Asia/Shanghai）。环境：Windows PowerShell，本地工作区 `E:/AIProjects/Dark/新建游戏项目`。

| 检查 | 实际执行/证据 | 结果 |
|---|---|---|
| 引擎身份 | Godot exe `--version` | 4.7.2.stable.steam.ed1daf0bf |
| 连接会话 | Godot MCP session_manage/list | sessions=[]；未执行场景 |
| 业务文件 | rg枚举正式区与project.godot | 无主场景、无现有战斗逻辑 |
| 资料基线 | `& ./tools/audit-study.ps1` | 9662文件、646509613字节；写出完整CSV索引及扩展名统计 |
| 资料复核 | `& ./tools/audit-study.ps1 -Verify` | PASS：9662文件路径、大小、SHA256完全一致 |
| 资料边界 | 显式枚举，无链接目录；未调用引擎导入 | 研究输出只写docs/research；已有import保留 |
| 本地授权 | 搜索LICENSE/license类文件及资料入口 | 未发现独立原创游戏复用许可；参考素材0项获准集成 |
| 版本管理 | Git 2.41.0；git init | 工作区仓库已初始化；正式文件与文档纳入，study忽略 |

注：哈希复核证明本次两次审计间的文件内容一致，不是操作系统只读权限证明；不能追溯基线前其他软件产生的.import。本阶段未对study设置文件属性或ACL。

文档链接检查第一次发现尚未生成的本文件链接，补齐后再次检查：12份Markdown文档，0个失效本地链接。Git暂存差异检查 `diff --cached --check` 通过；study未暂存，根默认icon的导入元数据仅保留本地并忽略。

Git初始化后普通终端发生setup refresh启动错误；备用Node环境也未能启动。获准使用提升后的终端完成检查；因沙箱用户与终端用户不同，Git报告ownership差异，使用仅限单条命令的 `-c safe.directory=<本工作区>` 处理，没有修改全局Git配置。最终提交见仓库历史。

**未执行**：战斗逻辑/状态机测试、场景运行、UI交互、A/B资源替换、4K/QHD渲染、全屏切换、性能和人工平衡。原因是本阶段没有实施游戏业务。对应验收计划在TESTING.md，不能标记为通过。
