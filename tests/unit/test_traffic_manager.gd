extends GdUnitTestSuite

## Testes do TrafficManager cobrindo I1 a I7 e o MUST de exposição de dados do
## SPEC-005 (FR-025). Usa um dublê de Road com apenas os dois membros que o
## contrato exige (`get_boundaries_for_player_y` e `scroll_speed`), de modo que
## nenhum trecho de cena precise ser montado (contrato §9).

const LEFT: float = 248.0
const NARROW: float = 392.0    # 2 vias: 144 px
const WIDE: float = 424.0      # 4 vias: 176 px

var manager: TrafficManager
## O contrato §4 assina `update(delta: float, road: Road)`, e o GDScript recusa
## em tempo de execução qualquer objeto que não seja `Road`. O dublê portanto
## ESTENDE `Road` (contrato §9) e anula tudo que exigiria cena: `_ready`, pool de
## segmentos e o `_process` de scroll. O que sobra é exatamente a superfície de
## leitura que o manager consome — `scroll_speed` e `get_boundaries_for_player_y`.
## Tipado como `Road` para que os casos de transição (T019) possam trocar o dublê.
var road: Road


## Dublê mínimo de Road.
##
## As larguras são literais porque uma classe interna em GDScript não enxerga o
## escopo da classe externa — `LEFT`/`NARROW` não seriam resolvidas aqui.
class FakeRoad:
	extends Road

	var left: float = 248.0
	var right: float = 392.0

	func _init(p_left: float = 248.0, p_right: float = 392.0) -> void:
		left = p_left
		right = p_right

	func _ready() -> void:
		# Anula a inicialização real (texturas + pool de segmentos).
		pass

	func _process(_delta: float) -> void:
		# Anula o scroll próprio da estrada; só o manager move os veículos.
		pass

	func get_boundaries_for_player_y(_y: float) -> Dictionary:
		return {"left": left, "right": right}

	func get_left_boundary() -> float:
		return left

	func get_right_boundary() -> float:
		return right


## Dublê de Road cuja largura varia com a ALTURA: 144 px (2 vias) no topo,
## 176 px (4 vias) na base, interpoladas na zona de transição (T019).
## Larguras literais porque uma classe interna não enxerga o escopo externo.
class FakeRoadTransicao:
	extends Road

	var esquerda: float = 248.0
	var largura_topo: float = 144.0
	var largura_base: float = 176.0
	var zona_topo: float = -200.0
	var zona_base: float = 240.0

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func largura_em(y: float) -> float:
		var t: float = clampf((y - zona_topo) / maxf(1.0, zona_base - zona_topo), 0.0, 1.0)
		return lerpf(largura_topo, largura_base, t)

	func get_boundaries_for_player_y(y: float) -> Dictionary:
		return {"left": esquerda, "right": esquerda + largura_em(y)}

	func get_left_boundary() -> float:
		return esquerda

	func get_right_boundary() -> float:
		return esquerda + largura_em(0.0)


func _make_categories() -> Dictionary:
	var categories: Dictionary = {}
	for id in GameConfig.TRAFFIC_CATEGORIES:
		categories[id] = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id])
	return categories


func before_test() -> void:
	manager = TrafficManager.new()
	road = FakeRoad.new()
	# Velocidade não nula por padrão: com `scroll_speed == 0.0` o manager
	# corretamente não cria veículos (SC-022), e todo teste de spawn passaria
	# vazio. Quem precisa de rolagem parada zera explicitamente no corpo.
	road.scroll_speed = 80.0
	manager.setup(_make_categories())


func after_test() -> void:
	manager.queue_free()
	if is_instance_valid(road):
		road.free()
	manager = null
	road = null


