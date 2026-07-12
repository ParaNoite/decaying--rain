# MVP 玩家系统架构

本文档定义 Decaying Rain MVP 阶段的玩家系统目标架构。它不是最终实现清单，而是后续拆分场景、脚本、资源和测试时的对齐合同。

## 目标

- 支撑 MVP 核心循环：白天探索、准备、雨夜防守。
- 让移动、战斗、交互、生存状态可以并行演化，而不是塞进单个超大玩家脚本。
- 复用现有组件：`HealthComponent`、`StaminaComponent`、`HungerComponent`、`StatusContainer`。
- 通过 `EventBus` 通知 HUD、音频、存档、阶段控制等无父子关系系统。
- 将可调数据放进 `resources/` 的 `.tres`，由 `scripts/resources/` 下的 Resource 脚本提供类型。

## 当前锚点

- 玩家场景：`res://scenes/characters/player/player.tscn`
- 当前控制器：`res://scripts/characters/player/player_3d_controller.gd`
- 旧原型路径：`res://scripts/Player/`，除非专项迁移，否则不继续扩展。
- 相关全局信号：`res://scripts/autoloads/event_bus.gd`
- 相关组件：`res://scripts/components/`

## 设计原则

- `Player` 场景只负责组合玩家实体，不直接承载所有 gameplay 规则。
- 父节点向子节点调用方法，子节点向父节点发信号。
- unrelated 系统之间使用 `EventBus`，不要通过硬编码 NodePath 找远处节点。
- 移动、战斗、交互、生存状态使用并行状态机；每个状态机只改自己负责的领域。
- `CharacterBody3D.velocity` 的最终写入由移动状态机/移动控制层统一处理，避免战斗和状态效果同时抢写速度。
- 资源定义只放数据，不放每帧逻辑。

## 目标 Player 节点树

MVP 可先从当前场景逐步演进到以下结构：

```text
Player (CharacterBody3D)
├── CollisionShape3D
├── Visuals (Node3D)
│   ├── BodyMesh
│   ├── ForwardMarker
│   └── WeaponVisualRoot (Node3D)
├── Head (Node3D)
│   ├── Camera3D
│   └── InteractionRayCast3D
├── Sockets (Node3D)
│   ├── RightHandSocket
│   ├── LeftHandSocket
│   └── BackSocket
├── Components (Node)
│   ├── HealthComponent
│   ├── StaminaComponent
│   ├── HungerComponent
│   ├── StatusContainer
│   ├── InventoryComponent
│   └── LoadoutComponent
├── StateMachines (Node)
│   ├── LocomotionStateMachine
│   ├── CombatStateMachine
│   ├── InteractionStateMachine
│   └── PlayerConditionStateMachine
├── Sensors (Node)
│   ├── GroundProbe
│   ├── ThreatProbe
│   └── BaseProximityProbe
├── Timers (Node)
│   ├── SlideCooldownTimer
│   ├── InteractHoldTimer
│   └── DamageIFrameTimer
└── AudioEmitters (Node)
    ├── FootstepPlayer
    ├── BreathPlayer
    └── ActionPlayer
```

### MVP 最小节点树

第一轮实现不需要一次到位。MVP 最小可用结构：

```text
Player (CharacterBody3D)
├── CollisionShape3D
├── BodyMesh
├── ForwardMarker
├── Head
│   ├── Camera3D
│   └── InteractionRayCast3D
├── Components
│   ├── HealthComponent
│   ├── StaminaComponent
│   ├── HungerComponent
│   └── StatusContainer
└── StateMachines
    ├── LocomotionStateMachine
    ├── CombatStateMachine
    └── InteractionStateMachine
```

## 脚本归属

建议路径：

```text
scripts/characters/player/
├── player_3d_controller.gd
├── player_input_reader.gd
├── player_movement_motor.gd
├── player_camera_rig.gd
├── player_combat_driver.gd
├── player_interaction_driver.gd
└── states/
    ├── state.gd
    ├── state_machine.gd
    ├── locomotion/
    ├── combat/
    ├── interaction/
    └── condition/
```

