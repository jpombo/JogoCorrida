extends GdUnitTestSuite

## SPEC-011 / T004+T008+T014+T025 — ProgressManager: materialização e
## tolerância de carga (data-model §1/§3), fórmula/recordes/histórico por
## modo (SC-001/SC-011), ciclo de troféus (SC-004/SC-005, FR-009…FR-011) e
## desbloqueio derivado de obstáculos (SC-007, FR-018/FR-019).

const SEQUENCIA: Array = ["PLAINS", "DESERT", "FOREST", "ICE"]


func _pm() -> ProgressManager:
	return ProgressManager.new()


## T004 — `carregar_de({})` materializa os 3 modos canônicos com defaults.
func test_01_carregar_vazio_materializa_modos() -> void:
	var pm := _pm()
	pm.carregar_de({})
	for modo in ProgressManager.MODOS:
		assert_float(pm.get_recorde(modo)).is_equal(0.0)
		assert_float(pm.get_acumulada(modo)).is_equal(0.0)
		assert_int(pm.get_trofeus(modo)).is_equal(0)
		assert_int(pm.get_ciclo(modo).size()).is_equal(0)


## T004 — modo faltante nos dados persistidos ⇒ só ele nasce com default.
func test_02_tolerancia_a_modo_faltante() -> void:
	var pm := _pm()
	pm.carregar_de({"modos": {"normal": {"recorde": 9.0, "trofeus": 2}}})
	assert_float(pm.get_recorde("normal")).is_equal_approx(9.0, 0.001)
	assert_int(pm.get_trofeus("normal")).is_equal(2)
	assert_float(pm.get_recorde("relaxing")).is_equal(0.0)
	assert_float(pm.get_recorde("challenge")).is_equal(0.0)


## T004 — ciclo com duplicata e ambiente fora da sequência ⇒ deduplicado e
## limpo na carga.
func test_03_ciclo_duplicata_e_invalido_limpos() -> void:
	var pm := _pm()
	pm.carregar_de({"modos": {"relaxing": {"ciclo": ["PLAINS", "PLAINS", "XXX", "DESERT"]}}})
	var ciclo: Array = pm.get_ciclo("relaxing")
	assert_int(ciclo.size()).is_equal(2)
	assert_str(ciclo[0]).is_equal("PLAINS")
	assert_str(ciclo[1]).is_equal("DESERT")


## T004 — histórico acima do teto é aparado preservando os MAIS RECENTES.
func test_04_historico_acima_do_teto() -> void:
	var entradas: Array = []
	for i in 70:
		entradas.append({"modo": "normal", "pontuacao": float(i)})
	var pm := _pm()
	pm.carregar_de({"historico": entradas})
	var dados: Dictionary = pm.dados_para_salvar()
	var hist: Array = dados["historico"]
	assert_int(hist.size()).is_equal(GameConfig.score_historico_max)
	assert_float(float(hist[hist.size() - 1]["pontuacao"])).is_equal_approx(69.0, 0.001)


## T004 — `dados_para_salvar()` devolve o esquema v1 completo (data-model §3).
func test_05_dados_para_salvar_esquema_v1() -> void:
	var pm := _pm()
	pm.processar_vitoria("normal", "PLAINS", 3.0, 0.0, "2026-10-17T12:00:00")
	var dados: Dictionary = pm.dados_para_salvar()
	assert_int(int(dados["versao"])).is_equal(ProgressManager.VERSAO_ESQUEMA)
	assert_bool(dados.has("modos")).is_true()
	assert_bool(dados.has("historico")).is_true()
	for modo in ProgressManager.MODOS:
		assert_bool((dados["modos"] as Dictionary).has(modo)).is_true()
	var entrada: Dictionary = (dados["historico"] as Array)[0]
	for campo in ["modo", "ambiente", "distancia", "pontuacao", "trofeus", "perda_colisao", "data_hora"]:
		assert_bool(entrada.has(campo)).is_true().override_failure_message(
			"Resultado persistido sem o campo %s (data-model §1.1)" % campo
		)


## T008 — primeiro resultado inicializa o recorde; superação ESTRITA
## atualiza; empate e valor menor não atualizam (SC-001).
func test_06_recorde_superacao_estrita() -> void:
	var pm := _pm()
	pm.processar_vitoria("normal", "PLAINS", 1.0, 0.0, "t")
	var r1: float = pm.get_recorde("normal")
	assert_bool(r1 > 0.0).is_true()

	pm.processar_vitoria("normal", "DESERT", 1.0, 0.0, "t")  # mesma pontuação ⇒ empate
	assert_float(pm.get_recorde("normal")).is_equal_approx(r1, 0.001)

	pm.processar_vitoria("normal", "FOREST", 0.5, 0.0, "t")  # menor
	assert_float(pm.get_recorde("normal")).is_equal_approx(r1, 0.001)

	pm.processar_vitoria("normal", "ICE", 2.0, 0.0, "t")  # maior
	assert_bool(pm.get_recorde("normal") > r1).is_true()


## T008 — zero cruzamento entre modos: recorde/acumulada/troféus de um
## modo nunca aparecem no outro (SC-001).
func test_07_independencia_entre_modos() -> void:
	var pm := _pm()
	pm.processar_vitoria("challenge", "PLAINS", 5.0, 0.0, "t")
	assert_bool(pm.get_recorde("challenge") > 0.0).is_true()
	assert_float(pm.get_recorde("normal")).is_equal(0.0)
	assert_float(pm.get_recorde("relaxing")).is_equal(0.0)
	assert_float(pm.get_acumulada("normal")).is_equal(0.0)


