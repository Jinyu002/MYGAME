# 技术架构 v0.1

> v0.5：HUD布局与只读详情抽至app/battle_hud.gd，main保留指令和演出协调；HUD接收shown快照，浏览角色/悬停技能不写规则状态。见 [UI重构记录](research/UI_REBUILD_05.md)。

> v0.4已实施：main登记反馈Tween并显式暂停/变速/释放，ActorView有独立表现时钟开关；不用全局SceneTree暂停。导演按after快照恢复死亡可见性和最终阵位，暴击为基础profile修饰，contact_gaps为技能表现配置。规则增加可选sure_hit并让必暴预览包含1.5倍修正。见 [迭代说明](research/PRESENTATION_ITERATION_04.md)。未引入多段事件架构。

> 2026-10-26演出专项决策：保留确定性规则和已结算记录接口；先修表现时钟与恢复语义，再做局部镜头/反馈优化。多段事件接口仅为待确认方案，未实现。见 [优化方案](research/PRESENTATION_OPTIMIZATION_PLAN.md)。

> v0.3已实施：独立game工程、规则内核、UI、Camera2D、Director、资源映射及测试已存在。具体实现采用JSON定义和独立Dictionary状态，其他差异与当前边界见 [ADR 0002](adr/0002-playable-demo.md)；下文为原设计基线，不应把其中全部计划当成已实现。

状态：设计，未声称任何模块已实现。依据见研究报告与 ADR 0001。

## 工程与技术路线

正式工程新建于 `game/`，Godot 4.7.2 + typed GDScript，2D 分层场景 + Camera2D + CanvasLayer HUD。初始使用 Compatibility 渲染做轻量 2D 原型；若实测特效限制再以 ADR 升级，绝不静默更改现有根工程。无第三方 Spine 运行库依赖。

```text
game/                       # 下一阶段才建立
  project.godot
  app/                      # 启动、战斗入口、结果返回
  battle/domain/            # 定义、状态、合法性、结算、轮次、AI
  battle/presentation/      # actor_view、演出调度、镜头、FX/音效
  battle/ui/                # 输入/预览、HUD、结果、设置
  content/                  # 独立定义的 .tres 数据
  assets/                   # 已登记许可的美术/字体/音频
  tests/                    # 无图形规则测试与场景集成测试
docs/ tools/ study/         # 不在正式 res:// 内
```

不创建 world/quest/inventory 等空模块。暂不引入全局事件总线或 ECS；只有应用入口持有战斗会话，局部 signal 连接表现与控制器。

## 数据与依赖

Resource 定义（ActorDefinition、SkillDefinition、StatusDefinition）作为只读配置；战斗状态用独立 RefCounted 对象，不能写回共享 Resource。Definitions 用稳定 ASCII ID 和 schema_version；中文显示名独立。载入时验证唯一 ID、引用、阵位集合、概率范围、伤害区间、剩余次数、状态枚举、演出配置和资源许可登记。

BattleState 包含 battle_id、revision、round、entity 状态、双方阵位列表、当前行动者、队列、使用计数、状态实例、随机流状态与结果。Entity ID 和角色定义 ID 不同，同类敌人可有多个实例。规则状态中不出现 Node、Texture 或磁盘路径。

```text
UI/AI → BattleCommand → BattleController → BattleRules
                                  ↓           ↓
                       状态机与输入屏障    ActionRecord + 新状态
                                  ↓           ↓
                       PresentationDirector → ActorView / CameraRig / HUD
                                  ↓
                        BattleResult → AppFlow
```

演出表现不能调用 apply_damage。规则提交一次后，UI 按 ActionRecord 播放旧到新状态的变化；暂停/快进/超时只能改变表现速度，不可重复规则计算。

## 输入输出契约

| 数据 | 必要字段/约束 |
|---|---|
| BattleRequest | schema_version、battle_id、seed、encounter_id、双方参与者快照（entity_id、definition_id、HP、技能、rank）、规则版本；复制输入，不引用上层可变对象 |
| BattleCommand | command_id、battle_id、expected_revision、actor_id、skill_id、target_ids 或 move_direction；验证当前行动权与所有目标 |
| ActionRecord | action_id、revision_before/after、事件有序列表、展示前后快照、presentation_id；每事件有event_id/source/target/type/actual_value |
| BattleResult | battle_id、outcome(victory/defeat/draw/retreat/error)、seed、rounds、参与者最终快照、规则版本、日志摘要；只输出一次 |

