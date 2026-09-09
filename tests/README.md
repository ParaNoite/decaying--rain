# Tests

## 音频系统验收

自动验收运行 `res://tests/integration/audio_system_smoke.tscn`。Output 出现 `AUDIO_SYSTEM_SMOKE: PASS` 且没有红色错误，表示默认总线、Master Limiter、Cue 目录校验、全局和 3D 固定池、音乐状态、线性音量转换与 `user://settings/audio.cfg` 持久化均正常。

人工验收：运行主场景，在 Remote 场景树展开 `AudioManager`，确认存在两个 `MusicPlayer`、16 个 `GlobalSfxPlayer` 与 24 个 `SpatialSfxPlayer`；打开 Audio 面板，确认 `Master`、`Music`、`SFX`、`UI`、`Ambience` 五条总线，且 Master 的第一个效果为 Limiter。通过 `AudioManager.set_bus_volume_linear(&"SFX", 0.0)` 将 SFX 设为静音，重启场景后确认仍为静音且 Output 没有 `-inf` 错误；将其恢复到 `1.0`。

Automated tests will live here once the project adds a Godot test runner.

Recommended first coverage:

- EventBus signal contracts.
- SaveManager schema migration.
- InventoryModel item accounting.
- LootResolver deterministic drops with seeded RNG.
- PhaseController daylight / preparation / rain / settlement transitions.

## Player System Smoke Test

Run `res://tests/integration/player_system_smoke.tscn`. It instantiates the real player scene and validates the first-person shoulder/elbow chains, profession initialization, inventory pickups, loadout switching, firearm ammunition, reloads, status refresh, and consumable use.

## 状态系统验收

自动验收运行 `res://tests/integration/status_system_smoke.tscn`。Output 出现 `STATUS_SYSTEM_SMOKE: PASS` 且没有红色错误，表示玩家和敌人都可通过伤害事件获得 bleeding，同类状态只刷新不叠层；饱食度归零会获得 hungry 并降低伤害，恢复饱食度后解除；冲刺储备耗尽会获得 exhausted 并将冲刺速度减半，储备回满后解除。

人工验收：运行主场景，持续冲刺至冲刺储备为空，松开冲刺键并等待储备回满；状态列表应显示 `Exhausted`，冲刺速度降为正常的一半，回满后消失。将饱食度耗尽后，状态列表应显示 `Hungry`，进食后消失。使用携带 `bleeding` 的敌人攻击或场景交互后，状态列表应显示 `Bleeding` 并每两秒掉血；使用绷带后该状态立即消失。

## HUD 状态栏验收

自动验收运行 `res://tests/integration/hud_status_display_smoke.tscn`。Output 出现 `HUD_STATUS_DISPLAY_SMOKE: PASS` 且没有红色错误，表示 HUD 底部状态栏会显示玩家当前状态名称与剩余时间，并在状态清除后移除状态条目。

人工验收：进入主场景后触发任意状态。屏幕左下 `CONDITIONS` 区域应显示状态名和剩余秒数；多个状态应自动换行且不遮挡交互提示；永久状态显示“持续”。清除所有状态后，区域应显示 `CLEAR`。

## 玩家耐力验收

自动验收运行 `res://tests/integration/player_endurance_smoke.tscn`。Output 出现 `PLAYER_ENDURANCE_SMOKE: PASS` 且没有红色错误，表示战斗耐力会在每次消耗后等待恢复延迟、再次消耗会重新计时，且冲刺只消耗隐藏冲刺储备而不消耗战斗耐力；无耐力的轻击和重击仍可发动并使用 0.3 倍伤害，轻击距离为基础近战距离的 1.5 倍，后续连招动作更快且左手 guard 会持续到连招结束。

人工验收：在可玩场景中耗尽耐力后继续用左键与右键攻击，动作应正常触发但伤害显著降低；连续按住或快速连按左键，第二、三段应比首段更快，左手始终维持架势而不会回落。停止输入超过连招窗口后，左手才平滑回到待机位置。

## Player Arms 人工验收

运行 `res://tests/manual/player_arms_acceptance.tscn`。该场景实例化真实 `player.tscn`，从玩家相机检查第一人称手臂，不包含另一套展示角色资产。

- `1`：轻击一段，左手横架，右手直刺。
- `2`：轻击二段，左手保持横架，右手横摆。
- `3`：轻击三段，左手保持横架，右手下劈。
- `4`：重击；`5`：推搡；`6`：格挡；`7`：交互。
- `8`：跳跃；`9`：滑铲；`0`：切换冲刺循环。

该场景只响应手动按键，不会自动播放动作，也不会自动关闭。

## Player 身体模型验收

自动验收运行 `res://tests/integration/player_body_visual_smoke.tscn`。Output 出现 `PLAYER_BODY_VISUAL_SMOKE: PASS` 且没有红色错误，表示旧胶囊和方向标记已删除，正式玩家已接入分层身体模型，四肢关节与第一人称渲染隔离合同有效。

人工验收运行 `res://tests/manual/player_body_model_acceptance.tscn`。该场景不会自动播放动作，也不会自动结束；使用左右方向键旋转模型。检查头罩、呼吸面罩、护目镜、胸甲、背包、腰包、破损外套、手套和靴子是否形成完整逃兵轮廓，并确认肩膀/手肘、髋部/膝盖处都有独立转折，不再出现蓝色胶囊或黄色方向块。