职责划分：

- `player_3d_controller.gd`：玩家实体门面，连接组件、状态机、外部 API，例如 `apply_damage()`。
- `player_input_reader.gd`：读取 `InputMap`，输出当前帧输入快照，不直接移动玩家。
- `player_movement_motor.gd`：统一计算和提交 `velocity`，封装重力、地面检测、速度限制。
- `player_camera_rig.gd`：鼠标视角、相机 pitch/yaw、镜头限制、未来屏幕震动入口。
- `player_combat_driver.gd`：把武器、体力、攻击窗口、命中检测连接起来。
- `player_interaction_driver.gd`：处理 RayCast 聚焦、提示、采集、修理、拾取、使用。
- `states/`：状态机基类和具体状态节点。

## 基础操作

InputMap 统一使用 gameplay 命名，避免依赖 `ui_*`：

| 动作 | 输入名 | MVP 行为 |
|---|---|---|
| 前后左右 | `move_forward` / `move_back` / `move_left` / `move_right` | 地面移动，方向相对玩家朝向 |
| 跳跃 | `jump` | 很容易实现，起跳后进入空中状态 |
| 视角 | mouse motion | yaw 旋转 Player，pitch 旋转 `Head` |
| 冲刺 | `sprint` | 消耗 stamina，提高移动速度 |
| 滑步 | `slide` | 消耗 stamina，短时前冲，有冷却 |
| 查看手表 | `watch` | 按住打开全息手表 UI，松开关闭；显示 wave 倒计时、地图和 detail 面板，释放鼠标 |
| 交互 | `interact` | 聚焦物品、采集、开门、修理、拾取 |
| 普攻 | `attack_primary` | 近战挥击或枪械开火 |
| 拦挡 | `parry` | 近战核心机制，不消耗 stamina，开启判定窗口 |
| 副动作 | `attack_secondary` | 武器副功能预留，MVP 可空置 |
| 推搡 | `shove` | 消耗 stamina，短距离击退 |
| 装填 | `reload` | 枪械装填 |
| 切武器 | `weapon_next` / `weapon_previous` | 在当前 loadout 间切换 |
| 背包 | `inventory` | 打开轻量背包界面 |
| 暂停 | `pause` | 释放鼠标并暂停 |

操作规则：

- 移动、视角和交互检测每帧可用，除非玩家死亡、硬控或暂停。
- 跳跃是低成本动作，属于基础移动的一部分。
- 冲刺和滑步由 stamina 决定是否允许进入。
- 按住 `watch` 时释放鼠标，打开手表 UI，只允许 walk，其余战斗、交互和机动状态全部锁定。
- 攻击、格挡、推搡会向移动状态机提交速度修正请求，而不是直接覆盖 `velocity`。
- 雨夜阶段强调近战、格挡和推搡；白天阶段强调探索、拾取和风险撤退。

## 并行状态机总览

玩家状态不要做成一个巨大枚举，例如 `RUNNING_WITH_AXE_WHILE_HUNGRY_AND_INTERACTING`。MVP 使用多个并行状态机：

```text
Player
├── LocomotionStateMachine：我在哪里，以及怎样移动
├── CombatStateMachine：我当前怎样攻击、防御或换弹
├── InteractionStateMachine：我正在看什么、用什么、采什么
├── WatchStateMachine：我是否正在查看手表
└── PlayerConditionStateMachine：我是否死亡、硬控、饥饿、濒死
```

### 状态机优先级

当多个状态机同帧提出请求时，按以下顺序裁决：