重复 command_id 返回原结果或明确拒绝，不再次消费 RNG；revision 过期返回 stale_command 并刷新 UI。非法数据启动前阻止进入战斗并列出字段，不让残缺数值进入半场战斗。缺图可降级，缺技能规则必须失败。

确定性范围为相同规则版本/引擎版本/数据/种子/命令序列；跨引擎随机算法稳定性不作保证。保存 replay 时记录版本及命令，未来需要跨版本复现时另设计随机实现。

## 状态机与一致性

`INITIALIZING → ROUND_START → TURN_START → AWAIT_COMMAND/AI_THINK → RESOLVING → PRESENTING → TURN_END → 下一角色/ROUND_START`；任何确定结束结果通过 `ENDING → RESULTS`。TURN_START 的流血/眩晕也产生事件，使用 PRESENTING 后回到对应续点；不能绕过显示。

Controller 在 RESOLVING 原子提交（同步、无 await），随后关闭命令入口直到表现屏障结束。PresentationDirector 为每次播放持有唯一 token 和取消上下文；按数据时间轴驱动准备、impact、结果分组、复位。动画和补间用于具体轨道，不能形成互相等待的回调网。

镜头只有 CameraRig 写变换，接收 Director 的 focus/impact/restore 请求。世界镜头不影响 HUD；弹字用世界坐标投影到专用 HUD 层并钳制安全区。多目标镜头以包围盒拟合，限制1.25倍；过宽时退回全景，不切掉后排。

正常完成、暂停后恢复、跳过、角色视图缺失、超时（原型单行动5秒看门狗）、返回菜单均调用同一 cleanup：停止轨道、恢复默认镜头、按最新状态重建阵位/HP、释放输入锁、确认 token 结束。旧 token 回调忽略。只有 cleanup 完成才发出屏障完成事件；战斗已结束时只去结果页。规则异常输出 error 结果，不擅自重试已提交行动。

## 资源和生命周期

ActorDefinition 仅含 visual_id，VisualManifest 对应 portrait、poses、FX/audio IDs、canvas尺寸、脚底/头/胸/socket、有效包围盒、推荐显示高度与翻转规则。SkillPresentationDefinition 选择 pose/timeline/camera profile，不读取技能规则内部图片路径。

默认独立程序占位：轮廓角色、矢量技能图标、几何场景、程序闪光/粒子/合成音。缺可选姿态回退 idle 并报告一次；缺头像显示 ID 缩写；缺音频静音；缺基本视觉定义显示通用轮廓。缺失记录汇总到开发日志，避免每帧刷屏。

每战预加载此次遭遇引用的表现资源；持有会话级引用，退出释放，连续重试不建立全局永久缓存。不提前预载全角色库。发布包只选择 game 下已登记资源；禁止 res://../study、外部绝对路径和未审核许可文件。

资源替换试验：同一个 visual_id 的 A/B manifest 分别使用两套独立原创/程序图；固定 seed 与命令录制生成完全相同 ActionRecord，截图核对脚底、目标区、头像、接触点与镜头。再移除一张攻击图验证回退，规则结果仍相同。

## 分辨率与性能

设计坐标3840×2160，canvas_items + keep；窗口初始1920×1080（开发便利），验收实际渲染3840×2160/2560×1440。非16:9先留边而非拉伸，原生宽屏延后。字体使用清晰可缩放字体资源，面板用矢量/九宫格，不把1080p画面整体放大。

这是依据 [Godot 多分辨率文档](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) 中 canvas_items 在目标分辨率渲染、keep 保留比例的能力作出的项目选择；访问2026-10-25，实际4.7.2表现仍须本机验证。窗口全屏切换用引擎窗口模式，不改变系统显示分辨率。

性能目标：指定测试机热身后各分辨率采样60秒，95百分位帧耗时≤16.7ms、99百分位≤33.3ms（先关闭VSync做分析，体验测试再开启）；记录GPU/CPU/驱动、窗口模式、显存、导入与首次加载时间。不能拿无渲染 headless 测试证明4K GPU性能。预算以实测纹理内存与包围盒更新成本调整，不先建复杂流式加载。

未来接入：世界流程构造 BattleRequest；成长/装备先计算参与者快照；战斗结果由上层决定持久化。仅定义 schema_version 与纯数据边界，本阶段不实现存档加密、迁移服务或任务事件框架。
