# 现有战斗演出诊断 · 2026-10-26

> 后续v0.4已修复本文部分问题。本文保留修改前诊断证据；当前实现与实测以 [演出迭代](PRESENTATION_ITERATION_04.md) 为准。

范围：基于 `fbcace0` 朝向修复及后续配置提交的正式 `game/`。用户新增的 MCP 插件与 project.godot 改动保留。本轮不修改正式玩法或表现代码；仅研究、审计工具维护和独立副本实验。

证据标签：**S**＝本地代码静态确认；**R**＝本轮独立运行验证；**H**＝待验证体验假设。参考研究和建议分别见 [DD2研究](DD2_MANAGED_RESEARCH.md)、[优化计划](PRESENTATION_OPTIMIZATION_PLAN.md)。

## 一次行动的实际组织

`main.gd:perform` → `battle_rules.gd:apply` 校验阵位/指令版本并一次性结算，生成 before/after/events → `main.gd:present` 锁输入并显示before → `shot_director.gd:play` 建立特写 → `_impact` 一次性发送记录 → `main.gd:_impact` 更新血条、声音、弹字和死亡淡出 → 导演恢复 → `_presentation_done` 显示after，继续回合或显示结果。

**保留：**规则与现实时间、图片、Tween无关；随机结算不由动画回调触发；before/after用于延后展示而不二次改HP；generation/decision_token防止旧AI计时器污染重试；导演集中控制相机并有skip和看门狗。已有统一调度，但只覆盖了一部分表现生命周期。不能把“需要统一更多时钟”说成“项目完全没有导演”。

## 逐项诊断

| 范围 | 已有合理设计 | 实际问题及扩展影响 | 证据 |
|---|---|---|---|
| 流程与状态 | 独立规则、命令去重、输入屏障、结果闭环 | main约650行同时承担应用流程、界面和反馈。可逐步拆反馈职责，无需重写规则 | S：main perform/present/_presentation_done；rules apply |
| 技能释放 | 解析完整事件列表，明确一次impact | 一个行动只有一个统一命中点；未来多段射击不能只重复impact，否则重复血条/弹字；当前单段技能不必引入通用队列框架 | S：shot_director:122；main:_impact |
| 待机/准备/攻击 | 独立视觉ID、技能姿态、朝向配置 | 待机复用defend；进入play立即换攻击图并重定位，没有独立蓄力/挥出/受击曲线。现有美术不是动画帧序列 | S：actor_view；shot_director:85–96 |
| 命中重量 | 闪光、命中特效、衰减震动、暴击参数 | 受击者只有漂移；miss也走同一漂移。镜头进入85ms后即impact，缺蓄力对比。35/55ms interval后直接开启parallel，持势与该interval同组，不能称为已完成hit-stop | S：shot_director:104–112；最后一点未做帧级轨迹验证 |
| 暂停与变速 | 导演Tween与特效时钟可暂停、变速 | 弹字0.9s、死亡淡出0.35s各建Tween；flash在ActorView每帧衰减。暂停导演不暂停它们，2倍速也不统一 | S：main:330–378、show_pause/toggle_speed；R：暂停探针 |
| 死亡与恢复 | 死亡记录和最终HP正确 | `_restore_pose`无条件恢复所有modulate为白色；已淡出的尸体在收镜阶段重现，最后refresh才隐藏。属于视觉状态错误，并非角色复活或HP错误 | S：shot_director:156–162；R：两组探针均记录重现 |
| 位移与击退 | 阵位与特写临时位置分离，换位有Tween | move分支使用after阵位；lunge/feint/shove仍先返回before的homes再由refresh跳到after阵位。应按移动事件协调归位，不能改变规则位移时机 | S：shot_director:60–70、115、cleanup；main:refresh |
| 镜头与构图 | 单一Camera2D、群体降低zoom、敌我反向、HUD分层 | 按人数而非实际可见包围盒构图；zoom=profile.zoom−0.15×额外人数，中心固定y965；角色高度统一680。大型、矮小、超宽武器可能裁切，目前未证明现有全技能均裁切 | S：shot_director:90–98；H：新美术边界 |
| 暴击 | 有专用更强镜头、震动和提示 | critical覆盖原ranged/support profile，远程暴击gap回到670；虽漂移仍看ranged，镜头语义被替换。推荐暴击作为修饰量而非技能类别 | S：shot_director:54–58；presentation.json |
| 弹字与UI | CanvasLayer不受相机直接缩放，位置clamp保底 | 创建时投影一次，镜头随后漂移/旋转，弹字不跟踪锚点；堆叠标签在边界被clamp到同一y可重叠。固定700×130无法保证长中文/极大数值。不能将现有clamp称为完整安全区布局 | S：main:popup；H：极端文本截图待测 |
| 结束屏障 | 完成/skip统一释放相机，5秒超时兜底 | 屏障未包含反馈Tween；未来长动作被固定5秒截断。当前时长低于阈值，不应先删除看门狗 | S：shot_director:_process/cleanup |
| 4K/QHD/全屏 | 3840×2160逻辑画布、canvas_items、F11切换、已有真4K截图 | 画布坐标不等于真实渲染尺寸；全屏窗口与DPI/超宽屏未全面验收。本轮headless探针不构成视觉/性能验收 | S：project.godot；main:toggle_fullscreen/capture；历史DEMO_DELIVERY |