1. `PlayerConditionStateMachine`：死亡、硬控、眩晕优先级最高，可阻止移动、战斗和交互。
2. `WatchStateMachine`：查看手表时锁定战斗、交互和机动，只保留 walk。
3. `CombatStateMachine`：攻击窗口、格挡、推搡、装填可限制移动速度或禁止交互。
4. `InteractionStateMachine`：采集、修理、长按交互可限制武器使用。
5. `LocomotionStateMachine`：在未被上层限制时决定最终速度。

### LocomotionStateMachine

推荐做成层级状态机：

```text
Locomotion
├── Grounded
│   ├── Idle
│   ├── Walk
│   ├── Sprint
│   └── Slide
├── Airborne
│   ├── Jump
│   └── Fall
└── Disabled
```

状态职责：

- `Idle`：无移动输入，摩擦减速，允许交互和攻击。
- `Walk`：基础移动，允许攻击、拾取、轻交互，治疗会打断行走。
- `Sprint`：持续消耗 stamina，禁止装填和精确交互，可被攻击输入打断。
- `Slide`：一次性消耗 stamina，短时间锁定方向，有冷却。
- `Jump`：起跳入口，处理极轻量的空中切换，落地后进入 `Fall` / `Grounded` 收尾流程。
- `Fall`：应用重力，保留水平速度，落地后回到 `Grounded` 子状态。
- `Disabled`：死亡、硬控、过场、暂停时使用。

### WatchStateMachine

```text
Watch
├── Hidden
└── Inspecting
```

状态职责：

- `Hidden`：普通游玩状态，不显示手表 UI。
- `Inspecting`：按住 `watch` 时进入；显示全息手表 UI，释放鼠标，展示 wave 倒计时、地图和 detail 面板；只允许 walk，禁止进入跳跃、冲刺、滑步、战斗、交互和换弹状态。

### CombatStateMachine

推荐做成并行状态机，内部按武器类型分支。MVP 阶段空手和近战武器使用同一套近战状态机，只由当前 `WeaponDefinition` 或空手配置决定伤害、范围、前后摇和动画。

```text
Combat
├── Melee
│   ├── Ready
│   ├── Light1
│   ├── Light2
│   ├── Light3
│   ├── Shove
│   ├── Parry
│   ├── Recover
└── Firearm
    ├── Ready
    ├── Fire
    ├── Reload
    └── Jammed
```

状态职责：

- `Ready`：可进入攻击、拦挡、推搡、换弹或换武器。
- `Light1` / `Light2` / `Light3`：空手、工具、斧头等近战来源共用的三段轻攻击链。长按轻攻击可推进连击，第 3 段伤害翻倍。
- `Shove`：消耗 stamina 的短距离控制动作，优先用于雨夜防守；命中部分敌人时让目标进入短暂 `Staggered`，但对重型、霸体或特定攻击中的敌人可以只造成轻微推退或完全无效。
- `Parry`：核心拦挡机制，不消耗 stamina；进入后打开一个短判定窗口。凡是敌人近战攻击在窗口期内命中玩家，玩家不受伤，攻击者反而进入 `Staggered`。窗口结束后进入 `Recover`，失败拦挡不提供减伤。
- `Recover`：后摇，限制连击、冲刺、连续推搡和连续拦挡。
- `Reload`：消耗时间和弹药资源，可被受击或切武器打断。
- `Jammed`：预留给枪械稀缺和可靠性系统，MVP 可不实现。

近战裁决规则：

- 空手、工具、斧头等近战来源都走 `Melee`，通过数据配置区分伤害和节奏。
- `Parry` 是核心反应机制，成功后玩家不受伤，攻击者进入 `Staggered`。
- `Parry` 的判定窗口短、反馈强，应该比普通格挡更有“读招反制”的意味。
- `Shove` 是主动控制，消耗 stamina，结果取决于敌人的 stagger 抗性。
- `Parry` 不反制远程攻击、环境伤害、持续伤害和非 melee 标记的碰撞。
- 近战连击由输入缓存推进，MVP 先做三段链，第三段伤害翻倍。
- 枪械 MVP 只做 hip fire，不启用独立 `Aim` 状态。
- `Parry` 和 `Shove` 在手表查看状态下都不可用。

