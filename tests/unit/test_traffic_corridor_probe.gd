extends GdUnitTestSuite

## SONDA TEMPORÁRIA de diagnóstico (cenários DESERT/FOREST) — NÃO é regressão
## de spec. Depois do diagnóstico, este arquivo deve ser removido ou
## reescrito como teste de regressão da decisão tomada no /speckit.clarify.
##
## Simula minutos reais com Road REAL (sequência de segmentos variando os
## bounds por altura), TrafficManager com o validador SPEC-006 ligado, SEM
## jogador (isenta a ultrapassagem do SPEC-005) e com a velocidade da
## estrada variando (máximo → freio → entre categorias → rampa). Procura:
##
##   A) par de velocidades DIFERENTES no mesmo corredor com o de CIMA mais
##      lento que o de baixo (arranjo "fechante" — proibido no nascimento);
##   B) truncamento do movimento pelo limitador (FR-019) envolvendo
##      velocidades diferentes — o "grude" do FOREST;
##   C) mudança de x sem estreitamento de pista, sem ultrapassagem e sem
##      drift (caminho de deslocamento lateral desconhecido);
##   D) contato NPC×NPC (sinal npc_collision_occurred) — sem jogador, não
##      deveria existir nenhum caminho para contato.
##
## Contadores de contexto (não falham o teste): freezes legítimos de spawn
## apertado, pares de mesma velocidade no mesmo corredor e pares de
## velocidades diferentes em arranjo correto (fallback de faixa).

const DELTA: float = 1.0 / 60.0
const QUADROS: int = 7200  ## 2 min por semente
const SEMENTES := [1, 7, 42, 20261008, 1337]
const LIMITE_REGISTROS: int = 6

## Achados (across sementes)
var _achado_a: Array = []  ## arranjo fechante no mesmo corredor
var _achado_a_quadros: int = 0
var _achado_b: Array = []  ## truncamento com arranjo fechante
var _achado_b_quadros: int = 0
var _achado_c: Array = []  ## x mudou sem motivo conhecido
var _achado_c_quadros: int = 0
var _achado_d: Array = []  ## contato NPC×NPC sem jogador
var _achado_d_quadros: int = 0

## Contexto
var _spawns_totais: int = 0
var _pares_iguais: int = 0
var _pares_diferentes_corretos: int = 0
var _freeze_igual: int = 0
var _freeze_diferente_correto: int = 0
var _x_por_motivo: Dictionary = {}
var _velocidades_vistas: Dictionary = {}

## Transientes por semente
var _quadro_atual: int = 0
var _reg_spawn: Dictionary = {}
var _estado: Dictionary = {}

var _sequencia_original: Array = []


func before_test() -> void:
	_sequencia_original = GameConfig.test_track_sequence.duplicate(true)
	# Ciclo curto para garantir segmentos EXPANDIDOS acima da faixa de spawn
	# (bounds largos) dentro de cada semente.
	GameConfig.test_track_sequence = [[0, 3], [3, 3], [1, 1], [2, 1]]


func after_test() -> void:
	GameConfig.test_track_sequence = _sequencia_original


func test_sonda_corredor_sem_jogador() -> void:
	for semente in SEMENTES:
		_rodar_semente(semente)

	var resumo: String = _resumo_geral()
	print(resumo)
	for achado in _achado_a:
		print("  A: %s" % _fmt(achado))
	for achado in _achado_b:
		print("  B: %s" % _fmt(achado))
	for achado in _achado_c:
		print("  C: %s" % _fmt(achado))
	for achado in _achado_d:
		print("  D: %s" % _fmt(achado))

	# Sanidade: a sonda precisa ter vivido trânsito real para valer alguma coisa.
	assert_int(_spawns_totais).is_greater_equal(80).override_failure_message(
		"Sonda vazia: só %d nascimentos em %d quadros — o cenário não gerou trânsito"
		% [_spawns_totais, QUADROS * SEMENTES.size()]
	)
	assert_int(_velocidades_vistas.size()).is_greater_equal(4).override_failure_message(
		"Sonda vazia: só %d velocidades de estrada vistas — o perfil não variou"
		% _velocidades_vistas.size()
	)
	var pares_corredor: int = _pares_iguais + _pares_diferentes_corretos + _achado_a_quadros
	assert_int(pares_corredor).is_greater_equal(50).override_failure_message(
		"Sonda vazia: só %d pares no mesmo corredor observados" % pares_corredor
	)

	# Evidências A/B/C/D são só reportadas (print acima), sem falhar a suíte,
	# até o clarify da SPEC-006 definir o comportamento esperado; aí os
	# contadores viram asserts de aceitação.


