# Rain Warden Character Test

## Scope warning

This directory is a discarded concept preserved only as an action showcase stage for the project owner. It exists solely to present poses, animation ideas, audiovisual treatment, and captured review frames. It is not the playable protagonist, not production content, not an MVP implementation target, and not a visual source of truth.

Agents and contributors must not modify, extend, integrate, or use this directory to satisfy general player, protagonist, modeling, hand, movement-feel, or animation requests unless the project owner explicitly names the Rain Warden showcase or `character_test_lab/`.

Actual player work starts from:

- `res://scenes/characters/player/player.tscn`
- `res://scripts/characters/player/`
- `res://docs/architecture/PLAYER_SYSTEM.md`

This folder is otherwise a self-contained presentation island inside the existing Godot 4.6 project. It does not modify or depend on any existing scene, gameplay script, resource, autoload, or project setting.

## Open

Open and run `res://character_test_lab/rain_warden_showcase.tscn` directly from the parent project.

## Controls

- `1`: idle
- `2`: ready stance
- `3`: weapon inspect
- `4`: cleaver attack
- `5`: rain pulse
- `6`: combat run loop
- Right-drag: orbit camera
- Mouse wheel: zoom
- `A` / `D`: orbit camera
- `Space`: toggle automatic turntable
- `R`: reset camera

## Assets

- `art/rain_warden_concept.png`: generated production concept sheet and visual target.
- `rain_warden_character.tscn`: standalone procedural character model and animation asset.
- `rain_cleaver_weapon.tscn`: standalone procedural weapon model.
- `rain_warden_showcase.tscn`: temporary presentation scene.

The models are authored from Godot mesh primitives plus custom `ArrayMesh` surfaces. Each arm has an explicit `Shoulder -> UpperArm -> Elbow -> Forearm/Hand` hierarchy with visible shoulder and elbow joints. Quaternion body tracks and per-clip elbow-hint tracks feed a deterministic two-arm IK pass, so both hands remain attached to the weapon while idle, ready, inspect, attack, pulse, and run retain distinct arm silhouettes.

## Arm acceptance

Run the showcase and orbit to a front three-quarter view. Confirm that the shoulder armor follows the upper arm, the black elbow joint remains between the upper arm and forearm, and neither elbow reverses direction during a clip. Compare `1` through `6`: ready must be asymmetric, inspect horizontal and raised, attack wide with a high windup, pulse symmetric and flared, and run compact with alternating elbows.

For frame-by-frame review, launch the showcase with the `RAIN_WARDEN_CAPTURE` environment variable set. The scene refreshes `art/animation_audit_*.png` with representative poses from every clip, then exits automatically.

The showcase audio is generated locally at runtime as 16-bit PCM. It includes layered rain ambience, UI confirmation, equipment movement, weapon inspection, attack whoosh and impact, rain-pulse charge and release, and synchronized combat-run footsteps. Dedicated runtime audio buses keep ambience, character SFX, and UI feedback independently balanced without changing the parent project's audio resources.