## T008 — histórico trima no teto mesmo por vitórias sucessivas.
func test_08_historico_trim_por_vitorias() -> void:
	var pm := _pm()
	var total: int = GameConfig.score_historico_max + 5
	for i in total:
		pm.processar_vitoria("normal", "PLAINS", 0.1, 0.0, "t%d" % i)
	var hist: Array = pm.dados_para_salvar()["historico"]
	assert_int(hist.size()).is_equal(GameConfig.score_historico_max)


## T008/SC-011 — derrota não cria resultado nem toca no recorde.
func test_09_derrota_sem_resultado_sem_recorde() -> void:
	var pm := _pm()
	pm.processar_vitoria("normal", "PLAINS", 2.0, 0.0, "t")
	var recorde: float = pm.get_recorde("normal")
	var hist_antes: int = (pm.dados_para_salvar()["historico"] as Array).size()

	var snap: Dictionary = pm.processar_derrota("normal")

	assert_int((pm.dados_para_salvar()["historico"] as Array).size()).is_equal(hist_antes)
	assert_float(pm.get_recorde("normal")).is_equal_approx(recorde, 0.001)
	assert_float(float(snap["pontuacao"])).is_equal(-1.0)


## T014/SC-004 — 4 ambientes distintos ⇒ exatamente +1 troféu e ciclo zerado.
func test_10_quatro_ambientes_concedem_um_trofeu() -> void:
	var pm := _pm()
	for env in SEQUENCIA:
		pm.processar_vitoria("relaxing", env, 1.0, 0.0, "t")
	assert_int(pm.get_trofeus("relaxing")).is_equal(1)
	assert_int(pm.get_ciclo("relaxing").size()).is_equal(0)


## T014/FR-010 — repetição de ambiente no mesmo ciclo é no-op total.
func test_11_ambiente_repetido_noop() -> void:
	var pm := _pm()
	pm.processar_vitoria("relaxing", "PLAINS", 1.0, 0.0, "t")
	pm.processar_vitoria("relaxing", "PLAINS", 1.0, 0.0, "t")
	assert_int(pm.get_ciclo("relaxing").size()).is_equal(1)
	assert_int(pm.get_trofeus("relaxing")).is_equal(0)


## T014/FR-011 — 3 ciclos completos ⇒ 3 troféus.
func test_12_tres_ciclos_tres_trofeus() -> void:
	var pm := _pm()
	for ciclo in 3:
		for env in SEQUENCIA:
			pm.processar_vitoria("relaxing", env, 1.0, 0.0, "t")
	assert_int(pm.get_trofeus("relaxing")).is_equal(3)


## T014/SC-005 — derrota zera o ciclo e preserva o total de troféus.
func test_13_derrota_zera_ciclo_preserva_total() -> void:
	var pm := _pm()
	for env in ["PLAINS", "DESERT", "FOREST"]:
		pm.processar_vitoria("normal", env, 1.0, 0.0, "t")
	pm.processar_derrota("normal")
	assert_int(pm.get_ciclo("normal").size()).is_equal(0)
	assert_int(pm.get_trofeus("normal")).is_equal(0)

	# Ciclo completo de novo para provar que o total continua subindo.
	for env in SEQUENCIA:
		pm.processar_vitoria("normal", env, 1.0, 0.0, "t")
	assert_int(pm.get_trofeus("normal")).is_equal(1)


## T014 — operações em um modo não tocam o outro (troféus E ciclo).
func test_14_isolamento_de_modo_trofeus() -> void:
	var pm := _pm()
	for env in SEQUENCIA:
		pm.processar_vitoria("relaxing", env, 1.0, 0.0, "t")
	assert_int(pm.get_trofeus("relaxing")).is_equal(1)
	assert_int(pm.get_trofeus("normal")).is_equal(0)
	assert_int(pm.get_ciclo("normal").size()).is_equal(0)


## T025/SC-007 — Relaxante nasce bloqueado e desbloqueia com ≥1 troféu;
## Normal/Desafio sempre livres (FR-018/FR-019).
func test_15_desbloqueio_por_trofeu_relaxing() -> void:
	var pm := _pm()
	assert_bool(pm.obstaculos_disponiveis("relaxing")).is_false()
	assert_bool(pm.obstaculos_disponiveis("normal")).is_true()
	assert_bool(pm.obstaculos_disponiveis("challenge")).is_true()

	for env in SEQUENCIA:
		pm.processar_vitoria("relaxing", env, 1.0, 0.0, "t")
	assert_bool(pm.obstaculos_disponiveis("relaxing")).is_true()


## T025 — troféus de outros modos nunca desbloqueiam o Relaxante.
func test_16_trofeus_de_outros_modos_nao_desbloqueiam() -> void:
	var pm := _pm()
	for env in SEQUENCIA:
		pm.processar_vitoria("normal", env, 1.0, 0.0, "t")
		pm.processar_vitoria("challenge", env, 1.0, 0.0, "t")
	assert_bool(pm.obstaculos_disponiveis("relaxing")).is_false()


## T025 — o desbloqueio sobrevive ao round-trip de persistência (derivado,
## nunca armazenado — research R2/R19).
func test_17_desbloqueio_sobrevive_round_trip() -> void:
	var pm := _pm()
	for env in SEQUENCIA:
		pm.processar_vitoria("relaxing", env, 1.0, 0.0, "t")
	var persistido: Dictionary = pm.dados_para_salvar()

	var pm2 := _pm()
	pm2.carregar_de(persistido)
	assert_int(pm2.get_trofeus("relaxing")).is_equal(1)
	assert_bool(pm2.obstaculos_disponiveis("relaxing")).is_true()