func _rodar_semente(semente: int) -> void:
	seed(semente)
	_reg_spawn.clear()
	_estado.clear()

	var road := Road.new()
	road._ready()  # fora da árvore: build manual do pool (mesmo recorte dos testes)

	var manager := TrafficManager.new()
	var categorias := {}
	for id in GameConfig.TRAFFIC_CATEGORIES:
		categorias[id] = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id])
	manager.setup(categorias)

	var sistema := NpcCollisionSystem.new()
	manager.validador = sistema
	manager.vehicle_spawned.connect(_on_spawn)
	manager.vehicle_recycled.connect(
		func(_v): sistema.marcar_reavaliacao()
	)
	sistema.npc_collision_occurred.connect(_on_contato)

	for quadro in QUADROS:
		_quadro_atual = quadro
		var v_estrada: float = _velocidade_estrada(quadro)
		_velocidades_vistas[v_estrada] = true
		road.scroll_speed = v_estrada
		road._process(DELTA)

		manager.update(DELTA, road)
		var snapshot: Array[TrafficVehicle] = manager.active_vehicles_snapshot
		sistema.update(
			DELTA,
			snapshot,
			Callable(road, "get_boundaries_for_player_y"),
			road.scroll_speed
		)

		_verificar(quadro, v_estrada, road, snapshot)

	manager.free()
	road.free()


## Perfil da velocidade da estrada: cobre todos os regimes relevantes —
## todas descendo (máximo), todas subindo (freio), pares em sentidos opostos
## (76, entre passeio 80 e caminhão 72), misto (95, entre passeio e esporte)
## e rampa contínua de desaceleração.
func _velocidade_estrada(quadro: int) -> float:
	var bloco: int = int(quadro / 600.0) % 5
	match bloco:
		0:
			return 100.0
		1:
			return 60.0
		2:
			return 76.0
		3:
			return 95.0
		_:
			return 100.0 - 45.0 * float(quadro % 600) / 600.0


func _right_em(road: Road, y: float) -> float:
	return float(road.get_boundaries_for_player_y(y).get("right", 392.0))


func _on_spawn(v: TrafficVehicle) -> void:
	_spawns_totais += 1
	_reg_spawn[v.get_instance_id()] = {
		"quadro": _quadro_atual,
		"cat": v.category.id if v.category != null else "?",
		"x": v.position.x,
		"y": v.position.y,
	}


func _on_contato(data: NpcCollisionData) -> void:
	_achado_d_quadros += 1
	if _achado_d.size() >= LIMITE_REGISTROS:
		return
	var causador: TrafficVehicle = data.causador
	var atingido: TrafficVehicle = data.atingido
	_achado_d.append({
		"quadro": _quadro_atual,
		"tipo": "LONGITUDINAL" if data.tipo == NpcCollisionData.Tipo.LONGITUDINAL else "LATERAL",
		"causador": causador.category.id if causador != null and causador.category != null else "?",
		"atingido": atingido.category.id if atingido != null and atingido.category != null else "?",
		"x_c": causador.position.x if causador != null else 0.0,
		"y_c": causador.position.y if causador != null else 0.0,
		"x_a": atingido.position.x if atingido != null else 0.0,
		"y_a": atingido.position.y if atingido != null else 0.0,
		"intensidade": data.intensidade,
	})