## I6 — o pool cresce sob demanda em vez de recusar criação (FR-018, SC-025).
func test_pool_grows_on_demand() -> void:
	assert_int(manager.pool_size).is_zero().override_failure_message("Pool deve começar vazio")
	for i in 10:
		manager.update(2.0, road)
	assert_int(manager.pool_size).is_greater(0).override_failure_message("Pool deve crescer sob demanda")
	assert_int(manager.active_count).is_less_equal(GameConfig.traffic_max_vehicles).override_failure_message("I1: nunca excede o limite")


## I1 — active_count nunca excede traffic_max_vehicles (FR-005, SC-005).
func test_never_exceeds_max_vehicles() -> void:
	for i in 600:
		manager.update(1.0, road)
	assert_int(manager.active_count).is_less_equal(GameConfig.traffic_max_vehicles).override_failure_message("I1 violado")


## I3 — todo veículo nasce com y <= -size.y, fora da área visível (FR-013, SC-002).
func test_spawn_above_visible_area() -> void:
	manager.update(5.0, road)
	assert_int(manager.active_count).is_greater(0).override_failure_message("Deve haver ao menos um veículo após alguns quadros")
	for v in manager.active_vehicles:
		assert_float(v.position.y).is_less_equal(-v.category.size.y).override_failure_message("I3: veículo nasceu dentro da área visível")


## I2 — todo veículo ativo fica dentro da área trafegável na sua altura (FR-009).
func test_active_vehicles_inside_lane() -> void:
	manager.update(20.0, road)
	for v in manager.active_vehicles:
		var b: Dictionary = road.get_boundaries_for_player_y(v.position.y)
		assert_float(v.position.x).is_greater_equal(b.left).override_failure_message("I2: veículo à esquerda do limite")
		assert_float(v.position.x).is_less_equal(b.right).override_failure_message("I2: veículo à direita do limite")


## I5 — veículos que saem completamente da área visível são desativados, não ocultados.
func test_recycle_out_of_view() -> void:
	for i in 2000:
		manager.update(0.5, road)
	for v in manager.pool:
		if v.position.y > 700:
			assert_bool(v.is_active()).is_false().override_failure_message("I5: veículo fora da tela continua ativo")


## FR-024 — com o spawn desabilitado nenhum veículo novo é criado. O manager
## congela `GameConfig.traffic_enabled` em `setup()` e passa a operar por
## `set_enabled()` (T041), que é a superfície de runtime do FR-024.
func test_disabled_prevents_new_vehicles() -> void:
	manager.set_enabled(false)
	for i in 300:
		manager.update(1.0, road)
	assert_int(manager.active_count).is_zero().override_failure_message("FR-024: criou veículos com o sistema desabilitado")
	manager.set_enabled(true)


## FR-007 + FR-016 + T015 — com o jogador parado, nenhum veículo NASCE, mas os
## que já estão em cena mantêm o próprio deslocamento, sobem e são reciclados
## ao saírem pelo topo.
func test_zero_scroll_only_suppresses_spawn() -> void:
	road.scroll_speed = 80.0
	manager.update(30.0, road)
	assert_int(manager.active_count).is_greater(0).override_failure_message("Deve haver veículos com a estrada em movimento")

	var antes: Array[Vector2] = []
	for v in manager.active_vehicles:
		antes.append(v.position)
	var tamanho_do_pool: int = manager.pool_size

	road.scroll_speed = 0.0
	for i in 120:
		manager.update(1.0 / 60.0, road)

	# FR-007: com o jogador parado o veículo sobe com a própria velocidade.
	var indice: int = 0
	for v in manager.active_vehicles:
		assert_float(v.position.y).is_less(antes[indice].y).override_failure_message("FR-007: veículo não subiu com o jogador parado")
		indice += 1

	# SC-022: nenhum veículo novo é criado com a estrada parada, então o pool
	# não pode crescer.
	assert_int(manager.pool_size).is_equal(tamanho_do_pool).override_failure_message("SC-022: nasceu veículo com scroll_speed 0.0")

	# FR-016: depois de subir o bastante, todos saem pelo topo e voltam ao pool
	# sem multiplicar objetos.
	for i in 600:
		manager.update(1.0 / 60.0, road)
	assert_int(manager.active_count).is_zero().override_failure_message("FR-016: veículos não foram reciclados ao sair pelo topo")
	assert_int(manager.pool_size).is_equal(tamanho_do_pool).override_failure_message("FR-016: reciclar não pode fazer o pool crescer")


