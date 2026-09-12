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
│   ├── PlayerBodyVisual（分层逃兵模型，肩肘与髋膝关节）
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
│   ├── LoadoutComponent
│   ├── ProfessionComponent
│   └── PlayerSkillComponent
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
├── Visuals
│   ├── PlayerBodyVisual
│   └── WeaponVisualRoot
├── Head
│   ├── Camera3D
│   └── InteractionRayCast3D
├── Components
│   ├── HealthComponent
│   ├── StaminaComponent
│   ├── HungerComponent
│   ├── StatusContainer
│   ├── ProfessionComponent
│   └── PlayerSkillComponent
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
├── player_profession_component.gd
├── player_skill_component.gd
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
- `player_profession_component.gd`：保存本局开局 Perk/职业包选择，应用出生状态、优劣势规则和对共享基础数值的修正。
- `player_skill_component.gd`：管理当前 Perk 主动技能的冷却、充能、消耗、触发请求和 HUD 反馈。
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
| 重击 | `attack_secondary` | 右键触发近战重击；使用独立前摇、出手、命中、后摇合同 |
| 推搡 | `shove` | 消耗 stamina，短距离击退 |
| 主动技能 | `active_skill` | 触发当前 Perk 赋予的唯一主动技能；是否可用由冷却、资源、阶段和行动限制裁决 |
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
- 主动技能只能通过 `PlayerSkillComponent` 发起请求；它可以调用战斗、交互、状态或资源系统，但不能绕过行动限制直接改写玩家速度、生命或输入状态。
- 雨夜阶段强调近战、格挡和推搡；白天阶段强调探索、拾取和风险撤退。

## 并行状态机总览

玩家状态不要做成一个巨大枚举，例如 `RUNNING_WITH_AXE_WHILE_HUNGRY_AND_INTERACTING`。MVP 使用多个并行状态机：

```text
Player
├── LocomotionStateMachine：我在哪里，以及怎样移动
├── CombatStateMachine：我当前怎样攻击、防御或换弹
├── InteractionStateMachine：我正在看什么、用什么、采什么
├── WatchStateMachine：我是否正在查看手表
├── PlayerConditionStateMachine：我是否死亡、硬控、饥饿、濒死
└── PlayerSkillComponent：我本局选择了哪个 Perk，以及主动技能是否能触发
```

### 状态机优先级

当多个状态机同帧提出请求时，按以下顺序裁决：

1. `PlayerConditionStateMachine`：死亡、硬控、眩晕优先级最高，可阻止移动、战斗和交互。
2. `WatchStateMachine`：查看手表时锁定战斗、交互和机动，只保留 walk。
3. `PlayerSkillComponent`：主动技能只在本局 Perk、冷却、资源、阶段和行动限制都允许时发起请求。
4. `CombatStateMachine`：攻击窗口、格挡、推搡、装填可限制移动速度或禁止交互。
5. `InteractionStateMachine`：采集、修理、长按交互可限制武器使用。
6. `LocomotionStateMachine`：在未被上层限制时决定最终速度。

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
- 枪械支持腰射与右键按住 ADS；ADS 为持续叠加姿态，开镜过程中可开火。精度、FOV 和移动速度随开镜比例变化。
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
- `StatusContainer` 只保存已裁决的运行时状态、层数、剩余时间和 Tick 计时；默认同类状态刷新，也可由 `StatusEffectDefinition.stack_policy` 明确覆盖或叠层。
- `PlayerConditionStateMachine` 负责把这些组件状态折算成行动限制、视觉压制和数值惩罚。

### 统一 DamageResolver / BuffResolver