func _verificar(
	quadro: int,
	v_estrada: float,
	road: Road,
	snapshot: Array[TrafficVehicle]
) -> void:
	# Zera o histórico de quem saiu (reciclado neste quadro).
	var atuais: Dictionary = {}
	for v in snapshot:
		atuais[v.get_instance_id()] = true
	for id in _estado.keys():
		if not atuais.has(id):
			_estado.erase(id)

	# A — pares no mesmo corredor: arranjo correto (contexto) ou fechante (A).
	for i in snapshot.size():
		var va: TrafficVehicle = snapshot[i]
		if va.category == null:
			continue
		for j in range(i + 1, snapshot.size()):
			var vb: TrafficVehicle = snapshot[j]
			if vb.category == null:
				continue
			var folga_x: float = (
				absf(va.position.x - vb.position.x)
				- (va.category.size.x + vb.category.size.x) * 0.5
			)
			if folga_x >= 0.0:
				continue  # corredor distinto
			var dy: float = va.position.y - vb.position.y
			if absf(dy) < 0.001:
				continue
			var topo: TrafficVehicle = va if dy < 0.0 else vb
			var base: TrafficVehicle = vb if dy < 0.0 else va
			if absf(topo.get_speed() - base.get_speed()) < 0.001:
				_pares_iguais += 1
			elif topo.get_speed() < base.get_speed():
				_achado_a_quadros += 1
				if _achado_a.size() < LIMITE_REGISTROS:
					_achado_a.append(
						_par_record(quadro, v_estrada, topo, base, "fechante")
					)
			else:
				_pares_diferentes_corretos += 1

	# B e C — exige continuidade desde o quadro anterior (mesmo nó ativo).
	for v in snapshot:
		if v.category == null:
			continue
		var id: int = v.get_instance_id()
		if not _estado.has(id):
			continue
		var reg: Dictionary = _estado[id]
		if int(reg["quadro"]) != quadro - 1:
			continue  # nasceu/reciclado no intervalo
		var sp: Dictionary = _reg_spawn.get(id, {})
		if int(sp.get("quadro", -1)) == quadro:
			# Reutilizado do pool neste mesmo quadro: o histórico pertence à
			# vida anterior do nó (o y pode ter coincidido no enchimento).
			continue
		var dy_real: float = v.position.y - float(reg["y"])
		if absf(dy_real) > 50.0:
			continue  # salto de pool (reciclagem), não é movimento

		# B — taxa real contra a taxa própria da categoria.
		var esperado: float = -(v.get_speed() - v_estrada) * DELTA
		if absf(dy_real - esperado) >= 0.002:
			var parceiro: TrafficVehicle = _parceiro_diferente(v, snapshot)
			if parceiro == null:
				_freeze_igual += 1
			else:
				var fechante: bool = (
					(v.position.y < parceiro.position.y and v.get_speed() < parceiro.get_speed())
					or (parceiro.position.y < v.position.y and parceiro.get_speed() < v.get_speed())
				)
				if fechante:
					_achado_b_quadros += 1
					if _achado_b.size() < LIMITE_REGISTROS:
						_achado_b.append({
							"quadro": quadro,
							"estrada": v_estrada,
							"veiculo": v.category.id,
							"speed": v.get_speed(),
							"dy_real": dy_real,
							"esperado": esperado,
							"parceiro": parceiro.category.id,
							"speed_parceiro": parceiro.get_speed(),
							"y": v.position.y,
							"y_parceiro": parceiro.position.y,
							"x": v.position.x,
							"x_parceiro": parceiro.position.x,
							"spawn": str(_reg_spawn.get(id, {})),
						})
				else:
					_freeze_diferente_correto += 1

		# C — mudança de x sem motivo conhecido.
		var dx: float = v.position.x - float(reg["x"])
		if absf(dx) >= 0.01:
			var motivo: String = "???"
			if _right_em(road, v.position.y) < float(reg["right"]) - 0.01:
				motivo = "estreitamento"
			elif v.overtake.ativo():
				motivo = "overtake"
			elif v.npc_drift.ativo():
				motivo = "drift"
			if motivo == "???":
				_achado_c_quadros += 1
				if _achado_c.size() < LIMITE_REGISTROS:
					_achado_c.append({
						"quadro": quadro,
						"veiculo": v.category.id,
						"dx": dx,
						"x": v.position.x,
						"x_antes": float(reg["x"]),
						"y": v.position.y,
						"estrada": v_estrada,
						"spawn": str(_reg_spawn.get(id, {})),
					})
			else:
				_x_por_motivo[motivo] = int(_x_por_motivo.get(motivo, 0)) + 1

	# Atualiza o histórico com a posição do fim do quadro.
	for v in snapshot:
		if v.category == null:
			continue
		_estado[v.get_instance_id()] = {
			"quadro": quadro,
			"x": v.position.x,
			"y": v.position.y,
			"cat": v.category.id,
			"right": _right_em(road, v.position.y),
		}


