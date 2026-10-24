# 第一轮参考资料研究

研究日期：2026-10-25。本报告研究本地数据，不将这些文件等同于原作完整源码。未运行原作，所有“运行观察”项均为空。原始文件保持只读。

## 资料索引与研究计划

完整路径、字节大小与 SHA256 见 [study-manifest.csv](study-manifest.csv)，分类统计见 [study-summary.json](study-summary.json)。审计共9662文件、646509613字节：3378 PNG、3378 import、1132 skel、1132 atlas、587 darkest、25 json、24 times、2 plist、2 txt、1 setup、1 cdt。路径索引包含隐藏文件，拒绝跟随链接。

| 模块 | 文件定位 | 第一轮阅读/后续深挖 |
|---|---|---|
| 技能/角色 | heroes/*/*.info.darkest | 详读 crusader、plague_doctor 的属性、技能、位移、死亡与选择配置；其余按新增机制再读 |
| 技能表现 | 对应 *.art.darkest、anim/、fx/ | 对照上述两个角色及弩手；只读 atlas 元数据，不反编译二进制骨骼 |
| 效果 | effects/base.effects.darkest、mode.effects.darkest | 定位眩晕、毒伤、减益、位移、种族伤害引用；未逐条验证全部效果 |
| 行动演出 | scripts/timescript/*.times | 详读 melee、melee_crit、ranged、friendly_skill、pre_do_skill、post_select_* |
| 镜头/世界 | scripts/camera.darkest、world.darkest、raid_visuals.json | 详读分层距离、镜头及表现镜头配置 |
| 布局 | scripts/layout/screen.raid*、actor_scale、panel.hero、base.popup_text | 详读主要战斗/血条/数字，screen.raid 读取前 130 行；其他布局后续按需研究 |
| 敌人 AI | monsters/skeleton_arbalist/*、raid/ai/base.monster_brains.json | 详读 A 级弩手及其 brain 区块；不推断全部 AI 算法 |
| 上层状态 | scripts/starting_save/*.json、raid_settings.json | 已索引存档分类，详读 raid_settings；存档内容及场景加载器留后续有依赖再研究 |
| 授权/背景 | study/mod介绍网址.txt | 指向官方 Mod 指南，未找到本地 LICENSE/COPYING/版权授权文本 |

下一轮优先补充：演出原型是否需要多人目标构图；若需要再读 ranged_crit、多目标技能和其他弹字布局。若用户之后提供真正宿主源码，先定位解析器、行动入口、lambda 注册点、战斗结束事件，再升级证据等级。不要为形式完整阅读无关城镇资源。

## 证据规则

- L：本地声明/时序文本直接确认，仅证明该文件包含这项配置。
- P：公开第一方资料确认。
- I：依据现象/命名推断；不可当作运行机制。
- U：缺失源码或运行验证，尚未确认。
- O：实际运行观察。本轮无 O 证据。

以下行号相对工作区路径，不代表所有配置已被游戏成功加载，也不证明文件版本与发行版一致。

## 可追踪的数据关系

### 链一：技能规则 → 效果与表现

1. `study/heroes/crusader/crusader.info.darkest:23` 定义 stunning_blow、launch 21、target 12、Stun 1 引用（L）。
2. `study/effects/base.effects.darkest:175` 定义同名效果，chance 100%、stun 1、on_hit true/on_miss false、queue true（L）。queue 的内部排队时机未知（U）。
3. `study/heroes/crusader/crusader.art.darkest:17` 用相同技能 ID 关联 attack_stun、stunning_blow FX 和头部目标特效（L）。
4. `study/heroes/crusader/crusader.info.darkest:13` 与 `art.darkest:15` 同样把 smite 的规则与 attack_sword 表现分开（L）；效果 `Unholy Killer 1` 在 `base.effects.darkest:260` 引用 performer 与 unholy 条件（L）。效果在伤害前后的准确执行点未知（U）。

可借鉴：稳定技能 ID 连接规则和表现；正式工程独立建定义，不解析或复制这些配置。

### 链二：持续效果与复合技能

`study/heroes/plague_doctor/plague_doctor.info.darkest:13` 的 noxious_blast 同时引用 PD Single Blight 1 和 Noxious Debuff 1；`study/effects/base.effects.darkest:1286` 声明 dotPoison 5/duration 3，`:1292` 声明 attack_rating_add -5%/duration 3；对应 `plague_doctor.art.darkest:15` 指向 attack_blast 和目标 FX（L）。同文件 `info:34` 定义治疗与 Cure/Cureself，`:44` 定义扰乱、清尸、眩晕组合（L）。

可借鉴：技能有有序效果列表，表现集中映射。原作的叠层/持续时间扣减点、抵抗公式和死亡处理顺序无法由这几个声明得出（U）。本项目明确自行设计。

### 链三：敌人 → 技能 → AI

`study/monsters/skeleton_arbalist/skeleton_arbalist_A/skeleton_arbalist_A.info.darkest:4-9` 声明后排 crossbow_shot、前排 bayonet_jab、每轮一次行动及 skeleton_arbalist_A brain（L）。`:10` 声明 corpse_A/death_class，暴击有效标志为 False（L）；不能由此推断所有死亡分支。

`study/raid/ai/base.monster_brains.json:4667-4707` 为同 ID 配置两项 specific_skill 权重、random_target 和 crossbow_shot 对 marked_target 的偏好（L）；`art.darkest:2-3` 配置两项技能的动画及 FX（L）。权重最终如何归一化、合法目标何时过滤、随机数如何使用，没有执行器源码（U）。

可借鉴：合法动作生成与 AI 评分分开。本项目先过滤合法动作，再评分；不用 UI 点击驱动 AI。

## 演出与镜头

`study/scripts/timescript/melee.times`：

| 行 | 直接可见的声明（L） | 本项目启示 |
|---|---|---|
| 3–17 | group 内镜头 zoom/blend、景深相关层参数、HUD alpha/update | 多通道共用时间轴，不能各自抢相机 |
| 20–36 | 攻击者/目标偏移，中心和 offset 表达式，最多 target4 | 战斗阵位与演出临时站位分开 |
| 38–45 | scale/wash_colour lock，presentation_camera.zoom | 演出显式拥有变换，退出后必须归还 |
| 47–48 | 注释 result popup 与 on_zoom_start_lambda | 结果展示存在回调入口；不证明这时才计算伤害 |
| 51–66 | tilt/shudder、riposte lambda、双方漂移 | 冲击、持势、反击协调，而非单一角色位移 |
| 68–94 | finish lambda、track 恢复、HUD 恢复、unlock | 完成屏障要覆盖镜头、角色、UI，不能只等攻击帧 |

该文本含 0.085、1.272、0.255、0.340 等时间参数，但 group、默认时长和 lambda 宿主未提供，不能把数值简单相加宣称实际总时长。

`melee_crit.times:7-15,45,51-53` 与普通近战相比，缩放/去饱和/模糊/震动参数不同（L）。`ranged.times:45,58-64` 使用不同缩放与漂移表达式（L）。`friendly_skill.times:19-26,39-55` 保留友方目标偏移与结果回调（L）。因此至少按近战、远程、支援和暴击调节表现，而不硬套一个模板。

`pre_do_skill.times:1-5` 含隐藏公告、0.25 wait、隐藏目标；`post_select_target.times:1-3` 显示目标并等待 1.45；`post_select_skill.times:1-2` 连续两次 show_announcement（L）。文件名称暗示选择与行动阶段关系（I），但没有调用这些脚本的代码，实际顺序未确认（U）；不能将重复行直接断言为 bug。

`scripts/camera.darkest:1-33` 分走廊、房间和 presentation camera；`world.darkest:2-8` 分前、中、远景距离（L）。这支持“空间分层 + 演出镜头”的概念；没有证据要求本项目复刻其 3D 投影或具体 FOV。

## UI 与流程边界

- `scripts/layout/screen.raid.darkest:2,12,17-25` 有安全区、panel_top、actor_spacing、双方 overlay 起点/间隔与淡入淡出（L）。参考布局出现 960 中心值，不代表可直接翻倍得到合格 4K UI。
- `screen.raid.status_bars.darkest:1-20` 有不同宽度血条、伤害与治疗延迟/插值、独立 tooltip 热区和状态图标位置（L）。信息区不应绑定美术画布边界。
- `actor_scale.raid.darkest:1` 有 turnscale 1.05 等行动强调参数（L）。
- `base.popup_text.layout.darkest:24-47,81-109` 为 miss、普通/暴击伤害、治疗、抵抗和状态分别定义弹字时长与偏移（L）。采用分级弹字队列，避免重叠。
- `screen.raid.battle.darkest:15,20` 有 roll_initiative_time 和 victory_narration_wait_time（L），仅为表现配置，不包含先攻公式或胜负状态机（U）。
- starting_save 的 roster/raid/map/game/estate 等文件名证明存在数据分类（L），不足以证明其存档架构、迁移和生命周期（U）。

## 公开资料与许可

[Red Hook 官方 Mod 指南](https://steamcommunity.com/sharedfiles/filedetails/?id=819597757)解释 launch 为技能可发动阵位，target 的 @/~/? 分别关联友方、全部指定阵位与随机指定目标；也说明原作采用 Spine 动画（P）。访问日期 2026-10-25；这些解释补足本地字段语义，不说明当前本地文件版本来源。指南的 Mod 说明未提供本项目独立游戏素材复用许可。本地未发现明确许可文本，故全部参考美术标记 **unknown / research-only / 禁止集成**。

## 第一轮结论与未确认项

采用：规则/美术分离、效果列表、阵位合法性、统一演出调度、镜头单一控制者、信息层独立恢复、资源 ID。

不照搬：参考脚本/配置、隐藏 HUD 的完整方式、二进制 Spine 管线、特定数值、复杂压力/死亡之门/尸体系统。它们没有当前必要依赖，或缺少可验证执行语义。

待证：先攻随机范围及平手规则、命中上下限/隐藏修正、暴击伤害舍入、状态叠加与触发时机、死亡/反击/胜负优先级、timescript 解析执行及回调调用栈、资源缓存与卸载、场景切换、实际音效同步。上述缺口不阻塞独立原创规则的设计，但不应再称为“原作已验证机制”。