## FR-025 + constitution §Trânsito — get_vehicles_data() devolve um snapshot utilizável.
func test_get_vehicles_data_snapshot() -> void:
	road.scroll_speed = 80.0
	manager.update(30.0, road)
	assert_int(manager.active_count).is_greater(0).override_failure_message("Precisa de veículos para o snapshot")

	var dados: Array[Dictionary] = manager.get_vehicles_data()
	assert_int(dados.size()).is_equal(manager.active_count).override_failure_message("Snapshot deve cobrir todos os veículos ativos")

	# A área ocupada vem da dimensão real medida da textura da categoria (R10).
	# Um `TrafficData` recém-montado a partir do GameConfig ainda tem
	# `size == Vector2.ZERO` — a medida acontece dentro do TrafficManager —,
	# então a referência precisa vir dos veículos ativos.
	var categorias_reais: Dictionary = {}
	for v in manager.active_vehicles:
		categorias_reais[v.get_category_id()] = v.category

	for d in dados:
		assert_dict(d).contains_keys(["id", "position", "occupied_area"]).override_failure_message("Snapshot sem id/position/occupied_area (FR-025)")
		# FR-002: os seis atributos obrigatórios — tipo, posição, velocidade,
		# direção, faixa e estado (T063).
		assert_dict(d).contains_keys(
			["id", "position", "speed", "direction", "lane", "state"]
		).override_failure_message("FR-002: snapshot sem os seis atributos obrigatórios")
		assert_int(int(d["direction"])).is_equal(TrafficVehicle.Direction.FORWARD).override_failure_message(
			"FR-006: todo trânsito segue o mesmo sentido do jogador nesta versão"
		)
		assert_array(GameConfig.TRAFFIC_CATEGORIES.keys()).contains(d["id"]).override_failure_message("id de categoria desconhecido")
		# `is_instanceof()` do GdUnit4 só aceita classe ou instância de Object —
		# um tipo embutido como `Rect2` não é um valor. O teste de tipo fica com
		# o operador `is` do GDScript.
		assert_bool(d["occupied_area"] is Rect2).is_true().override_failure_message("occupied_area deve ser Rect2")
		var categoria: TrafficData = categorias_reais[d["id"]]
		assert_that(d["occupied_area"].size).is_equal(categoria.size)


## FR-025 — o snapshot é um retrato: mexer nele não afeta o manager.
func test_get_vehicles_data_is_a_snapshot() -> void:
	road.scroll_speed = 80.0
	manager.update(30.0, road)
	var dados: Array[Dictionary] = manager.get_vehicles_data()
	if dados.is_empty():
		return
	dados[0]["id"] = " adulterado "
	var novamente: Array[Dictionary] = manager.get_vehicles_data()
	assert_str(novamente[0]["id"]).is_not_equal(" adulterado ").override_failure_message("Snapshot deve ser uma cópia, não uma referência viva")


## Troca o dublê liberando o anterior (o `after_test` só libera o último).
func _trocar_road(nova: Road) -> void:
	if is_instance_valid(road):
		road.free()
	road = nova


