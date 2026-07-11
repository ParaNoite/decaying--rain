# Versioning

## Version Axes

- Game version: player-facing build identity.
- Content spec version: design document compatibility.
- Save schema version: user data migration contract.
- Milestone tag: MVP readiness marker.

## Current Values

- Game version: `0.1.0-mvp.0`
- Content spec version: `mvp-docs-v0.1`
- Save schema version: `1`
- Integration branch: `mvp`

These values are mirrored in `scripts/core/version_info.gd`.

## Milestone Tags

Use milestone tags only after review:

- `mvp/m0-graybox`
- `mvp/m1-day-rain-loop`
- `mvp/m2-combat-base-pressure`
- `mvp/m3-content-complete`
- `mvp/m4-demo-ready`

## Save Compatibility

Save files must include an integer `version`. `SaveManager` migrates older dictionaries forward one version at a time.

Breaking save compatibility is not allowed inside the MVP branch unless the save schema version is incremented and migration is updated.