- 攻击、技能、环境和持续伤害只创建原始 `DamageEventData`；攻方倍率、暴击、伤害类型倍率、守方倍率和最终扣血统一由 Autoload `DamageResolver` 裁决。
- 玩家门面保留 `receive_damage()` 作为目标接口，但它只能委托 `DamageResolver`，不得直接调用 `HealthComponent.take_damage()`。
- 状态查找、免疫、持续时间修正、施加、移除、约束汇总和周期效果统一由 Autoload `BuffResolver` 裁决。
- `StatusContainer` 的 `apply_resolved_status()` / `remove_resolved_status()` 是解析器内部提交接口，不是技能、角色或关卡脚本的调用入口。
- 周期掉血由 `BuffResolver` 转换成带来源和伤害类型的 `DamageEventData`，再交给 `DamageResolver`；DOT 不得直接扣生命。
- 玩家和敌人共享同一套状态合同。敌人硬直使用 `staggered` 状态，不维护敌人专属的第二套硬直计时器。
- HUD、音频和调试系统消费 `EventBus.damage_resolved`、`status_applied`、`status_removed` 和 `status_list_changed`，不参与玩法裁决。

### Perk / Profession Skill System

MVP 中“Perk”和“Profession”指同一个开局选择包：玩家在一局开始前选择一个 Perk，例如老兵、工程师或当前的 deserter 原型。UI 可以显示为 Perk，数据资源继续使用 `ProfessionDefinition`，避免同时维护两套概念。

每个 Perk 必须定义：

- 唯一 `profession_id`，显示名和说明文本。
- 共享玩家基础数值引用；所有 Perk 默认使用同一套基础生命、体力、饥饿、移动、战斗和交互数值。
- 一个唯一主动技能，通过 `PlayerActiveSkillDefinition` 描述。
- 0-3 个独特优势，通过 `PerkRuleDefinition` 或 `StatusEffectDefinition` 表达。
- 0-3 个独特劣势，通过 `PerkRuleDefinition` 或 `StatusEffectDefinition` 表达。
- 出生装备、出生物品和出生状态。

Perk 不直接拥有一套独立基础面板。最大生命、最大体力、饥饿消耗、近战伤害、枪械稳定、弹药拾取、交互速度、修理效率等差异，都必须通过优势或劣势中的 modifier 表达。这样平衡时只有一套基础数值来源，Perk 只描述“偏离基础值的规则”。

Perk 优势可以包括：

- 数值优势：提高某类伤害、降低体力消耗、提高资源收益、提高枪械稳定、加快特定交互。
- 状态优势：免疫某些 `status_id`、免疫某些状态类别、降低 debuff 强度或缩短持续时间。
- 行动优势：允许执行特殊交互、特殊修理、特殊武器操作，或在特定阶段放宽某些限制。

Perk 劣势可以包括：

- 数值劣势：降低最大体力、提高饥饿消耗、降低治疗效率、降低某类武器表现。
- 状态劣势：开局携带永久或长时 debuff，或更容易受到某类状态影响。
- 行动劣势：禁用某些动作，例如不能使用枪械、不能滑步、不能 parry、不能维修、不能采集某类资源。

行动禁用必须通过统一的行动裁决层处理：`PlayerConditionStateMachine`、`WatchStateMachine`、`PlayerSkillComponent`、`CombatStateMachine` 和 `InteractionStateMachine` 都查询同一组 action restrictions，而不是在单个输入分支里临时 `return`。被禁用时应触发 HUD 可读反馈，例如 `Action blocked: Engineer cannot use heavy firearms`。

主动技能规则：

- 每个 Perk 只能有一个核心主动技能，MVP 不做技能树。
- 主动技能定义冷却、充能、消耗、允许阶段、允许动作状态、是否打断当前动作、是否需要目标。
- 主动技能效果可以请求战斗、交互、状态或资源系统执行具体行为，例如短时稳定枪械、临时修理加速、清除某类 debuff、制造噪音诱饵。
- 主动技能运行时状态只存在于 `PlayerSkillComponent`，包括剩余冷却、剩余充能和本局临时修正；不要写回共享 `.tres`。
- 主动技能触发失败必须给出原因：冷却中、资源不足、当前阶段不可用、当前动作被锁、Perk 劣势禁用。

