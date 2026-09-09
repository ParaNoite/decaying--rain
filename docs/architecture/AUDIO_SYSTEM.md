# 音频系统

`AudioManager` 是音乐和音效的唯一入口。玩法代码只能通过稳定 ID 请求 `AudioCue`，不得临时创建 `AudioStreamPlayer` 节点。

## 总线

`default_bus_layout.tres` 提供 `Master`、`Music`、`SFX`、`UI`、`Ambience` 五条总线。所有子总线均路由至 Master，Limiter 在最终混音阶段防止削波。音频设置独立于跑局存档，保存于 `user://settings/audio.cfg`。

## 内容

仅在 `res://resources/audio/mvp_audio_catalog.tres` 登记 Cue。每个 `AudioCue` 持有音频流、总线、音量、随机音高、空间衰减和单 Cue 并发上限。ID 使用小写点分命名，例如 `player.weapon.rifle.fire`、`ui.watch.open`、`environment.rain.loop`。

音乐和长循环音频放在 `res://assets/audio/music/`，格式为 OGG Vorbis；短促、时序敏感的音效放在 `res://assets/audio/sfx/`，格式为 16-bit WAV。3D 音源导入时必须转为单声道。

## 运行时接口

- `AudioManager.play_music(cue_id, fade_seconds)`：经 Music 总线交叉淡入淡出。
- `AudioManager.play_global_sfx(cue_id)`：播放 UI 或非定位音效。
- `AudioManager.play_3d_sfx(cue_id, world_position)`：播放世界坐标定位音效。
- `AudioManager.play_sfx(cue_id, bus_name)`：保留的兼容全局音效入口。

未知、缺流、重复或目标总线无效的 Cue 会安全失败，并只输出一次警告。全局与定位播放使用固定对象池，调用方无需持有或释放播放器。
