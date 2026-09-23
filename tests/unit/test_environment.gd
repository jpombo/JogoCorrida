extends GdUnitTestSuite

var manager: EnvironmentManager

func before_test() -> void:
	manager = EnvironmentManager.new()

func after_test() -> void:
	manager = null

func test_set_valid_environment() -> void:
	manager.set_environment("PLAINS")
	var env = manager.get_current_environment()
	assert_object(env).is_not_null()
	assert_str(env.id).is_equal("PLAINS")
	assert_str(env.display_name).is_equal("Planície")
	assert_int(env.difficulty).is_equal(1)

func test_set_desert() -> void:
	manager.set_environment("DESERT")
	var env = manager.get_current_environment()
	assert_str(env.id).is_equal("DESERT")
	assert_int(env.difficulty).is_equal(2)

func test_set_forest() -> void:
	manager.set_environment("FOREST")
	var env = manager.get_current_environment()
	assert_str(env.id).is_equal("FOREST")
	assert_int(env.difficulty).is_equal(3)

func test_set_ice() -> void:
	manager.set_environment("ICE")
	var env = manager.get_current_environment()
	assert_str(env.id).is_equal("ICE")
	assert_int(env.difficulty).is_equal(4)

func test_invalid_id_fallback_to_plains() -> void:
	manager.set_environment("INVALID")
	var env = manager.get_current_environment()
	assert_object(env).is_not_null()
	assert_str(env.id).is_equal("PLAINS")
	assert_int(env.difficulty).is_equal(1)

func test_difficulty_returns_zero_when_no_environment() -> void:
	assert_int(manager.get_difficulty()).is_equal(0)

func test_difficulty_plains() -> void:
	manager.set_environment("PLAINS")
	assert_int(manager.get_difficulty()).is_equal(1)

func test_difficulty_desert() -> void:
	manager.set_environment("DESERT")
	assert_int(manager.get_difficulty()).is_equal(2)

func test_difficulty_forest() -> void:
	manager.set_environment("FOREST")
	assert_int(manager.get_difficulty()).is_equal(3)

func test_difficulty_ice() -> void:
	manager.set_environment("ICE")
	assert_int(manager.get_difficulty()).is_equal(4)

func test_get_all_environments() -> void:
	var all = manager.get_all_environments()
	assert_int(all.size()).is_equal(4)

func test_all_environments_have_unique_ids() -> void:
	var all = manager.get_all_environments()
	var ids: Array = []
	for env in all:
		ids.append(env.id)
	var unique_ids: Dictionary = {}
	for id in ids:
		unique_ids[id] = true
	assert_int(unique_ids.size()).is_equal(4)

func test_texture_paths_are_valid() -> void:
	var all = manager.get_all_environments()
	for env in all:
		assert_bool(ResourceLoader.exists(env.texture_path)).is_true()