## T019 / FR-014, I2 — o spawn valida a faixa livre NA ALTURA DE CRIAÇÃO, mesmo
## quando a largura muda ao longo da altura (zona de transição 2 <-> 4 vias).
func test_spawn_validates_free_lane_at_its_height() -> void:
	_trocar_road(FakeRoadTransicao.new())
	# Roda do jogador na velocidade máxima (100): é a situação em que TODAS as
	# categorias são ultrapassáveis e descem a tela — com 80 (a do teste antigo)
	# a categoria de 120 km/h sobe e a de 100 km/h fica parada na linha de spawn.
	road.scroll_speed = GameConfig.max_speed

	# Contado POR QUADRO: ao fim da simulação os veículos que cruzaram a
	# zona já passaram dela e a contagem no estado final seria sempre zero.
	var na_transicao: int = 0
	for i in 3600:
		manager.update(1.0 / 60.0, road)
		for v in manager.active_vehicles:
			if v.position.y > -200.0 and v.position.y < 240.0:
				na_transicao += 1

	assert_int(manager.active_count).is_greater(0).override_failure_message(
		"T019: nenhum veículo nasceu na faixa em transição"
	)

	for v in manager.active_vehicles:
		var b: Dictionary = road.get_boundaries_for_player_y(v.position.y)
		var meia: float = v.category.size.x * 0.5
		assert_float(v.position.x).is_greater_equal(
			float(b["left"]) + meia
		).override_failure_message("T019: veículo à esquerda da faixa na sua altura")
		assert_float(v.position.x).is_less_equal(
			float(b["right"]) - meia
		).override_failure_message("T019: veículo à direita da faixa na sua altura")

	assert_int(na_transicao).is_greater(0).override_failure_message(
		"T019: nenhum veículo cruzou a zona de transição de larguras"
	)


## T019 / FR-021, FR-051, R8 — ao estreitar, o veículo é reposicionado de forma
## CONTÍNUA: sem salto do tamanho da redução e terminando dentro da faixa nova.
func test_continuous_reposition_when_narrowing() -> void:
	_trocar_road(FakeRoad.new(248.0, 424.0))  # 4 vias
	road.scroll_speed = 80.0
	for i in 600:
		manager.update(1.0 / 60.0, road)
	assert_int(manager.active_count).is_greater(0).override_failure_message(
		"T019: preciso de veículos na pista larga"
	)

	# O mais jovem é o que está longe da borda e não será reciclado no teste.
	var alvo: TrafficVehicle = null
	for v in manager.active_vehicles:
		if alvo == null or v.position.y < alvo.position.y:
			alvo = v
	alvo.position.x = 410.0
	alvo.lane_position = 410.0
	alvo.previous_right_boundary = 424.0

	var passo_max: float = 0.0
	var x_anterior: float = alvo.position.x
	# A faixa encolhe de forma gradual, como o Road real faz durante a
	# transição de 4 para 2 vias (FR-021, R8).
	for i in 60:
		road.right = lerpf(424.0, 392.0, float(i + 1) / 60.0)
		manager.update(1.0 / 60.0, road)
		if alvo.is_active():
			passo_max = maxf(passo_max, absf(alvo.position.x - x_anterior))
			x_anterior = alvo.position.x

	assert_bool(alvo.is_active()).is_true().override_failure_message(
		"T019: veículo reciclado durante a transição"
	)
	assert_float(x_anterior).is_less(
		410.0
	).override_failure_message("FR-021: veículo não foi reposicionado ao estreitar")
	assert_float(passo_max).is_less(32.0).override_failure_message(
		"FR-051: salto lateral de uma peça só durante o estreitamento"
	)
	assert_float(x_anterior).is_less_equal(
		392.0 - alvo.category.size.x * 0.5
	).override_failure_message("I2: veículo ficou fora da faixa estreita")


