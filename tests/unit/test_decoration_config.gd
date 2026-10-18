extends GdUnitTestSuite

## T040 — invariantes de configuração da decoração (FR-037, FR-038, FR-056).
## Nada aqui cria nó: são propriedades de GameConfig, conferidas direto.


func test_spacing_min_not_greater_than_max() -> void:
	assert_float(GameConfig.decoration_spacing_min).is_less_equal(
		GameConfig.decoration_spacing_max
	).override_failure_message("T040: decoration_spacing_min > decoration_spacing_max")


func test_spacing_positive() -> void:
	assert_float(GameConfig.decoration_spacing_min).is_greater(0.0).override_failure_message(
		"T040: decoration_spacing_min deve ser positivo"
	)
	assert_float(GameConfig.decoration_spacing_max).is_greater(0.0).override_failure_message(
		"T040: decoration_spacing_max deve ser positivo"
	)


func test_speed_multiplier_non_negative() -> void:
	assert_float(GameConfig.decoration_speed_multiplier).is_greater_equal(
		0.0
	).override_failure_message("T040: decoration_speed_multiplier negativo")


func test_safety_margin_non_negative() -> void:
	assert_float(GameConfig.decoration_safety_margin).is_greater_equal(
		0.0
	).override_failure_message("T040: decoration_safety_margin negativa")


func test_depth_configuration_valid() -> void:
	assert_int(GameConfig.decoration_depth_count).is_greater_equal(1).override_failure_message(
		"FR-034: decoration_depth_count deve ser ao menos 1"
	)
	assert_float(GameConfig.decoration_depth_spacing).is_greater(0.0).override_failure_message(
		"FR-034: decoration_depth_spacing deve ser positivo"
	)


func test_density_positive() -> void:
	assert_float(GameConfig.decoration_density).is_greater(0.0).override_failure_message(
		"FR-037: decoration_density deve ser positiva"
	)


func test_repeat_limit_positive() -> void:
	assert_int(GameConfig.decoration_tree_repeat_limit).is_greater_equal(
		1
	).override_failure_message("FR-036: decoration_tree_repeat_limit deve ser ao menos 1")


func test_environment_has_path_and_library() -> void:
	for ambiente in GameConfig.DECORATION_LIBRARIES:
		assert_dict(GameConfig.DECORATION_PATHS).contains_keys(
			str(ambiente)
		).override_failure_message("FR-030: sem pasta declarada para %s" % ambiente)
		assert_array(GameConfig.DECORATION_LIBRARIES[ambiente]).is_not_empty(
		).override_failure_message("FR-029: biblioteca vazia para %s" % ambiente)
		var soma: float = 0.0
		for item in GameConfig.DECORATION_LIBRARIES[ambiente]:
			soma += float(item.get("weight", 0.0))
		assert_float(soma).is_equal_approx(100.0, 0.001).override_failure_message(
			"FR-036: percentuais de %s somam %.2f, não 100" % [ambiente, soma]
		)


## T040 — a decoração também é projetada em decoration_tuning (FR-061).
func test_decoration_tuning_exposes_parameters() -> void:
	GameConfig._build_tuning_groups()
	assert_dict(GameConfig.decoration_tuning).contains_keys(
		["decoration_enabled", "decoration_spacing_min", "decoration_spacing_max"]
	).override_failure_message("FR-061: decoration_tuning incompleto")
