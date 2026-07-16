# Rain Warden Character Test

This folder is a self-contained asset island inside the existing Godot 4.6 project. It does not modify or depend on any existing scene, gameplay script, resource, autoload, or project setting.

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

The models are authored from Godot mesh primitives plus custom `ArrayMesh` surfaces. The character uses quaternion pose tracks and a deterministic two-arm IK pass so both hands remain attached to the weapon grips through idle, ready, inspect, attack, pulse, and run clips.

The showcase audio is generated locally at runtime as 16-bit PCM. It includes layered rain ambience, UI confirmation, equipment movement, weapon inspection, attack whoosh and impact, rain-pulse charge and release, and synchronized combat-run footsteps. Dedicated runtime audio buses keep ambience, character SFX, and UI feedback independently balanced without changing the parent project's audio resources.