### InteractionStateMachine

```text
Interaction
├── None
├── Focus
├── InstantUse
├── HoldUse
├── Looting
├── Harvesting
└── Repairing
```

状态职责：

- `None`：没有可交互目标。
- `Focus`：RayCast 命中 `InteractableComponent`，通过 `EventBus.interaction_prompt_changed` 更新 HUD。
- `InstantUse`：开门、拾取小物件等立即完成的交互。
- `HoldUse`：需要按住的通用交互。
- `Looting`：从资源点或容器取物。
- `Harvesting`：白天采集资源，可能受噪音、耗时、工具影响。
- `Repairing`：预留给后续基地修复流程，MVP 暂不启用。

### PlayerConditionStateMachine

```text
Condition
├── Alive
│   ├── Normal
│   ├── Hungry
│   ├── Exhausted
│   ├── Bleeding
│   └── Staggered
└── Dead
```

职责划分：

- `HealthComponent` 管生命值，只负责数值和死亡信号。
- `StaminaComponent` 管体力，不直接知道移动或战斗状态。
- `HungerComponent` 管饥饿值，向 condition 状态机提供阈值。
- `StatusContainer` 管可见状态，状态不叠层，同类状态再次施加时覆盖或刷新。
- `PlayerConditionStateMachine` 负责把这些组件状态折算成行动限制、视觉压制和数值惩罚。

## 数据资源

建议新增或复用以下资源定义：

```text
scripts/resources/
├── player_movement_definition.gd
├── player_combat_definition.gd
├── weapon_definition.gd
├── profession_definition.gd
└── status_effect_definition.gd

resources/player/
├── mvp_player_movement.tres
├── mvp_player_combat.tres
└── deserter_player_profile.tres
```

数据建议：

- `PlayerMovementDefinition`：步行速度、冲刺速度、滑步速度、滑步时间、重力倍率、相机灵敏度。
- `PlayerCombatDefinition`：轻攻击三段链、推搡、拦挡窗口、体力消耗、受击硬直参数。
- `WeaponDefinition`：已有武器定义继续负责伤害、射速、弹药、后坐力、近战攻击窗口。
- `ProfessionDefinition`：职业初始负重、基础装备、初始饥饿/体力修正。
- `StatusEffectDefinition`：状态效果图标、文本、持续时间、数值影响、视野影响、阻断动作列表、是否覆盖同类状态。

注意：

- 运行中可变值不要直接写回共享 Resource；实例状态留在组件或运行时 model。
- `.tres` 只作为设计时和内容配置数据。

## 信号和事件

玩家内部优先使用直接信号：

- `HealthComponent.health_changed` -> Player/HUD adapter
- `StaminaComponent.stamina_changed` -> Player/HUD adapter
- `InteractionRayCast3D` focus change -> `InteractionStateMachine`
- 具体状态 `entered` / `exited` -> 动画、音频、调试 UI

跨系统使用 `EventBus`：

- `player_health_changed(current, maximum)`
- `player_stamina_changed(current, maximum)`
- `hunger_changed(current, maximum)`
- `interaction_prompt_changed(prompt)`
- `watch_state_changed(active: bool)`
- `wave_timer_changed(remaining_seconds, total_seconds, wave_index)`
- `combat_hit(data: DamageEventData)`
- `status_applied(target_id, status_id)`
- `status_removed(target_id, status_id)`
- `status_list_changed(target_id, statuses)`
- `run_failed(reason)`

建议后续补充：

- `player_died(reason: StringName)`
- `player_weapon_changed(weapon_id: StringName)`
- `player_ammo_changed(current: int, reserve: int)`
- `player_noise_emitted(position: Vector3, radius: float, noise_id: StringName)`

## 阶段约束

