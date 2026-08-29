class_name ActionTimingDefinition
extends Resource

enum Phase {
	WINDUP,
	RELEASE,
	IMPACT,
	RECOVERY,
	COMPLETE,
}

@export_group("Action Timing Contract")
@export_range(0.0, 10.0, 0.001) var windup_seconds: float = 0.0
@export_range(0.0, 10.0, 0.001) var release_seconds: float = 0.0
@export_range(0.0, 10.0, 0.001) var impact_seconds: float = 0.0
@export_range(0.0, 10.0, 0.001) var recovery_seconds: float = 0.0


static func from_phases(
	windup: float,
	release: float,
	impact: float,
	recovery: float
) -> ActionTimingDefinition:
	var timing := ActionTimingDefinition.new()
	timing.windup_seconds = maxf(0.0, windup)
	timing.release_seconds = maxf(0.0, release)
	timing.impact_seconds = maxf(0.0, impact)
	timing.recovery_seconds = maxf(0.0, recovery)
	return timing


func total_seconds() -> float:
	return impact_end_seconds() + recovery_seconds


func release_start_seconds() -> float:
	return windup_seconds


func impact_start_seconds() -> float:
	return windup_seconds + release_seconds


func impact_end_seconds() -> float:
	return impact_start_seconds() + impact_seconds


func phase_at(elapsed_seconds: float) -> Phase:
	var elapsed := maxf(0.0, elapsed_seconds)
	if elapsed < release_start_seconds():
		return Phase.WINDUP
	if elapsed < impact_start_seconds():
		return Phase.RELEASE
	if elapsed < impact_end_seconds():
		return Phase.IMPACT
	if elapsed < total_seconds():
		return Phase.RECOVERY
	return Phase.COMPLETE


func phase_duration(phase: Phase) -> float:
	match phase:
		Phase.WINDUP:
			return windup_seconds
		Phase.RELEASE:
			return release_seconds
		Phase.IMPACT:
			return impact_seconds
		Phase.RECOVERY:
			return recovery_seconds
		_:
			return 0.0


func phase_start_seconds(phase: Phase) -> float:
	match phase:
		Phase.WINDUP:
			return 0.0
		Phase.RELEASE:
			return release_start_seconds()
		Phase.IMPACT:
			return impact_start_seconds()
		Phase.RECOVERY:
			return impact_end_seconds()
		_:
			return total_seconds()
