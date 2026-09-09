# Enemy System Architecture

本文是 MVP 敌人系统的长期交接入口。修改敌人 AI、攻击、反应、动画、受击区域、刷怪或波次推进前，必须先阅读本文件、仓库根目录 `AGENTS.md`、`SYSTEM_CONTRACTS.md` 和 `PLAYER_SYSTEM.md`。

## 不可破坏的合同

- Godot 工具只使用 `http://localhost:19080/mcp`。19080 不可用时停止 Godot 工作并通知用户，不得切换端口。
- 敌人玩法根节点是 `EnemyBase extends CharacterBody3D`，正式场景为 `res://scenes/characters/enemies/enemy_stub.tscn`。
- 敌人参数唯一入口是 `res://resources/gameplay/enemies/*.tres`，不得在动画中另写动作阶段秒数。
- 一次性动作使用同一份 `ActionTimingDefinition` 四阶段合同：`windup / release / impact / recovery`。玩法生效点是 `windup + release`。
- 敌人硬直由共享 `staggered` 状态管理，不增加第二套敌人专属硬直计时器。
- 普通受击只产生后仰/踉跄动画，`knockback_force` 必须保持为 `0`，不得产生物理打飞。
- `F` 推搡和 `Q` 成功招架必须中断攻击、播放各自旧动画并产生碰撞约束下的物理击退。
- 招架反击在敌人攻击命中的同步调用栈内发生。返回攻击函数后必须检查敌人是否已进入 `HURT`，禁止 `attack_impact` 覆盖 `PARRIED`。
- 击退通过 `velocity + move_and_slide()` 完成，不直接修改坐标，不得穿墙。
- 不修改 `character_test_lab/`；它不是正式敌人或玩家资产来源。

## 运行时结构

| 职责 | 文件 |
|---|---|
| 敌人状态、目标、攻击、受击、击退、死亡 | `res://scripts/characters/enemies/enemy_base.gd` |
| 程序化模型和四种敌人外观差异 | `res://scripts/characters/enemies/enemy_visual_rig.gd` |
| 待机、移动、攻击、重击和反应动画 | `res://scripts/characters/enemies/enemy_animation_controller.gd` |
| 头部受击标签 | `res://scripts/characters/enemies/enemy_hit_zone.gd` |
| 敌人数据合同 | `res://scripts/resources/enemy_definition.gd` |
| 固定波次数据合同 | `res://scripts/resources/wave_definition.gd`、`wave_enemy_entry.gd` |
| 刷怪、死亡统计和清场推进 | `res://scripts/systems/run/wave_director.gd` |
| 推搡事件来源 | `res://scripts/characters/player/player_combat_driver.gd` |
| 招架反击事件来源 | `res://scripts/characters/player/player_3d_controller.gd` |
| 推搡/招架权威数值 | `res://resources/gameplay/player/mvp_player_combat.tres` |

`enemy_stub.tscn` 当前包含身体胶囊、独立 `HeadHitZone`、`EnemyVisualRig`、`EnemyAnimationController`、`HealthComponent` 和 `StatusContainer`。不要把头部碰撞重新合并到躯干胶囊。

## 状态与反应

`EnemyBase.State` 当前为 `CHASE / ATTACK / HURT / DEAD`。`HURT` 只是运行状态表达，其持续时间权威仍是 `StatusContainer` 内的 `staggered`。

伤害结算后的语义：

| 来源 | 动画 | 状态持续 | 物理击退 |
|---|---|---|---|
| 普通有效伤害 | `ACTION_HURT` | 敌人 `hurt_timing` | 无 |
| `source_tags` 含 `shove` | `ACTION_SHOVED` | `max(0.35, stagger * 0.05)` | `5.5`，来自玩家战斗资源 |
| `source_tags` 含 `parry` | `ACTION_PARRIED` | `max(0.35, stagger * 0.05)` | `8.0`，来自玩家战斗资源 |

现有旧动画实现位于 `enemy_animation_controller.gd` 的 `_apply_hurt()`、`_apply_shove()`、`_apply_parry()`。它们已经包含后仰、补偿步、武器下坠和武器侧弹开，不要另建一套动画控制器。

反应持续时间通过 `play_reaction(reaction, hurt_timing, duration_override)` 缩放同一动作合同。普通受击不能因为没有物理击退而回到“立正”；推搡和招架也不能在 `staggered` 尚未结束时提前回待机。

## 当前 AI

- 所有敌人使用无导航网格的平面直线追击，并通过 `CharacterBody3D` 碰撞移动。
- `doorbreaker` 按 `preferred_target_tags` 优先选择 `barrier -> base_core -> player`。
- `wet_gunner` 使用不穿透首个碰撞体的 hitscan。
- `armored_scavenger` 是高生命、高伤害的近战敌人。
- `ruptured` 是快速近战敌人，并启用进阶双手重击。

`ruptured` 重击不是每帧随机。AI 按资源中的 `heavy_attack_decision_min/max_seconds` 定时做一次低概率决策，并受最小/最大距离与冷却限制。

