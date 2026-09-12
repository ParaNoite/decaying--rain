# 第一人称武器表现

WeaponDefinition.first_person_scene 引用 scenes/weapons/viewmodels/ 下的独立场景。
人物只实例化 FirearmViewmodel 并驱动表现，不判断型号，也不加载素材包路径。

每个场景使用同一结构：
- 根节点：右手握持原点，保存与 FirstPersonWeaponSocket 的安装变换。
- Alignment：整体模型及挂点调整，修改这里可保持枪口和瞄具同步。
- Alignment/Model：导入模型坐标轴和单位校正；标准方向为 -Z 向前、+Y 向上。
- Alignment/AimPoint：机械瞄具后方参考点，人物开镜时使用其实际全局位置。
- Alignment/Muzzle：枪口挂点；Flash 和可选 ShotLight 是它的子节点。闪光跟随命中阶段，实际开火事件额外保证至少显示一帧，避免短阶段被渲染帧跳过。

在本地场景中编辑并保存，不需要从 Remote 抄数值。
只调整握持关系时修改场景根；只修正模型导入时修改 Model。
修改模型尺寸或枪管长度后检查 AimPoint 和 Muzzle。

当前手枪使用 ZC57，冲锋枪使用 MGP7。包内没有步枪或霰弹枪，
这两个逻辑武器暂复用 MGP7，但拥有独立场景，后续可分别换成正式模型。
这里不修改逻辑武器的伤害、弹药、射速或四阶段动作合同。

## 机械动画

手枪、步枪通过各自 AnimationPlayer 引用 resources/animations/weapons/ 的动画库。
fire 和 reload 的时间轴 0–1、1–2、2–3、3–4 分别表示前摇、出手、命中、后摇；
这四个单位是归一化阶段，不是实际秒数。FirearmViewmodel.sample_action 读取同一
ActionTimingDefinition，将实际时间映射到对应阶段并 seek，不使用动画事件裁决玩法。

Alignment 下的 WeaponAnimatedPart 将时间轴 offset 转为导入网格父空间的位移，
避免模型导出的厘米单位、骨骼旋转影响作者使用统一的 -Z 前方、+Y 上方坐标。
MagazineMotion、BoltMotion、TriggerMotion 的目标路径属于武器场景，人物不识别型号。
弹匣在命中阶段起点回到插槽；动作完成或中断时所有机械部件立即恢复基准姿态。

tests/integration/weapon_animation_preview.tscn 可独立运行，循环慢放两把枪的开火与装填。
tests/integration/weapon_animation_smoke.tscn 检查机械复位、装填时序及不同帧率下的枪机行程。
tests/integration/firearm_fire_visual_smoke.tscn 在真实靶场输入开火，检查耗弹、枪机运动与闪光，并保存运行截图。
这版是机械部件动画，沿用已有双臂姿态，尚未制作左手抓取弹匣的接触动画。
