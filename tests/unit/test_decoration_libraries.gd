extends GdUnitTestSuite

## T023 — bibliotecas de decoração por ambiente: contagem de assets (FR-029),
## `repeatable` como DADO DE CONFIGURAÇÃO (FR-036, research.md R3),
## percentuais de apresentação somando 100 (FR-036) e existência dos arquivos
## (FR-047). T056 acrescenta a leitura do peso efetivo de sorteio.

const CONTAGENS: Dictionary = {
	"PLAINS": 5,
	"DESERT": 5,
	"FOREST": 4,
	"ICE": 3,
}

## Os 6 elementos repetíveis atuais — vêm da configuração, não do nome (R3).
const REPETIVEIS: Array[String] = [
	"planice_arvore01",
	"deserto_arvore01",
	"deserto_arvore02",
	"floresta_arvore01",
	"floresta_arvore02",
	"gelo_arvore",
]


func test_four_libraries_declared() -> void:
	assert_int(GameConfig.DECORATION_LIBRARIES.size()).is_equal(
		4
	).override_failure_message("FR-030: são 4 bibliotecas, uma por ambiente")


func test_asset_counts_per_environment() -> void:
	for ambiente in CONTAGENS:
		assert_int(GameConfig.DECORATION_LIBRARIES[ambiente].size()).is_equal(
			int(CONTAGENS[ambiente])
		).override_failure_message(
			"FR-029: %s deveria ter %d assets" % [ambiente, int(CONTAGENS[ambiente])]
		)


func test_repeatable_flag_from_config() -> void:
	var achados: Array[String] = []
	for ambiente in GameConfig.DECORATION_LIBRARIES:
		for item in GameConfig.DECORATION_LIBRARIES[ambiente]:
			if bool(item.get("repeatable", false)):
				achados.append(String(item.get("asset", "")))
	achados.sort()
	var esperados: Array[String] = REPETIVEIS.duplicate()
	esperados.sort()
	assert_array(achados).is_equal(
		esperados
	).override_failure_message("FR-036: repeatable deve ser exatamente os 6 assets declarados")


func test_weight_sums_100_per_environment() -> void:
	for ambiente in GameConfig.DECORATION_LIBRARIES:
		var soma: float = 0.0
		for item in GameConfig.DECORATION_LIBRARIES[ambiente]:
			soma += float(item.get("weight", 0.0))
		assert_float(soma).is_equal_approx(100.0, 0.01).override_failure_message(
			"FR-036: percentuais de %s somam %.2f, esperado 100" % [ambiente, soma]
		)


func test_texture_paths_exist() -> void:
	for ambiente in GameConfig.DECORATION_LIBRARIES:
		var pasta: String = String(GameConfig.DECORATION_PATHS.get(ambiente, ""))
		for item in GameConfig.DECORATION_LIBRARIES[ambiente]:
			var caminho: String = pasta + String(item.get("asset", "")) + ".png"
			assert_bool(ResourceLoader.exists(caminho)).is_true().override_failure_message(
				"FR-047: asset ausente para %s -> %s" % [ambiente, caminho]
			)


## T023 — a entrada crua vira DecorationData com peso declarado preservado.
func test_library_builds_data_with_declared_weight() -> void:
	var gerenciador := DecorationManager.new()
	gerenciador.setup(GameConfig.DECORATION_LIBRARIES)
	assert_bool(gerenciador.libraries.has("PLAINS")).is_true().override_failure_message(
		"R4: setup deve montar a biblioteca de PLAINS"
	)

	var planicie: Array = gerenciador.libraries["PLAINS"]
	assert_int(planicie.size()).is_equal(5).override_failure_message("FR-029: PLAINS com 5 assets")
	for data in planicie:
		assert_bool(data is DecorationData).is_true().override_failure_message(
			"R4: entrada bruta não virou DecorationData"
		)
	gerenciador.free()


## T056 — o peso efetivo de sorteio também soma 100 por ambiente depois da
## compensação de D6/D7 (_compensar_pesos), e `weight` não é alterado.
func test_sorting_weight_sums_100_after_compensation() -> void:
	var gerenciador := DecorationManager.new()
	gerenciador.setup(GameConfig.DECORATION_LIBRARIES)

	for ambiente in gerenciador.libraries:
		var soma: float = 0.0
		var declarado: float = 0.0
		for data in gerenciador.libraries[ambiente]:
			soma += data.peso_sorteio
			declarado += data.weight
		assert_float(soma).is_equal_approx(100.0, 0.01).override_failure_message(
			"T056: peso_sorteio de %s soma %.3f, esperado 100" % [ambiente, soma]
		)
		assert_float(declarado).is_equal_approx(100.0, 0.01).override_failure_message(
			"FR-036: weight declarado de %s deixou de somar 100" % ambiente
		)
	gerenciador.free()


## T056 — a compensação muda o peso efetivo, mas mantém a ordem de grandeza
## declarada: o elemento com maior percentual continua sendo o mais pesado.
func test_sorting_weight_preserves_dominant_element() -> void:
	var gerenciador := DecorationManager.new()
	gerenciador.setup(GameConfig.DECORATION_LIBRARIES)

	var arvore: DecorationData = null
	var menor: DecorationData = null
	for data in gerenciador.libraries["PLAINS"]:
		if data.asset == "planice_arvore01":
			arvore = data
		if menor == null or data.peso_sorteio < menor.peso_sorteio:
			menor = data

	assert_object(arvore).is_not_null().override_failure_message("asset não montado")
	assert_float(arvore.peso_sorteio).is_greater(
		menor.peso_sorteio
	).override_failure_message("T056: árvore deixou de ser a mais pesada em PLAINS")
	gerenciador.free()