`ruptured` 还保留原有站桩普通攻击，并额外拥有一种控制器驱动的追击挥击。两者共用普通攻击冷却，但按 `tracking_attack_probability` 选择；追击挥击的独立四阶段时序和 `AttackMovementDefinition` 都来自 `ruptured.tres`。它只在前摇和出手阶段贴近目标，命中与后摇锁脚。物理移动由 `EnemyBase` 经 `move_and_slide()` 执行，动画仅根据真实速度叠加低权重下半身步态。

重击表现顺序：半蹲蓄力、快速抬起双手、视觉跳跃并以高速扑近、在玩家前方短时间减速、双手交叉下砸。移动根节点仍贴地走物理，跳跃只发生在视觉骨架。正式伤害只在下砸 `impact` 起点结算。

飞扑途中伤害窗口被用户明确要求关闭。`enemy_base.gd` 中保留了注释掉的 `_try_resolve_heavy_pounce()` 调用，便于用户以后改回；除非用户再次明确要求，不得取消注释。

## 波次与生命周期

- `WaveDefinition.spawn_entries` 是显式固定刷怪表；`spawn_budget_multiplier` 只是未来扩展口。
- `WaveDirector` 从关卡 `SpawnPoints` 读取出生点，实例化统一 `enemy_stub.tscn` 并绑定对应 `EnemyDefinition`。
- `EventBus.enemy_spawned` 和 `enemy_died` 用于生命周期观察。
- 雨夜倒计时归零不能清除活敌或推进阶段；最后一名敌人死亡后才进入 settlement。
- 正式出生点应位于地表、互不重叠并处于可观察区域。

## 测试入口

所有 Godot 测试必须经 19080 MCP 的 `run_project` 运行。

| 场景 | 覆盖范围 |
|---|---|
| `res://tests/integration/enemy_reaction_smoke.tscn` | 普通受击零击退、完整玩家推搡、完整 Q 招架、同帧动画覆盖保护 |
| `res://tests/integration/combat_buff_resolver_smoke.tscn` | 零伤害 stagger 进入共享 BuffResolver 状态链 |
| `res://tests/integration/enemy_collision_smoke.tscn` | 敌人和玩家碰撞，不穿透 |
| `res://tests/integration/enemy_system_smoke.tscn` | 波次、四类敌人、重击、目标优先级、hitscan 和清场全量合同 |
| `res://tests/manual/enemy_animation_acceptance.tscn` | 四种模型、攻击和 `HURT/SHOVED/PARRIED` 姿态截图 |
| `res://tests/manual/enemy_system_acceptance.tscn` | 第 5 波 11 敌人的人工关卡验收 |

最近一次明确通过：

- `ENEMY_REACTION_SMOKE: PASS`
- `COMBAT_BUFF_RESOLVER_SMOKE: PASS`
- `ENEMY_COLLISION_SMOKE: PASS distance=1.165`
- `ENEMY_ANIMATION_ACCEPTANCE_READY`
- 正式 `mvp_skeleton.tscn` 经 19080 启动 9 秒，无新增运行时错误。

当前测试基础设施问题：19080 的 `run_project` 对 `enemy_system_smoke.tscn` 报告启动成功，但当前编辑器会话没有实例化该测试根节点，也没有输出首条日志；需要下一个任务继续诊断，不能据此声称全量 PASS。`player_system_smoke.tscn` 的既有 `ActionTarget` 是无碰撞 `Node3D`，而玩家近战现为物理射线，因此会在“primary attack did not resolve”处失败；这是独立测试夹具问题。

历史和最新反应截图位于：

- `res://.codex_artifacts/enemy_reaction_acceptance.png`
- `res://.codex_artifacts/enemy_heavy_windup.png`
- `res://.codex_artifacts/enemy_heavy_impact.png`

## 人工验收标准

1. 普通攻击敌人：应短暂后仰踉跄，但角色根节点不得滑退或飞走。
2. `F` 推搡：敌人应向远离玩家方向滑退，保持明显失衡姿态。
3. 敌人近战命中前按 `Q`：出现 `PARRY SUCCESS`，敌人立即中断攻击、武器侧弹开并后退。
4. Q 击退应强于 F；经过约 `0.35s`，敌人仍应保持 `PARRIED`，不能突然立正或切回命中动作。
5. 重击/下砸被 Q 或 F 中断后，不得延迟补伤害。
6. 敌人背靠墙时受到推击或招架，应被墙阻挡，不得穿墙。
7. 四种敌人模型、体态、服装和面容应可直接区分，头部命中应获得资源定义的 headshot 倍率。

## 推荐技能

开始修改前按任务选用并阅读对应技能：`using-godot-prompter`、`gdscript-patterns`、`animation-system`、`state-machine`、`physics-system`、`resource-pattern`、`event-bus`、`godot-testing`。只有明确引入导航时才使用 `ai-navigation`；当前 MVP 明确没有导航网格。
