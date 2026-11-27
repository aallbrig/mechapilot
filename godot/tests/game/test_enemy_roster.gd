extends GdUnitTestSuite
## The enemy hit points (#73, #23 tuning) that Intel shows (#75) and play uses
## are one table: every kind is pinned, and EnemyProfile reads EnemyRoster.

const EXPECTED: Dictionary[EnemyKind.Kind, int] = {
	EnemyKind.Kind.FIGHTER: 1,
	EnemyKind.Kind.HEAVY: 4,
	EnemyKind.Kind.INTERCEPTOR: 2,
	EnemyKind.Kind.DRONE: 1,
	EnemyKind.Kind.BOMBER: 4,
	EnemyKind.Kind.ENEMY_MECH: 6,
}


func test_every_enemy_hit_point_is_pinned_and_shared_with_intel() -> void:
	var roster: Dictionary[EnemyKind.Kind, int] = {}
	var profiles: Dictionary[EnemyKind.Kind, int] = {}
	var intel: Dictionary[EnemyKind.Kind, int] = {}
	for kind: int in EnemyKind.Kind.size():
		var which: EnemyKind.Kind = kind as EnemyKind.Kind
		roster[which] = EnemyRoster.hit_points(which)
		profiles[which] = EnemyProfile.of(which).hit_points
		intel[which] = EnemyRoster.intel_entry(which).hit_points
	var _every_kind: GdUnitAssert = assert_int(EXPECTED.size()).is_equal(EnemyKind.Kind.size())
	var _roster: GdUnitAssert = assert_dict(roster).is_equal(EXPECTED)
	var _play: GdUnitAssert = assert_dict(profiles).is_equal(EXPECTED)
	var _codex: GdUnitAssert = assert_dict(intel).is_equal(EXPECTED)