Perk 与 Status 的关系：

- 长时 buff/debuff、职业被动标签和 HUD 可见状态优先表达为 `StatusEffectDefinition`。
- 免疫、动作禁用、规则覆盖、主动技能引用等结构化规则优先表达为 `PerkRuleDefinition`。
- 同类状态不叠层；再次施加时覆盖或刷新。
- Perk 规则是本局开局选择，不等于永久成长；永久 meta unlock 只负责解锁可选择的 Perk，不直接修改运行中玩家数值。

## 数据资源

建议新增或复用以下资源定义：

```text
scripts/resources/
├── player_movement_definition.gd
├── player_combat_definition.gd
├── weapon_definition.gd
├── profession_definition.gd
├── player_active_skill_definition.gd
├── perk_rule_definition.gd
└── status_effect_definition.gd

resources/gameplay/player/
├── mvp_player_movement.tres
└── mvp_player_combat.tres

resources/gameplay/professions/
├── deserter.tres
├── veteran.tres
└── engineer.tres

resources/gameplay/player_skills/
├── deserter_charged_beam.tres
├── veteran_focus.tres
└── engineer_field_patch.tres
```

数据建议：

- `PlayerMovementDefinition`：步行速度、冲刺速度、滑步速度、滑步时间、重力倍率、相机灵敏度。
- `PlayerCombatDefinition`：轻攻击三段链、推搡、拦挡窗口、体力消耗、受击硬直参数。
- `WeaponDefinition`：已有武器定义继续负责伤害、射速、弹药、后坐力、近战攻击窗口。
- `ProfessionDefinition`：开局 Perk/职业包；引用共享玩家基础数值，定义出生装备、出生状态、唯一主动技能、0-3 个优势、0-3 个劣势。
- `PlayerActiveSkillDefinition`：主动技能蓝图；定义触发输入、冷却、充能、消耗、阶段限制、动作限制、目标需求和效果 id。主动技能可以表现为热武器式能力，但不是 `WeaponDefinition`，不占背包或武器槽，也不参与拾取、瞄准和装填链路。
- `PerkRuleDefinition`：Perk 优劣势规则；定义数值修正、状态免疫、状态易伤、动作禁用、特殊动作许可和 HUD 文案。
- `StatusEffectDefinition`：状态效果图标、文本、持续时间、数值影响、视野影响、阻断动作列表、是否覆盖同类状态。

注意：

- 运行中可变值不要直接写回共享 Resource；实例状态留在组件或运行时 model。
- `.tres` 只作为设计时和内容配置数据。
- Perk、主动技能和状态定义都是只读蓝图；冷却、已选 Perk、已激活状态、临时免疫和动作锁定都属于本局运行时状态。

## 信号和事件

玩家内部优先使用直接信号：

- `HealthComponent.health_changed` -> Player/HUD adapter
- `StaminaComponent.stamina_changed` -> Player/HUD adapter
- `InteractionRayCast3D` focus change -> `InteractionStateMachine`
- 具体状态 `entered` / `exited` -> 动画、音频、调试 UI
- `PlayerSkillComponent.active_skill_ready_changed` -> HUD skill adapter
- `PlayerSkillComponent.action_blocked` -> HUD notice adapter

跨系统使用 `EventBus`：

- `player_health_changed(current, maximum)`
- `player_stamina_changed(current, maximum)`
- `hunger_changed(current, maximum)`
- `interaction_prompt_changed(prompt)`
- `player_perk_selected(perk_id)`
- `player_active_skill_changed(skill_id, cooldown_remaining, charges)`
- `player_active_skill_triggered(skill_id)`
- `player_action_blocked(action_id, reason_id)`
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
| `daylight` | 探索、采集、拾取、撤退 | 允许远距离探索，资源交互完整开启；探索/采集类 Perk 主动技能优先在此阶段可用 |
| `preparation` | 治疗、整理装备、补给 | 修理流程预留，MVP 不作为主线；工程/整备类 Perk 主动技能优先在此阶段可用 |
| `rain` | 防守、近战、格挡、推搡、稀缺枪械 | 敌人压力开启，修理受风险限制；战斗类 Perk 主动技能优先在此阶段可用 |
| `settlement` | 结算、奖励、轻量选择 | 禁止移动战斗或切换到结算控制 |
| `failed` / `complete` | 失败或通关 | 玩家进入 `Disabled` 或结果界面 |

