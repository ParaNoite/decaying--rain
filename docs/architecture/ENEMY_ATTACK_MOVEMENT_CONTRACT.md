# 敌人攻击运动合同

攻击时长与攻击位移是两份独立合同：`ActionTimingDefinition` 仅定义前摇、出手、命中、后摇的时间；`AttackMovementDefinition` 定义该攻击是否移动、由谁写入移动，以及各阶段可用的速度倍率。

## 当前运动来源

| 来源 | 位移权威 | 用途 |
|---|---|---|
| `NONE` | 无 | 原地攻击，角色根节点水平速度为零。 |
| `CONTROLLER` | `EnemyBase` 的 `CharacterBody3D` | 可选贴近攻击。根据当前阶段的倍率与停止距离计算速度，再经 `move_and_slide()` 处理碰撞。 |

同一攻击的同一时刻不得有多个系统写入水平速度。动画不得移动敌人的物理根节点、不得决定伤害时机。

## 动画规则

`CONTROLLER` 攻击可开启 `use_locomotion_blend`。此时动画控制器读取真实水平速度，仅在移动倍率大于零的阶段保留受 `locomotion_blend_max_weight` 限制的下半身碎步；攻击姿势主要覆盖上半身。若命中或后摇阶段倍率为零，动画和物理会在该阶段同时锁脚。

## Ruptured

`ruptured.tres` 保留原有 `attack_timing` 原地挥击，并额外配置了 `tracking_attack_timing + tracking_attack_movement`：40% 概率选择，在前摇以 40% 移速、出手以 18% 移速贴近，距离目标 1.35 米停止；命中与后摇固定不移动。重击仍使用其既有专用扑近逻辑。
