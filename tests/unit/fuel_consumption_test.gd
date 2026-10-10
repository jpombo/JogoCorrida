extends GdUnitTestSuite

## SPEC-007 / US1 — testes obrigatórios 1–10 + gating de inicialização (SC-001).
## Instancia FuelSystem.new() e chama update(delta, velocidade) sintético
## (research R8) — sem loop de frames. Sem penalidades, eventos ou interface.

var sistema: FuelSystem

var _capacidade_original: float
var _inicial_original: float
var _idle_original: float
var _min_original: float
var _max_original: float
var _fator_original: float


func before_test() -> void:
	_capacidade_original = GameConfig.fuel_capacity
	_inicial_original = GameConfig.fuel_initial_amount
	_idle_original = GameConfig.fuel_consumption_idle
	_min_original = GameConfig.fuel_consumption_min
	_max_original = GameConfig.fuel_consumption_max
	_fator_original = GameConfig.fuel_consumption_speed_factor
	GameConfig.fuel_initial_amount = -1.0
	sistema = FuelSystem.new()
	sistema.reset()


func after_test() -> void:
	GameConfig.fuel_capacity = _capacidade_original
	GameConfig.fuel_initial_amount = _inicial_original
	GameConfig.fuel_consumption_idle = _idle_original
	GameConfig.fuel_consumption_min = _min_original
	GameConfig.fuel_consumption_max = _max_original
	GameConfig.fuel_consumption_speed_factor = _fator_original
	sistema.free()


## Consome em passos sintéticos e devolve a variação total observada.
func _drenar(velocidade: float, passos: int, delta: float) -> float:
	var antes: float = sistema.get_atual()
	for i in passos:
		sistema.update(delta, velocidade)
	return antes - sistema.get_atual()


## Teste 1 — nova partida inicia com o tanque exatamente cheio.
func test_01_init_tanque_cheio() -> void:
	assert_float(sistema.get_atual()).is_equal(GameConfig.fuel_capacity)
	assert_float(sistema.get_capacidade()).is_equal(GameConfig.fuel_capacity)


## Teste 2 — quantidade inicial configurada e clamp do valor fora do intervalo
## (o sentinela -1.0 permanece "tanque cheio" — FR-003).
func test_02_init_configurado_e_clamp() -> void:
	GameConfig.fuel_initial_amount = 40.0
	sistema.reset()
	assert_float(sistema.get_atual()).is_equal(40.0)

	GameConfig.fuel_initial_amount = -5.0
	sistema.reset()
	assert_float(sistema.get_atual()).is_equal(0.0)

	GameConfig.fuel_initial_amount = 9999.0
	sistema.reset()
	assert_float(sistema.get_atual()).is_equal(GameConfig.fuel_capacity)

	GameConfig.fuel_initial_amount = -1.0
	sistema.reset()
	assert_float(sistema.get_atual()).is_equal(GameConfig.fuel_capacity)


## Testes 3–4 — mesma duração em velocidades constantes: consumo na alta é
## maior ou igual, e cresce com a velocidade (monotonicidade).
func test_03_04_velocidade_alta_consome_mais() -> void:
	var baixa: float = _drenar(20.0, 5, 1.0)
	var media: float = _drenar(50.0, 5, 1.0)
	var alta: float = _drenar(100.0, 5, 1.0)

	assert_float(alta).is_greater_equal(baixa)
	assert_float(alta).is_greater_equal(media)
	assert_float(media).is_greater_equal(baixa)
	assert_float(alta).is_greater(0.0)


## Teste 5 — acelerar eleva o consumo na medida da velocidade alcançada.
func test_05_acelerar_eleva_consumo() -> void:
	var devagar: float = _drenar(20.0, 1, 1.0)
	sistema.reset()
	var rapido: float = _drenar(80.0, 1, 1.0)
	assert_float(rapido).is_greater(devagar)