## 动画和音频接入

MVP 可以先用占位 Mesh 和音效，但接口应提前留好：

- Locomotion 状态进入时播放脚步节奏、呼吸、滑步音效。
- Combat 状态进入时启动统一动作时间合同，并按前摇、出手、命中、后摇阶段播放动画和音效。
- Interaction 状态进入时播放采集、修理、拾取反馈。
- Condition 状态变化时播放受击、濒死、死亡反馈。
- 动画不得反向驱动 gameplay 裁决；命中窗口由状态机按共享时间合同推进，动画事件只允许播放纯表现效果。
- HUD 需要显示当前全部 active 状态的文本与持续时间 bar。

### 动作时间合同

所有一次性动作使用 `res://scripts/resources/action_timing_definition.gd` 定义的 `ActionTimingDefinition`。合同只有以下四个连续阶段：

| 阶段 | 字段 | 玩法语义 | 动画语义 |
|---|---|---|---|
| 前摇 | `windup_seconds` | 动作已经锁定，但尚未生效 | 从常态进入蓄力、举起或准备姿态 |
| 出手 | `release_seconds` | 动作正在释放，仍未结算命中 | 从准备姿态快速运动到接触姿态 |
| 命中 | `impact_seconds` | 阶段起点结算伤害、射线、弹药、装填或交互 | 保持动作峰值并播放命中、后坐力等反馈 |
| 后摇 | `recovery_seconds` | 判定关闭，动作仍锁定 | 从峰值姿态恢复到待机或循环姿态 |

时间边界统一为：

```text
0
├─ 前摇结束 / 出手开始: windup
├─ 出手结束 / 命中开始: windup + release   <- gameplay 生效点
├─ 命中结束 / 后摇开始: windup + release + impact
└─ 动作结束: windup + release + impact + recovery
```

状态机和表现层必须持有来自同一 `.tres` 的同一个 Resource 实例，禁止把四个浮点值复制到动画参数、状态机常量或另一份动画资源。动画控制器可以定义不同姿态和 Tween 曲线，但 Tween 每段时长只能读取合同字段。某阶段无意义时设为 `0.0`，不得删除阶段或改用另一套字段。

数值权威入口：

| 动作 | 权威 `.tres` |
|---|---|
| 武器近战、枪械射击、装填 | `res://resources/gameplay/weapons/*.tres` |
| 轻击回退、重击、格挡、推搡、交互、玩家受击 | `res://resources/gameplay/player/mvp_player_combat.tres` |
| 跳跃起步、滑铲、冲刺起步 | `res://resources/gameplay/player/mvp_player_movement.tres` |
| Perk 主动技能 | `res://resources/gameplay/player_skills/*.tres` |
| 敌人攻击、受击、死亡 | `res://resources/gameplay/enemies/*.tres` |

`cooldown`、连击输入窗口、跳跃输入缓存、持续状态时间属于动作之外的规则，继续使用独立字段。循环待机、持续行走和持续冲刺没有有限动作结束点，不使用四阶段合同；它们切入时的一次性动作仍需使用合同。

近战武器可在各自的 `WeaponDefinition` `.tres` 中额外配置 `held_combo_timing`，用于长按轻击时第 2、3 段的较快连段节奏。它仍是完整的四阶段 `ActionTimingDefinition`，状态机与手臂动画必须共享该 Resource 实例；第 1 段继续使用 `primary_timing`。第三段结束后的额外锁定使用 `PlayerCombatDefinition.combo_finisher_cooldown_seconds`，它是独立冷却，不得塞进动作后摇或连击输入窗口。

