extends GdUnitTestSuite

## SPEC-007 / US2 — testes obrigatórios 16–25: penalidade por ambiente, acúmulo,
## sem duplicação, NPC×NPC = 0, troca de ambiente e clamp a zero. Muta
## `GameConfig.current_environment_id` e restaura em `after_test` (research R8).

var sistema: FuelSystem

var _ambiente_original: String
var _penalidades_original: Dictionary
var _inicial_original: float


func before_test() -> void:
	_ambiente_original = GameConfig.current_environment_id
	_penalidades_original = GameConfig.collision_fuel_penalty.duplicate()
	_inicial_original = GameConfig.fuel_initial_amount
	GameConfig.fuel_initial_amount = -1.0
	sistema = FuelSystem.new()
	sistema.reset()


func after_test() -> void:
	GameConfig.current_environment_id = _ambiente_original
	GameConfig.collision_fuel_penalty = _penalidades_original
	GameConfig.fuel_initial_amount = _inicial_original
	sistema.free()


func _penalidade(ambiente: String) -> float:
	return float(_penalidades_original.get(ambiente, 0.0))


## Teste 16 — planície: perda adicional exatamente zero (só consumo normal).
func test_16_plains_penalidade_zero() -> void:
	GameConfig.current_environment_id = "PLAINS"
	var antes: float = sistema.get_atual()
	sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal(antes)


## Teste 17 — deserto: perda adicional exatamente zero.
func test_17_desert_penalidade_zero() -> void:
	GameConfig.current_environment_id = "DESERT"
	var antes: float = sistema.get_atual()
	sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal(antes)


## Teste 18 — floresta: desconta exatamente o valor configurado.
func test_18_forest_desconta_valor_configurado() -> void:
	GameConfig.current_environment_id = "FOREST"
	var antes: float = sistema.get_atual()
	sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal(antes - _penalidade("FOREST"))


## Teste 19 — gelo: desconta exatamente o valor configurado.
func test_19_ice_desconta_valor_configurado() -> void:
	GameConfig.current_environment_id = "ICE"
	var antes: float = sistema.get_atual()
	sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal(antes - _penalidade("ICE"))


## Teste 20 — floresta e gelo equivalentes entre si (config e desconto).
func test_20_forest_e_ice_equivalentes() -> void:
	assert_float(_penalidade("FOREST")).is_equal(_penalidade("ICE"))

	GameConfig.current_environment_id = "FOREST"
	var antes_forest: float = sistema.get_atual()
	sistema.on_player_collision()
	var desconto_forest: float = antes_forest - sistema.get_atual()

	sistema.reset()
	GameConfig.current_environment_id = "ICE"
	var antes_ice: float = sistema.get_atual()
	sistema.on_player_collision()
	var desconto_ice: float = antes_ice - sistema.get_atual()

	assert_float(desconto_ice).is_equal(desconto_forest)
	assert_bool(desconto_forest > 0.0).is_true()


## Teste 21 — N colisões distintas = N descontos acumulados.
func test_21_acumulo_de_descontos() -> void:
	GameConfig.current_environment_id = "FOREST"
	var antes: float = sistema.get_atual()
	for i in 3:
		sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal(antes - 3.0 * _penalidade("FOREST"))


## Teste 22 — no máximo 1 desconto por evento de colisão recebido: uma única
## chamada produz exatamente um desconto e uma única emissão de fuel_changed.
func test_22_uma_chamada_um_desconto() -> void:
	GameConfig.current_environment_id = "ICE"
	var mudancas := [0]
	sistema.fuel_changed.connect(func(_a, _c): mudancas[0] += 1)

	var antes: float = sistema.get_atual()
	sistema.on_player_collision()

	assert_float(sistema.get_atual()).is_equal(antes - _penalidade("ICE"))
	assert_int(mudancas[0]).is_equal(1)


## Teste 23 — colisão exclusivamente entre NPCs (SPEC-006) não altera o
## combustível do jogador: nenhum caminho do FuelSystem é acionado sem o
## evento jogador×NPC da SPEC-005 (FR-015/FR-032).
func test_23_npc_por_npc_nao_altera_combustivel() -> void:
	GameConfig.current_environment_id = "ICE"
	var antes: float = sistema.get_atual()
	var mudancas := [0]
	var esgotamentos := [0]
	sistema.fuel_changed.connect(func(_a, _c): mudancas[0] += 1)
	sistema.fuel_depleted.connect(func(): esgotamentos[0] += 1)

	# Atividade puramente NPC (atualizações de trânsito) não emite nada aqui:
	# sem chamada de on_player_collision, o valor permanece intocado.
	sistema.update(1.0 / 60.0, 0.0)

	assert_float(sistema.get_atual()).is_equal(antes)
	assert_int(mudancas[0]).is_equal(0)
	assert_int(esgotamentos[0]).is_equal(0)


## Teste 24 — troca de ambiente: a nova colisão usa o valor novo; nada
## retroativo às anteriores (FR-016, SC-012).
func test_24_troca_de_ambiente_sem_retroatividade() -> void:
	GameConfig.current_environment_id = "DESERT"
	sistema.on_player_collision()  # desconto 0
	var apos_desert: float = sistema.get_atual()

	GameConfig.current_environment_id = "ICE"
	sistema.on_player_collision()

	assert_float(apos_desert).is_equal(GameConfig.fuel_capacity)
	assert_float(sistema.get_atual()).is_equal(apos_desert - _penalidade("ICE"))


## Teste 25 — penalidade maior que o saldo: zera exatamente em zero, nunca
## negativo, e o esgotamento é detectado normalmente (origem "colisão").
func test_25_clamp_a_zero_com_esgotamento() -> void:
	GameConfig.fuel_initial_amount = 5.0
	sistema.reset()
	var esgotamentos := [0]
	sistema.fuel_depleted.connect(func(): esgotamentos[0] += 1)

	GameConfig.current_environment_id = "ICE"
	GameConfig.collision_fuel_penalty = {"ICE": 999.0}
	sistema.on_player_collision()

	assert_float(sistema.get_atual()).is_equal(0.0)
	assert_int(esgotamentos[0]).is_equal(1)