## Testes 6–7 — desacelerar/frear reduz o consumo nos quadros seguintes:
## a segunda janela (velocidade menor) consome menos que a primeira.
func test_06_07_desacelerar_e_freiar_reduzem_consumo() -> void:
	sistema.update(1.0, 80.0)
	var primeira_janela: float = GameConfig.fuel_capacity - sistema.get_atual()
	sistema.reset()
	sistema.update(1.0, 80.0)
	sistema.update(1.0, 30.0)  # desaceleração (ou frenagem) — velocidade caiu
	var segunda_janela: float = GameConfig.fuel_capacity - sistema.get_atual() - primeira_janela
	assert_float(segunda_janela).is_less(primeira_janela)


## Teste 8 — repouso segue exatamente o consumo em repouso configurado
## (que pode ser zero).
func test_08_repouso_usa_consumo_em_repouso() -> void:
	GameConfig.fuel_consumption_idle = 0.0
	var variacao: float = _drenar(0.0, 10, 1.0)
	assert_float(variacao).is_equal(0.0)

	GameConfig.fuel_consumption_idle = 1.5
	sistema.reset()
	variacao = _drenar(0.0, 2, 1.0)
	assert_float(variacao).is_equal(3.0)


## Teste 9 — mesma duração em taxas de atualização diferentes produz o mesmo
## total (dependência do tempo decorrido, não do número de atualizações).
func test_09_independente_da_taxa_de_atualizacao() -> void:
	var total_lento: float = _drenar(100.0, 10, 0.1)
	sistema.reset()
	var total_rapido: float = _drenar(100.0, 100, 0.01)
	var desvio: float = absf(total_rapido - total_lento) / total_lento
	assert_float(desvio).is_less(0.01)


## Teste 10 — o valor para exatamente em zero e jamais negativo; reset recheia
## sem ultrapassar a capacidade.
func test_10_clamp_em_zero_e_capacidade() -> void:
	sistema.update(1000.0, 100.0)
	assert_float(sistema.get_atual()).is_equal(0.0)
	sistema.update(1.0, 100.0)
	sistema.update(1.0, 0.0)
	assert_float(sistema.get_atual()).is_equal(0.0)
	assert_bool(sistema.get_atual() < 0.0).is_false()

	sistema.reset()
	assert_float(sistema.get_atual()).is_equal(GameConfig.fuel_capacity)
	assert_bool(sistema.get_atual() > GameConfig.fuel_capacity).is_false()


## SC-001 / gating de inicialização — READY→PLAYING re-inicializa o tanque;
## PAUSED→PLAYING preserva o valor. O handler depende apenas do campo
## `fuel_system` (T006); um Node stub satisfaz `_show_playing`. O manager NÃO
## entra na árvore (evitando `_ready` com refs de cena nulas).
func test_gating_reset_somente_ready_para_playing() -> void:
	# GameplayManager não tem class_name (raiz de cena) — carrega por caminho.
	# Variante não tipada: os campos injetados (T006) são dinâmicos.
	var manager = load("res://src/game/gameplay_manager.gd").new()
	# Descarta o FuelSystem já instanciado pelo manager para não deixá-lo órfão.
	manager.fuel_system.free()
	manager.fuel_system = FuelSystem.new()
	manager.player_vehicle = Node.new()

	manager.fuel_system.reset()
	manager.fuel_system.update(10.0, 100.0)
	var drenado: float = manager.fuel_system.get_atual()
	assert_bool(drenado < GameConfig.fuel_capacity).is_true()

	# PAUSED → PLAYING NÃO re-inicializa (FR-002, SC-001).
	manager._on_state_changed(GameState.State.PLAYING, GameState.State.PAUSED)
	assert_float(manager.fuel_system.get_atual()).is_equal(drenado)

	# READY → PLAYING re-inicializa, exatamente uma vez por partida.
	manager._on_state_changed(GameState.State.PLAYING, GameState.State.READY)
	assert_float(manager.fuel_system.get_atual()).is_equal(GameConfig.fuel_capacity)

	manager.player_vehicle.free()
	manager.fuel_system.free()
	manager.free()
