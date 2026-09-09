# 敌人攻击移动的业内实践

本文记录近战敌人在攻击期间是否移动、以及移动时脚部动画如何处理的通用技术路线。它是设计与实现的决策依据，不替代 `ENEMY_SYSTEM.md`、敌人 `.tres` 资源或 `ActionTimingDefinition` 的运行时合同。

## 结论

不存在“普通攻击必须移动”或“普通攻击必须原地进行”的行业统一规则。较常见的是按攻击的运动意图选择以下三条路线，并让每个攻击资源显式声明选择：

| 路线 | 位移权威 | 典型动作 | 脚部处理 |
|---|---|---|---|
| 原地攻击（in-place） | 角色控制器速度为零 | 普通挥砍、格挡反击、需要清晰硬直的打击 | 攻击站姿或定脚姿势 |
| 控制器驱动的攻击移动 | AI/角色控制器计算并应用速度 | 缓慢逼近挥击、横移射击、可调整朝向的连段 | 用真实水平速度驱动低权重步态；攻击主要覆盖上半身 |
| 根运动或专用冲刺 | 动画根运动，或专用动作运动曲线/控制器逻辑 | 扑击、跳斩、冲刺刺击、重击 | 专用全身动作，脚步与大位移一起设计 |

普通攻击应默认采用第一种路线；只有攻击设计明确需要持续压迫、修正距离或边移动边出招时，才在该攻击资源上选择第二种。明显的前扑、跳跃或冲刺攻击使用第三种。这样“是否移动”是攻击的可选数据能力，不封死在动画里，也不写死在通用追击逻辑里。

## 官方资料所支持的能力

### Unreal Engine

- [Root Motion](https://dev.epicgames.com/documentation/en-us/unreal-engine/root-motion-in-unreal-engine) 说明根运动动画可由动画数据驱动角色移动；同页也说明常规角色移动通常由 `Character Movement Component` 驱动，再叠加动画播放。这两种运动权威都是正式路径。
- 同一页面定义了 `Root Motion from Everything`（从所有参与最终姿势、且启用根运动的资源提取并按权重混合）和 `Root Motion from Montages Only`（仅从 Montage 提取）。这支持按攻击资源决定是否使用动画位移，而不是把所有攻击强制成同一种方式。
- 该页还注明根运动会让 Animation Graph 在 Game Thread 上执行。因此根运动适合需要动作精确位移的攻击，不应在未评估成本和同步需求前成为所有普通攻击的默认方案。

### Unity

- [Root motion](https://docs.unity3d.com/Manual/RootMotion.html) 说明动画导入时可配置 Body Transform 如何投影到 Root Transform，并可选择 `Bake Into Pose`。也就是说，位移可以保留为姿势、提取为根运动，或由运行时另行处理。
- [Scripting Root Motion](https://docs.unity3d.com/Manual/ScriptingRootMotion.html) 明确举例说明“in-place”动画不包含根运动时，仍可由脚本修改根运动，并可用动画曲线驱动速度。这支持把攻击移动作为外部策略或资源数据，而不必烘焙进每段动画。
- [Animation Layers](https://docs.unity3d.com/Manual/AnimationLayers.html) 将 lower-body 的行走/跳跃与 upper-body 的投掷/射击作为分层示例；Avatar Mask、Override 与 Additive 用于控制覆盖范围和叠加方式。这对应“腿部继续低权重步态、躯干和手臂播放攻击”的常见实现。

### Godot

- [AnimationTree: Root motion](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html#root-motion) 将根骨骼带动其他骨骼描述为 3D 动画中的常用技术，并提供 `get_root_motion_position()` 等 API 供代码取得运动增量后应用。根运动不是让视觉骨骼直接改写物理根节点；物理角色仍应统一经角色移动逻辑处理。
- [AnimationTree: Blend Tree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html#blend-tree) 提供逐轨道过滤（filter），官方明确说明它适合在其他动画上进行分层。这可用于保留下半身步态，同时将攻击姿势限制在脊柱、头部和手臂等轨道。

上述资料说明的是引擎提供的正式能力和官方示例，不能推导为所有商业游戏都采用同一攻击设计。具体取舍仍取决于距离控制、可读性、网络同步、碰撞约束和动画资产预算。

## 给 MVP 敌人系统的约束

攻击移动应作为 `EnemyDefinition` 中每个攻击的可选运动定义，而不是 `ActionTimingDefinition` 的一部分。动作时间合同继续只保存 `windup_seconds`、`release_seconds`、`impact_seconds`、`recovery_seconds` 四段时间；速度、停止距离、朝向追踪和下半身混合策略使用语义独立的字段或资源。

建议的资源语义如下：

| 字段语义 | 用途 |
|---|---|
| `movement_source` | `NONE`、`CONTROLLER`、`ROOT_MOTION`，声明该攻击的唯一位移权威 |
| 阶段移动倍率或许可 | 分别控制前摇、出手、命中、后摇是否能移动及移动强度 |
| 距离与朝向规则 | 仅供 `CONTROLLER` 路线使用，例如停止距离、是否持续面向目标 |
| 下半身策略 | `LOCKED` 或 `LOCOMOTION_BLEND`，只决定动画混合，不决定物理位移 |

运行时必须保证同一攻击同一时刻只有一个系统写入角色的水平位移。`NONE + LOCKED` 是普通站桩攻击的安全默认值；`CONTROLLER + LOCOMOTION_BLEND` 用于需要慢速贴近的攻击，步态权重应由真实速度而非攻击状态本身驱动；重击等大位移动作可使用 `ROOT_MOTION` 或保留当前专有控制器冲刺实现，但仍需在资源语义上明确其唯一运动来源。

命中阶段通常宜停步或显著降速，以维持落脚、武器接触和可招架窗口的可读性；这是可调的攻击数据，不是动画回调或新的动作时间字段。

## 本项目的初步选择

现有 `ruptured` 重击已经是“视觉跳跃 + `CharacterBody3D` 物理移动”的专有控制器路线，且正式伤害只在 `impact` 起点结算。它不应因为引入该模型而被强制改为根运动。

普通近战攻击先保持 `NONE + LOCKED`。后续只为确有追击需求的攻击增加 `CONTROLLER + LOCOMOTION_BLEND`，并以同一 `.tres` 中的阶段倍率控制前摇低速接近、命中停步和后摇恢复。动画控制器消费真实速度与下半身策略，但不得反向裁决移动或伤害时机。
