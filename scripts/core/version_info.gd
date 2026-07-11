class_name VersionInfo
extends RefCounted

const GAME_VERSION: String = "0.1.0-mvp.0"
const CONTENT_SPEC_VERSION: String = "mvp-docs-v0.1"
const SAVE_SCHEMA_VERSION: int = 1
const INTEGRATION_BRANCH: String = "mvp"


static func as_dictionary() -> Dictionary:
	return {
		"game_version": GAME_VERSION,
		"content_spec_version": CONTENT_SPEC_VERSION,
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"integration_branch": INTEGRATION_BRANCH,
	}