## 实现拆分建议

1. 保留当前 `player.tscn`，先补 `InteractionRayCast3D` 和 `StateMachines` 容器。
2. 把 `player_3d_controller.gd` 中的输入读取、速度计算、相机旋转逐步拆成小脚本。
3. 先实现 `LocomotionStateMachine`，让当前走、跑、滑步行为通过状态表达。
4. 接入 `InteractionStateMachine`，完成提示、拾取、采集的基础入口，修理作为后续扩展。
5. 接入 `CombatStateMachine`，先做三段近战连击、parry、shove，再接枪械 hip fire。
6. 接入 `PlayerConditionStateMachine`，将死亡、饥饿、体力耗尽、硬直变成统一行动限制。
7. 接入 `ProfessionComponent` 和 `PlayerSkillComponent`，让开局 Perk 选择能应用出生状态、优劣势规则、共享基础数值修正和唯一主动技能。
8. 将速度、体力消耗、攻击窗口、交互时长、Perk 优劣势 modifier、主动技能冷却和动作禁用迁移到 `.tres` 资源。
9. 增加 GUT 测试或最小集成测试，覆盖状态转移、Perk 规则、主动技能冷却、动作禁用和关键信号。

## MVP 验收标准

- 玩家能在白天阶段移动、冲刺、滑步、跳跃、拾取或采集资源。
- 玩家可以按住查看手表，看到 wave 倒计时、地图和 detail 信息，同时只保留 walk。
- 玩家能在雨夜阶段使用三段近战连击、parry、shove 和至少一种枪械 hip fire。
- 玩家能在开局选择一个 Perk；所有 Perk 共用同一套基础数值，但该 Perk 能通过优势/劣势 modifier 改变最终运行数值、提供唯一主动技能，并展示 0-3 个优势和 0-3 个劣势。
- Perk 劣势可以可靠禁用动作，Perk 优势可以可靠免疫或削弱指定 debuff，且所有阻断原因可读。
- HUD 能正确显示生命、体力、饥饿、所有 active 状态文本和持续时间 bar。
- HUD 能显示当前 Perk、主动技能冷却/充能，以及主动技能触发或失败原因。
- 死亡原因可读，并能通过 `GameManager` 或 `EventBus` 进入失败流程。
- 状态机之间没有互相抢写 `velocity` 的问题。
- 新增 gameplay tuning 不需要修改玩家主脚本常量。

## 已确认决策

- 手感目标：移动和攻击都保持“正常”手感，不要偏慢，也不要过分敏捷或过重。
- 玩家幻想：熟练士兵。
- MVP 必须保留：基础移动、近战、远程、跳跃、parry、shove。
- 开局 Perk：玩家开局选择一个 Perk/职业包；所有 Perk 共用同一套基础数值，每个 Perk 有唯一主动技能、0-3 个优势和 0-3 个劣势。
- Perk 示例：老兵偏战斗稳定和短时爆发，工程师偏修理/资源/机关处理；具体数值通过 `.tres` 调整。
- Perk 限制：某些 Perk 可以免疫指定 debuff，某些 Perk 可以禁用指定动作；禁用动作必须走统一行动裁决并给出 HUD 原因。
- 技能范围：MVP 做开局 Perk 主动技能，不做技能树、连线天赋盘或局内升级选技。
- 暂时不做：基地修复主线流程。
- 平衡方向：速度由后续数值调；每一波都要明显消耗饱食度，逼玩家出去；状态影响必须很大，既影响视野，也影响数值，还可以直接禁用某些攻击或移动功能。
- 参考感觉：全面参照 `decaying`。
- 跳跃：有，而且要极轻量。
- 视角：第一人称。
- 枪械：清晰、利落的腰射与 ADS；半固定上扬后坐，移动与空中散布，距离衰减；整匣或逐发装填。枪械仍是稀缺爆发来源。