通过标准：左右手均能看出肩膀和手肘两个独立转折点；前臂和手必须从手肘向上、向前抬起，任何待机或动作姿态都不得从手肘向下反折；武器代理必须固定在右手握持位置并完整跟随肩、肘、手部动作，不得与手掌分离或浮空；三段轻击期间左手先横向架住并保持稳定，右手分别完成直刺、横摆和下劈；重击要平滑举过头顶、停顿蓄力后猛砸；推搡要快出缓收；交互时左手前探、右手后收；其余动作也应仅凭手臂姿势相互区分，且不遮住画面中心、不穿过相机。

## Combat And Buff Resolver Smoke Test

Run `res://tests/integration/combat_buff_resolver_smoke.tscn`. It validates centralized outgoing/incoming modifiers, critical damage, periodic damage routing, enemy status support, zero-damage stagger, and the resolved damage signal.

## Enemy System MVP 验收

自动验收运行 `res://tests/integration/enemy_system_smoke.tscn`。Output 出现 `ENEMY_SYSTEM_SMOKE: PASS` 且没有红色错误，表示以下合同通过：

- 五波固定刷怪表数量和类型正确，最多 11 个敌人不会重叠出生。
- 敌人出生在地表与基地北侧外场，不会生成在院内或墙体中。
- 四种敌人的生命、速度、攻击范围、攻击伤害和冷却来自各自资源。
- 状态机覆盖追击、攻击、受击和死亡。
- `doorbreaker` 按 barrier、base_core、player 的顺序选择目标。
- `wet_gunner` 的 hitscan 会被无关世界几何阻挡，无遮挡时造成 ballistic 伤害，并遵守冷却。
- 每个敌人生成和死亡各触发一次生命周期事件，伤害仍触发 `combat_hit`。
- 雨夜计时归零不会结束未清场波次；最后一个敌人死亡后才进入 settlement。

人工验收运行 `res://tests/manual/enemy_system_acceptance.tscn`。该场景直接进入第 5 波；Output 应出现 `ENEMY_SYSTEM_ACCEPTANCE_READY: wave=5 enemies=11`。

占位颜色对应关系：

- 绿色：ruptured，快速低血近战。
- 红色：doorbreaker，优先攻击 barrier，再攻击 base_core，最后攻击 player。
- 灰蓝色：armored_scavenger，高血高伤近战。
- 青色：wet_gunner，远程 hitscan；实体遮挡应阻止伤害。

人工通过标准：11 个敌人全部可见、脚部贴地、不在同一点重叠；近战敌人会移动和贴身攻击；红色敌人遵守目标优先级；青色敌人不能穿墙；清场前阶段保持 rain，清场后进入 settlement。

## 大基地布局验收

自动验收运行 `res://tests/integration/base_layout_smoke.tscn`。Output 出现 `BASE_LAYOUT_SMOKE: PASS` 且没有红色错误，表示基地四周墙体、门楼、内堡和掩体均有碰撞，旧的核心与北门路径保持兼容，出生点与采集区分别位于基地南北两侧。

自动验收运行 `res://tests/integration/loot_world_smoke.tscn`。Output 出现 `LOOT_WORLD_SMOKE: PASS` 且没有红色错误，表示地面物品是受重力影响的 `RigidBody3D`，物理层只扫描 World 而不会与玩家或敌人发生实体碰撞，且野外刷新器会从候选点中随机生成指定数量的可拾取物品。

自动验收运行 `res://tests/integration/watch_hud_smoke.tscn`。Output 出现 `WATCH_HUD_SMOKE: PASS` 且没有红色错误，表示 Tab 手表可持续开关，左手会先举起并保持，投影再从中心点展开；关闭时投影先收拢，左手在恢复阶段才放下。状态页能区分基地与搜刮区、显示时钟格式的阶段倒计时，物资页能显示食物并在点击后关闭手表、按既有动作合同消耗食物和恢复饱食度，旧 I 键背包入口已移除。

人工验收：运行主场景，按 Tab 打开全屏全息手表投影；先确认左手向上抬至视线顶部并保持，随后投影从屏幕中心快速放大。确认移动降至手表步行速度，攻击和交互失效但世界计时继续。再次按 Tab 或 Esc，确认投影先快速缩回中心点，左手随后才落回待机。点击 `STATUS & MAP`，从基地前往北侧搜刮区，确认位置文字与地图箭头同步变化。点击 `SUPPLIES`，拾取 Light Ammo、Rifle Ammo、Shells 和 Food Ration 后确认数量即时刷新；点击 `EAT FOOD RATION` 后手表关闭，食物在使用动作命中阶段消耗并恢复饱食度。按 I 不应再出现独立背包窗口。

人工验收运行主场景 `res://scenes/levels/mvp_skeleton.tscn`。离开基地进入北方的 ScavengeArea，确认每局在六个候选位置中随机出现三到五个带模型的地面物品；等待它们落地后，确认不会阻挡玩家或敌人。对准物品按交互键，应进入背包。对木箱或金属箱长按交互键，确认掉落物带模型、会落地且可拾取。打开背包选中普通物品后按丢弃键，确认丢出的同一物品会向前轻抛、落地并可再次拾取。

人工验收运行 `res://tests/manual/base_layout_acceptance.tscn`。该场景不会自动开局，也不会自动结束，可以自由走动检查空间：

- 北侧是约 4 米宽的可修复防守门，敌人出生线位于门外。
- 南侧是约 4 米宽的探索出口，三个采集点位于出口外并逐级拉远。
- 院内有中央、左侧、右侧三条连续通路；中央核心和前后掩体不应堵死任一路线。
- 左右内堡、四角高塔、外围墙、门柱和掩体都应阻挡玩家，不得穿模。
- 玩家出生在院内南半区，面向核心与北门；雨水遮蔽体积覆盖整座基地。

这一步只验收基地尺度与路线轮廓，不包含敌人专用导航。基地布局确认后再以北门、三条内院通路和南门为权威几何烘焙导航。