## T019 / FR-019, SC-006 — todo veículo recém-nascido mantém o espaçamento
## longitudinal mínimo em relação a todos os demais ativos.
func test_no_immediate_overlap_after_spawn() -> void:
	_trocar_road(FakeRoad.new())
	# 60 s de corrida com o jogador na velocidade máxima. Com 80 px/s a categoria
	# de 100 km/h empatava com a estrada, ficava parada na linha de criação e
	# travava o espaçamento (FR-019) para sempre — nascimentos dependiam da sorte.
	road.scroll_speed = GameConfig.max_speed

	var conhecidos: Array = []
	var nascimentos: int = 0
	for i in 3600:
		manager.update(1.0 / 60.0, road)
		for v in manager.active_vehicles:
			if conhecidos.has(v):
				continue
			conhecidos.append(v)
			nascimentos += 1
			for outro in manager.active_vehicles:
				if outro == v:
					continue
				assert_float(absf(v.position.y - outro.position.y)).is_greater_equal(
					GameConfig.traffic_min_spacing - 0.5
				).override_failure_message(
					"FR-019: veículo nasciu colado em outro (espaçamento mínimo)"
				)

	assert_int(nascimentos).is_greater(3).override_failure_message(
		"T019: poucos nascimentos para validar o espaçamento"
	)


## Retângulo visível do veículo tem algum pixel na viewport 640x480.
func _tem_pixel_visivel(v: TrafficVehicle) -> bool:
	var metade: Vector2 = v.category.size * 0.5
	var r := Rect2(v.position - metade, v.category.size)
	return r.intersects(Rect2(0, 0, 640, 480))


## T064 / SC-023, US3/AC6 — durante a redução contínua de 4 para 2 vias, ZERO
## veículos aparecem ou desaparecem da área visível por causa da mudança de
## largura, e 100% permanecem dentro da área trafegável do início ao fim.
##
## O spawn é desligado na medição para que todo "aparecimento" seja atribuível
## à largura (e não a um birth legítimo acima do topo), e a única saída da
## tela considerada legítima é o cruzamento da borda vertical (topo/base) —
## o deslocamento longitudinal do próprio veículo (FR-007), nunca o estreitar.
func test_sc023_no_blink_during_narrowing() -> void:
	# Popula a pista larga (4 vias, 176 px).
	_trocar_road(FakeRoad.new(248.0, 424.0))
	road.scroll_speed = 80.0
	for i in 1800:
		manager.update(1.0 / 60.0, road)
	assert_int(manager.active_count).is_greater(0).override_failure_message(
		"SC-023: preciso de trânsito na pista larga antes de estreitar"
	)

	# Sem nascimentos durante a redução (FR-024 aos poucos, aqui por set_enabled).
	manager.set_enabled(false)

	var visivel_antes: Dictionary = {}
	var piscadas: Array[String] = []
	var passos: int = 120  # 2 s de redução contínua 176 -> 144 px
	for i in passos:
		(road as FakeRoad).right = lerpf(424.0, 392.0, float(i + 1) / float(passos))
		manager.update(1.0 / 60.0, road)

		for v in manager.active_vehicles:
			# 100% dentro da área trafegável na própria altura, do início ao fim.
			var b: Dictionary = road.get_boundaries_for_player_y(v.position.y)
			var meia: float = v.category.size.x * 0.5
			assert_float(v.position.x).is_greater_equal(
				float(b["left"]) + meia - 0.01
			).override_failure_message("SC-023: veículo à esquerda da faixa no estreitamento")
			assert_float(v.position.x).is_less_equal(
				float(b["right"]) - meia + 0.01
			).override_failure_message("SC-023: veículo à direita da faixa no estreitamento")

			var id: int = v.get_instance_id()
			var visivel: bool = _tem_pixel_visivel(v)
			if visivel_antes.has(id) and bool(visivel_antes[id]) != visivel:
				# Piscar no MEIO da tela só pode ser efeito da largura: a
				# reciclagem legítima (I5) e a entrada pelo topo exigem o
				# veículo encostado na borda vertical.
				var meia_y: float = v.category.size.y * 0.5
				var na_borda_vertical: bool = (
					v.position.y - meia_y <= 1.0 or v.position.y + meia_y >= 479.0
				)
				if not na_borda_vertical:
					piscadas.append("%s em y=%.1f" % [v.get_category_id(), v.position.y])
			visivel_antes[id] = visivel

	assert_array(piscadas).is_empty().override_failure_message(
		"SC-023: veículos apareceram ou sumiram no meio da tela durante a redução: %s"
		% str(piscadas)
	)
	assert_int(manager.active_count).is_greater(0).override_failure_message(
		"SC-023: o estreitamento eliminou o trânsito inteiro"
	)
	manager.set_enabled(true)