### 枪械手感第一版

- 正式 HUD 与独立靶场共用 `res://scenes/ui/aim_hud.tscn`，调参入口为 `res://resources/ui/aim_hud.tres`。中心点固定；四条外框短线按实际散布与相机 FOV 投影平滑伸缩，并以最多 7 像素小幅跟随已施加的枪身回弹。外框是精度与冲击反馈，不改变射线。
- ADS 隐藏中心点和外框；换弹、冲刺保留中心点；空手、近战共用中心点；有效交互焦点显示细圆环，文字位于中心下方。瞄到敌人不改变颜色。手表、隐藏 HUD、死亡时清除命中提示。
- 命中提示独立固定在屏幕中心，白色分段 X 为命中，金色分段 X 加圆环为爆头，红色加粗 X 为击杀；持续时间依次为 0.12/0.20/0.30 秒。同级刷新，高级覆盖低级，低级等待高级提示自然结束。`DamageResolutionData.killed` 在伤害生效后、目标回调前记录，不依赖靶子回血或敌人释放后的状态。

- 相机后坐使用 `recoil_target` / `recoil_offset` 双状态；开火只累加目标，渲染帧按 `recoil_response_seconds`（默认 0.03 秒）无过冲追随。`recoil_limit_degrees` 限制双轴累积。反向鼠标输入同步消耗当前和待生效后坐，超量部分正常转动视角。
- 枪身按基础姿态 → ADS 对齐 → 肩肘手链回弹叠加；每发沿同一个 `primary_timing` 实例的命中阶段建立冲击、后摇阶段恢复。`viewmodel_pitch_degrees`、`viewmodel_yaw_degrees`、`viewmodel_ads_multiplier`、`viewmodel_recoil_limit` 控制旋转、开镜表现与累积上限。
- ADS 隐藏固定十字，保留独立命中提示。机械瞄具可暂时偏离中心；射线仍沿相机实际方向，不将枪身视觉偏移加入伤害散布。每发记录当时的冲击倍率，恢复倍率实时作用于剩余相机后坐；切枪丢弃待施加冲击，已有相机偏移平滑收敛，死亡清空。

- `WeaponDefinition` 与四把武器 `.tres` 是射速、精度、后坐、射程和 ADS 的调参入口。运行中后坐、弹匣和散布保存在组件，不改写资源。
- 射击与每次装填均使用原有四阶段合同，弹药扣除、射线和装填转移只在命中阶段起点发生。`fire_interval_seconds` 是独立射击冷却。
- 霰弹枪每次合同装一发并循环；切枪、开火、受击、交互可打断，已装入的子弹保留。奔跑不会打断已经开始的换弹，但奔跑中不能开始换弹。
- Buff 通过约束链提供 `firearm_fire_rate_multiplier`、`firearm_recoil_multiplier`、`firearm_recoil_recovery_multiplier`、`firearm_viewmodel_recoil_multiplier`。倍率只作用于运行时，不写回共享武器资源。
- 默认独立枪械容量为 4，空手与近战不占枪械容量。普通背包四格与特殊弹药库存不变。
- 测试入口：`res://scenes/tests/firearm_range.tscn`。正式玩家、四种枪械、10/25/50 米部位靶，25 米靶移动；弹药充足且靶子自动恢复。
- 第一人称枪模为占位几何体，始终挂在右手武器插槽；正式模型、专用手枪和霰弹枪音色仍待替换。
- 近战：三段轻攻击连击，长按推进连击，第 3 段伤害翻倍。
- 饥饿：MVP 只影响攻击伤害。
- 状态：不叠层；同类状态覆盖或刷新；全部状态都要显示，MVP 先用文本和持续时间 bar。
- 查看手表：按住进入，松开退出；释放鼠标；仅 walk 可用；显示 wave 倒计时、地图和 detail 面板。