## 本轮运行验证

执行 `powershell -ExecutionPolicy Bypass -File tools/research/run-pause-probe.ps1`。脚本仅复制自研game内容到随机命名的research_sandbox子目录，删除**副本**MCP配置，避免启动第二个编辑器服务。读取原图副本，不读取或改写study；正式源码不变。

夹具使用合成已结算暴击/死亡记录，在实际impact信号后暂停250ms。首轮夹具未等待初始deferred回合而被覆盖，已修正为等待初始化及真实impact；只采用修正后的结果。

| 观察量 | 当前实现 | 统一场景暂停原型 |
|---|---|---|
| 规则revision | 1→1 | 1→1 |
| 导演elapsed | 0.090665→0.090665 | 0.087630→0.087630 |
| 弹字y | 482.400→457.467 | 482.400→482.400 |
| 死亡alpha | 1→0.287633 | 1→1 |
| 受击flash | 0.65→0 | 0.65→0.65 |
| 暂停后所有取样状态冻结 | 否 | 是 |
| 继续后、导演结束前已淡出角色重新不透明 | 是 | 是，暂停修复不会顺带修复此问题 |

证据：`artifacts/dd2-pause-probe.log`。原型只验证SceneTree暂停机制，设置面板设PROCESS_MODE_ALWAYS；未将恢复快捷键、重试/标题/撤退、音频暂停和所有MCP交互纳入原型，因此**不是可直接合并的完整暂停补丁**。不将headless数值测试说成已观察原版游戏行为。

## 对十个重点问题的结论

1. 已有统一导演；欠缺的是反馈生命周期归属与一致时钟。
2. 存在已复现的暂停不同步、死亡复现；hit-stop分组和高速残留需补帧级验证。
3. 重量感受限于缺少蓄力/受击姿态和速度对比；加震幅只能改善其中一部分。
4. 固定中心和人数估算未充分利用实际角色边界，尚需包围盒原型。
5. 现有680高角色可用，但不能作为所有新角色的统一尺寸；最大特写1.44需纳入资源预算。
6. clamp减少出屏，但不能防长文本裁切、边缘堆叠重叠或锚点漂移。
7. 0.55秒AI等待、固定持势、回合记录0.42秒可能形成重复停顿；先做时间轨迹和人工A/B，不整体加速。
8. 数据和资源映射利于扩展；多段命中、体型差异、动作时长会突破当前单impact及固定构图。
9. 暂停、死亡恢复、暴击修饰、显式顺序阶段和弹字安全区适合局部修正。
10. 多段表现事件流/通用动作队列/动画资源框架才属于较大架构变化，需先确认，不作为本轮自动重构。