| 阶段 | 玩家重点 | 系统约束 |
|---|---|---|
| `daylight` | 探索、采集、拾取、撤退 | 允许远距离探索，资源交互完整开启 |
| `preparation` | 治疗、整理装备、补给 | 修理流程预留，MVP 不作为主线 |
| `rain` | 防守、近战、格挡、推搡、稀缺枪械 | 敌人压力开启，修理受风险限制 |
| `settlement` | 结算、奖励、轻量选择 | 禁止移动战斗或切换到结算控制 |
| `failed` / `complete` | 失败或通关 | 玩家进入 `Disabled` 或结果界面 |

## 动画和音频接入

MVP 可以先用占位 Mesh 和音效，但接口应提前留好：

- Locomotion 状态进入时播放脚步节奏、呼吸、滑步音效。
- Combat 状态进入时播放前摇、命中、格挡、装填音效。
- Interaction 状态进入时播放采集、修理、拾取反馈。
- Condition 状态变化时播放受击、濒死、死亡反馈。
- 动画不要反向驱动 gameplay 裁决；动画事件只用于打开命中窗口、播放效果等时间点。
- HUD 需要显示当前全部 active 状态的文本与持续时间 bar。

## 实现拆分建议

1. 保留当前 `player.tscn`，先补 `InteractionRayCast3D` 和 `StateMachines` 容器。
2. 把 `player_3d_controller.gd` 中的输入读取、速度计算、相机旋转逐步拆成小脚本。
3. 先实现 `LocomotionStateMachine`，让当前走、跑、滑步行为通过状态表达。
4. 接入 `InteractionStateMachine`，完成提示、拾取、采集的基础入口，修理作为后续扩展。
5. 接入 `CombatStateMachine`，先做三段近战连击、parry、shove，再接枪械 hip fire。
6. 接入 `PlayerConditionStateMachine`，将死亡、饥饿、体力耗尽、硬直变成统一行动限制。
7. 将速度、体力消耗、攻击窗口、交互时长迁移到 `.tres` 资源。
8. 增加 GUT 测试或最小集成测试，覆盖状态转移和关键信号。

## MVP 验收标准

- 玩家能在白天阶段移动、冲刺、滑步、跳跃、拾取或采集资源。
- 玩家可以按住查看手表，看到 wave 倒计时、地图和 detail 信息，同时只保留 walk。
- 玩家能在雨夜阶段使用三段近战连击、parry、shove 和至少一种枪械 hip fire。
- HUD 能正确显示生命、体力、饥饿、所有 active 状态文本和持续时间 bar。
- 死亡原因可读，并能通过 `GameManager` 或 `EventBus` 进入失败流程。
- 状态机之间没有互相抢写 `velocity` 的问题。
- 新增 gameplay tuning 不需要修改玩家主脚本常量。

## 已确认决策

- 手感目标：移动和攻击都保持“正常”手感，不要偏慢，也不要过分敏捷或过重。
- 玩家幻想：熟练士兵。
- MVP 必须保留：基础移动、近战、远程、跳跃、parry、shove。
- 暂时不做：基地修复主线流程。
- 平衡方向：速度由后续数值调；每一波都要明显消耗饱食度，逼玩家出去；状态影响必须很大，既影响视野，也影响数值，还可以直接禁用某些攻击或移动功能。
- 参考感觉：全面参照 `decaying`。
- 跳跃：有，而且要极轻量。
- 视角：第一人称。
- 枪械：MVP 先 hip fire。
- 近战：三段轻攻击连击，长按推进连击，第 3 段伤害翻倍。
- 饥饿：MVP 只影响攻击伤害。
- 状态：不叠层；同类状态覆盖或刷新；全部状态都要显示，MVP 先用文本和持续时间 bar。
- 查看手表：按住进入，松开退出；释放鼠标；仅 walk 可用；显示 wave 倒计时、地图和 detail 面板。