## T065 / SC-003, US1/AC4, FR-007 — quando a velocidade do jogador cruza a do
## veículo, a direção relativa inverte de forma CONTÍNUA: o deslocamento por
## quadro muda de sinal no cruzamento, sem salto, e o veículo nunca fica parado
## sobre a tela fora do quadro exato do cruzamento.
##
## Cenário controlado: um único veículo `esporte` (96.0 unidades) no meio da
## tela, com a estrada varrida de 60.0 até 100.0 (a máxima, cruzando 96.0).
## Com um único veículo não há líder, então o espaçamento de FR-019 não interfere.
func test_sc003_continuous_inversion_when_crossing_vehicle_speed() -> void:
	var esporte: TrafficData = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES["esporte"])
	esporte.garantir_size()

	var v: TrafficVehicle = manager._obter_do_pool()
	v.activate(esporte, 320.0, 240.0)
	v.previous_right_boundary = 392.0
	manager.active_vehicles.append(v)
	manager.set_enabled(false)

	var delta: float = 1.0 / 60.0
	var passos: int = 40  # 60.0 -> 100.0 em passos de 1.0 unidade
	var sinal_anterior: int = 0
	var inversoes: int = 0
	var quadros_parados: int = 0
	var passo_max: float = 0.0

	for i in passos + 1:
		road.scroll_speed = lerpf(60.0, GameConfig.max_speed, float(i) / float(passos))
		var y_anterior: float = v.position.y
		manager.update(delta, road)

		var deslocamento: float = v.position.y - y_anterior
		passo_max = maxf(passo_max, absf(deslocamento))
		if absf(deslocamento) < 0.0001:
			# Só é admissível no quadro exato do cruzamento (veículo e estrada
			# na MESMA velocidade): qualquer parada com diferença de velocidade
			# viola SC-003.
			quadros_parados += 1
			assert_float(absf(road.scroll_speed - esporte.max_speed)).is_less(
				0.001
			).override_failure_message(
				"SC-003: veículo parado na tela com estrada a %.2f e veículo a %.2f"
				% [road.scroll_speed, esporte.max_speed]
			)
			continue

		# FR-007: o sinal do deslocamento é o sinal de (estrada - veículo):
		# o veículo sobe enquanto é mais rápido e desce quando é ultrapassado.
		var sinal: int = signi(int(road.scroll_speed - esporte.max_speed))
		assert_int(int(sign(deslocamento))).is_equal(sinal).override_failure_message(
			"FR-007: deslocamento %.3f não corresponde à diferença estrada-veículo %.2f"
			% [deslocamento, road.scroll_speed - esporte.max_speed]
		)
		if sinal != 0 and sinal_anterior != 0 and sinal != sinal_anterior:
			inversoes += 1
		if sinal != 0:
			sinal_anterior = sinal

	assert_int(quadros_parados).is_less_equal(1).override_failure_message(
		"SC-003: %d quadros parados sobre a tela durante a troca de direção"
		% quadros_parados
	)
	assert_int(inversoes).is_equal(1).override_failure_message(
		"SC-003: a direção relativa deveria inverter exatamente uma vez no cruzamento"
	)
	# Continuidade: nenhum quadro desloca mais que a maior diferença de
	# velocidade possível por quadro — sem salto na inversão (R8).
	assert_float(passo_max).is_less_equal(
		(GameConfig.max_speed - 60.0 + esporte.max_speed) * delta + 0.001
	).override_failure_message("SC-003: salto de %.3f px num quadro" % passo_max)
	manager.set_enabled(true)