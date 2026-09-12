# Repository Instructions

This repository is a Godot 4.x project for the MVP branch of Decaying Rain.

## Branch Discipline

- Active integration branch: `mvp`.
- Feature work branches from `mvp`, not from `main`.
- Use `feat/mvp-<milestone>-<short-name>` for implementation branches.
- Pull requests for playable MVP work target `mvp`.
- `main` receives milestone-quality snapshots from `mvp` only after review.
- Before any Git operation, use the global `github-feature-branch-safety` skill and ask for explicit confirmation. Only use it when it is exposed as an active skill in the current session. If it is unavailable, do not search or read disabled skill directories; stop and notify the user.

## Disabled Skills

- Never search, read, invoke, or otherwise inspect skills under `.agents/skills.disabled/` or any global `skills.disabled*` directory.
- A disabled skill must not be used as fallback guidance, even when another repository instruction names it.
- Only skills explicitly exposed as active in the current agent session may be opened or invoked.
- If a required skill is not active, stop the affected work and notify the user instead of loading its disabled copy.

## GodotPrompter

When working on Godot-specific code, invoke the relevant GodotPrompter skill before editing only if it is exposed as active in the current session. If the required skill is unavailable, follow the Disabled Skills rules and stop the affected work.

- `godot-project-setup` for project layout, settings, autoloads, and repository hygiene.
- `scene-organization` for scene tree structure and composition boundaries.
- `event-bus` for cross-system signals.
- `resource-pattern` for typed gameplay data containers.
- `save-load` for settings, saves, and schema migration.
- `gdscript-patterns` for typed GDScript.

## AI Tool Port

- All AI clients and assistant conversations for this repository must use the Godot MCP endpoint on port `19080`.
- The expected endpoint is `http://localhost:19080/mcp`, matching `.mcp.json`.
- If an AI client cannot connect to port `19080`, it must stop Godot-related work immediately and notify the user instead of continuing with assumptions.
- Do not silently fall back to another port unless the user explicitly updates the repository configuration.

## Code Shape

- New runtime code goes in `scripts/` using lowercase paths.
- Existing `scripts/Player/` files are legacy prototype files until explicitly migrated.
- Scenes go in `scenes/`, with one responsibility per scene.
- Gameplay tuning data lives in `resources/` as `.tres` files backed by scripts in `scripts/resources/`.
- Use autoloads for long-lived orchestration only; keep gameplay behavior in components and systems.

## 动作时间合同

- 一次性动作统一使用 `ActionTimingDefinition`，四个阶段固定为：`windup_seconds`（前摇）、`release_seconds`（出手）、`impact_seconds`（命中）、`recovery_seconds`（后摇）。不得另造同义字段或只维护总时长。
- 玩法判定与动画必须读取同一个 `.tres` 中的同一个 `ActionTimingDefinition` Resource 实例。状态机负责按阶段推进；动画只消费合同，不得用动画事件或 Tween 回调反向裁决 gameplay。
- 伤害、射线、弹药消耗、装填完成、推搡等生效点统一位于“命中”阶段起点，即 `windup + release`。格挡等持续判定若无专项说明，覆盖“出手 + 命中”阶段。
- 动画脚本不得硬编码动作阶段秒数。姿态、曲线和动作差异可以写在动画实现中，但每段时长必须来自合同的四个字段。
- 某阶段不适用时允许设为 `0.0`，但仍必须保留四阶段合同。循环动画（待机、持续行走、持续冲刺）不套用一次性动作合同；跳跃起步、滑铲、冲刺起步等一次性动作仍适用。
- 冷却、输入缓存、连击输入窗口、状态持续时间不属于动作四阶段，必须以独立且语义明确的字段保存，不得假装成后摇。
- 数值唯一入口是 `resources/` 下的 gameplay `.tres`：武器攻击/装填在各武器资源，玩家格挡/推搡/交互/受击在 `mvp_player_combat.tres`，跳跃/滑铲/冲刺起步在 `mvp_player_movement.tres`，主动技能和敌人动作在各自定义资源。修改这些合同后，玩法与动画必须同步变化，无需改脚本。

## Player Work Boundary

- `character_test_lab/` is a discarded concept preserved only as a user-facing action showcase stage. It is not the playable protagonist, not a production asset source, and not an implementation target or visual reference for MVP work.
- Do not modify, extend, integrate, or use anything under `character_test_lab/` to satisfy player, protagonist, modeling, hand, weapon-viewmodel, movement-feel, or animation requests unless the user explicitly names that directory or its Rain Warden showcase.
- Unqualified references to the player or protagonist always mean the playable MVP player rooted at `res://scenes/characters/player/player.tscn`.
- Player runtime work belongs under `res://scripts/characters/player/`; the first-person shoulder/elbow arm rig is instanced under the camera in `player.tscn` from `res://scenes/characters/player/player_first_person_arms.tscn` and driven by `res://scripts/characters/player/player_first_person_arms.gd`.
- Before editing player visuals or animations, inspect the playable `player.tscn`, its lowercase player scripts, and `docs/architecture/PLAYER_SYSTEM.md`. Do not infer the target from standalone showcases, test labs, concept art, or audit captures.

## First-Person Arm Joint Direction

- Known bug to avoid: do not bend the forearm downward from the elbow. In first-person view, the elbow is the lower pivot and the forearm/hand must lift upward and forward from it.
- For `player_first_person_arms.tscn`, elbow flexion uses positive local X rotation. Negative local X produces the incorrect downward/reversed bend.
- This direction rule applies to idle, locomotion, attacks, parry, shove, interaction, skills, hurt reactions, and every transition/return pose. Do not fix only a subset of actions.
- Preserve the explicit `Shoulder -> Elbow -> Forearm/Hand` hierarchy and keep the runtime elbow-direction guard in `player_first_person_arms.gd` when adding or tuning poses.
- First-person weapon visuals must be children of `RightHandSocket/FirstPersonWeaponSocket` in the arm rig. Never animate or position a first-person weapon independently under the arm root, because it will float away from the hand.