## Primeiro veículo ativo no MESMO corredor de `v` com velocidade DIFERENTE.
func _parceiro_diferente(
	v: TrafficVehicle, snapshot: Array[TrafficVehicle]
) -> TrafficVehicle:
	for w in snapshot:
		if w == v or w.category == null:
			continue
		var folga_x: float = (
			absf(v.position.x - w.position.x)
			- (v.category.size.x + w.category.size.x) * 0.5
		)
		if folga_x < 0.0 and absf(w.get_speed() - v.get_speed()) >= 0.001:
			return w
	return null


func _par_record(
	quadro: int, v_estrada: float, topo: TrafficVehicle, base: TrafficVehicle, rotulo: String
) -> Dictionary:
	return {
		"quadro": quadro,
		"rotulo": rotulo,
		"estrada": v_estrada,
		"topo": "%s(%.0f)@%.0f,%.0f" % [topo.category.id, topo.get_speed(), topo.position.x, topo.position.y],
		"base": "%s(%.0f)@%.0f,%.0f" % [base.category.id, base.get_speed(), base.position.x, base.position.y],
		"spawn_topo": str(_reg_spawn.get(topo.get_instance_id(), {})),
		"spawn_base": str(_reg_spawn.get(base.get_instance_id(), {})),
	}


func _fmt(reg: Dictionary) -> String:
	var partes: Array = []
	for chave in reg:
		partes.append("%s=%s" % [chave, str(reg[chave])])
	return " | ".join(partes)


func _lista(registros: Array) -> String:
	if registros.is_empty():
		return "  (nenhum registro — ver contadores do resumo)"
	var linhas: Array = []
	for reg in registros:
		linhas.append("  - " + _fmt(reg))
	return "\n".join(linhas)


func _resumo_geral() -> String:
	var motivos: Array = []
	for motivo in _x_por_motivo:
		motivos.append("%s=%d" % [motivo, _x_por_motivo[motivo]])
	return (
		"SONDA corredor | sementes=%d quadros/sem=%d | spawns=%d | "
		+ "pares_iguais=%d pares_dif_corretos=%d | "
		+ "A_quadros=%d B_errado_quadros=%d B_freeze_igual=%d B_freeze_dif_correto=%d | "
		+ "C_quadros=%d C_x_motivos=[%s] | D_contatos=%d | estradas_vistas=%d"
	) % [
		SEMENTES.size(),
		QUADROS,
		_spawns_totais,
		_pares_iguais,
		_pares_diferentes_corretos,
		_achado_a_quadros,
		_achado_b_quadros,
		_freeze_igual,
		_freeze_diferente_correto,
		_achado_c_quadros,
		", ".join(motivos),
		_achado_d_quadros,
		_velocidades_vistas.size(),
	]
