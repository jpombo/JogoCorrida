extends GdUnitTestSuite

## SPEC-012 / T013 — Demonstração do menu (RED contra
## contracts/menu_demo_lifecycle.md §1–2): estados da API
## (iniciar/pausar/retomar/encerrar/esta_ativo/ambiente_atual), ciclo local
## PLAINS→DESERT→FOREST→ICE→PLAINS, duração de cada ambiente respeitando
## `demo_duracao_ambiente` (config temporário), `GameConfig.current_environment_id`
## INALTERADO após ciclos (isolamento de dados, FR-013) e `encerrar()` ⇒
## inativo + alpha do fade zerado. O tempo avança por chamadas diretas de
## `_process(delta)`; a conclusão do fade (Tween) é aguardada nos quadros do
## loop — fades encurtados por configuração temporária para a suíte.

var demo: MenuDemo

var _config_original: Dictionary = {}


## Configuração temporária (quickstart §5 / testes): valores originais
## guardados e restaurados em after_test.
func _config_temporario(chaves_valores: Dictionary) -> void:
	for chave in chaves_valores:
		if not _config_original.has(chave):
			_config_original[chave] = GameConfig.get(chave)
		GameConfig.set(chave, chaves_valores[chave])


func before_test() -> void:
	_config_temporario({
		"demo_duracao_ambiente": 0.5,
		"demo_fade_escurecer": 0.01,
		"demo_fade_clarear": 0.01,
	})
	demo = MenuDemo.new()
	add_child(demo)
	demo.iniciar()
	# O tempo é dirigido à mão (contracts §1: `_process = true` em iniciar) —
	# sem processamento automático disputando os deltas com os testes.
	demo.set_process(false)


func after_test() -> void:
	demo.queue_free()
	demo = null
	for chave in _config_original:
		GameConfig.set(chave, _config_original[chave])
	_config_original.clear()


## Espera o Tween de fade concluir a troca nos quadros do loop (3000 quadros
## ≈ teto generoso; fades de 0,01 s resolvem em 1–2 quadros) e também o
## fim do próprio fade — assim o gatilho do próximo ciclo nasce com o tween
## anterior já encerrado (um swap por fade, contract §2).
func _aguardar_troca(ambiente_de: String) -> String:
	for i in 3000:
		if demo.ambiente_atual() != ambiente_de:
			for j in 3000:
				if demo._tween == null or not demo._tween.is_valid():
					break
				await get_tree().process_frame
			return demo.ambiente_atual()
		await get_tree().process_frame
	return demo.ambiente_atual()


## 1 — Ciclo de ambientes sempre partindo de PLAINS e envolvendo a
## sequência completa até voltar a PLAINS (RF-005, contract §2).
func test_01_ciclo_de_ambientes() -> void:
	var sequencia: Array = GameConfig.environment_sequence.duplicate()
	assert_str(demo.ambiente_atual()).is_equal(sequencia[0]).override_failure_message(
		"iniciar() não partiu do primeiro ambiente da sequência"
	)

	var esperado: String = sequencia[0]
	for i in sequencia.size():
		var proximo: String = sequencia[(i + 1) % sequencia.size()]
		demo._process(float(GameConfig.demo_duracao_ambiente) + 0.01)
		var obtido: String = await _aguardar_troca(esperado)
		assert_str(obtido).is_equal(proximo).override_failure_message(
			"RF-005: o ciclo %d não foi %s → %s (ficou em %s)"
				% [i + 1, esperado, proximo, obtido]
		)
		esperado = obtido


## 2 — Duração de cada ambiente: deltas abaixo de `demo_duracao_ambiente`
## não trocam; a soma cruzando o limite inicia a transição (RF-006).
func test_02_duracao_do_ambiente() -> void:
	var dur := float(GameConfig.demo_duracao_ambiente)
	var segundo: String = GameConfig.environment_sequence[1]

	demo._process(dur * 0.6)
	demo._process(dur * 0.3)
	assert_str(demo.ambiente_atual()).is_equal(
		String(GameConfig.environment_sequence[0])
	).override_failure_message(
		"RF-006: 90%% da duração já trocou o ambiente (trocou cedo demais)"
	)

	demo._process(dur * 0.2)
	var obtido := await _aguardar_troca(String(GameConfig.environment_sequence[0]))
	assert_str(obtido).is_equal(segundo).override_failure_message(
		"RF-006: cruzar demo_duracao_ambiente não iniciou a transição"
	)


## 3 — Isolamento de dados (FR-013/FR-018): ciclos completos da demo com o
## jogo em MENU nunca escrevem `GameConfig.current_environment_id` — o
## ambiente canônico continua sendo só do gameplay (SC-009 automatizada).
func test_03_current_environment_id_inalterado() -> void:
	var ambiente_do_jogo: String = GameConfig.current_environment_id

	# Dois ciclos completos (≥ 2 voltas) com a demo ativa.
	for i in GameConfig.environment_sequence.size() * 2:
		demo._process(float(GameConfig.demo_duracao_ambiente) + 0.01)
		var antes: String = demo.ambiente_atual()
		var depois: String = await _aguardar_troca(antes)
		assert_str(depois).is_not_equal(antes).override_failure_message(
			"a demo travou em '%s' no ciclo %d" % [antes, i]
		)

	assert_str(GameConfig.current_environment_id).is_equal(ambiente_do_jogo)\
		.override_failure_message(
			"FR-013: a demonstração escreveu em GameConfig.current_environment_id"
		)


## 4 — `encerrar()` ⇒ API do contract §1: inativo, alpha do fade 0 e NPCs
## reciclados (SC-005); idempotente (chamar 2× não falha).
func test_04_encerrar_fica_inativo_com_fade_zero() -> void:
	assert_bool(demo.esta_ativo()).is_true().override_failure_message(
		"iniciar() não deixou a demo ativa"
	)

	demo.encerrar()
	assert_bool(demo.esta_ativo()).is_false().override_failure_message(
		"encerrar() manteve a demo ativa"
	)
	assert_float(demo._fade_rect.color.a).is_equal_approx(0.0, 0.001)\
		.override_failure_message(
			"SC-005: encerrar() deixou alpha do fade ≠ 0"
		)
	assert_int(demo.npc_ativos()).is_zero().override_failure_message(
		"encerrar() não reciclou os NPCs"
	)

	# Idempotência (contract §1): segunda chamada é no-op sem erro.
	demo.encerrar()
	assert_bool(demo.esta_ativo()).is_false()


## 5 — T015 / SC-005: `encerrar()` no MEIO da transição de fade mata o
## tween e força alpha 0; a troca de ambiente (que só acontece em alpha 1,
## contract §2) não ocorre.
func test_05_encerrar_durante_transicao_zera_alpha() -> void:
	var antes: String = demo.ambiente_atual()
	demo._process(float(GameConfig.demo_duracao_ambiente) + 0.01)
	assert_bool(demo._tween != null and demo._tween.is_valid()).is_true()\
		.override_failure_message("preparação: a transição de fade não começou")

	# Avança o tween pela metade do escurecer (sem esperar frames) — a
	# troca (callback no alpha 1) ainda não aconteceu.
	demo._tween.custom_step(float(GameConfig.demo_fade_escurecer) * 0.5)
	assert_float(demo._fade_rect.color.a).is_greater(0.0).override_failure_message(
		"preparação: o fade não está em curso"
	)

	demo.encerrar()
	assert_float(demo._fade_rect.color.a).is_equal_approx(0.0, 0.001)\
		.override_failure_message("SC-005: encerrar() em transição deixou alpha ≠ 0")
	assert_bool(demo.esta_ativo()).is_false()
	assert_bool(demo._tween == null or not demo._tween.is_valid()).is_true()\
		.override_failure_message("SC-005: encerrar() não matou o tween")
	assert_str(demo.ambiente_atual()).is_equal(antes).override_failure_message(
		"contract §2: o ambiente trocou sem chegar a alpha 1"
	)


## 6 — T015: `pausar()` em transição faz o mesmo (alpha 0, tween morto, sem
## troca) e `retomar()` continua pelo mesmo ambiente — o ciclo não reinicia
## (RF-009).
func test_06_pausar_durante_transicao_zera_alpha_e_retoma() -> void:
	var antes: String = demo.ambiente_atual()
	demo._process(float(GameConfig.demo_duracao_ambiente) + 0.01)
	demo._tween.custom_step(float(GameConfig.demo_fade_escurecer) * 0.5)

	demo.pausar()
	assert_float(demo._fade_rect.color.a).is_equal_approx(0.0, 0.001)\
		.override_failure_message("SC-005: pausar() em transição deixou alpha ≠ 0")
	assert_bool(demo.esta_ativo()).is_false()
	assert_str(demo.ambiente_atual()).is_equal(antes)

	demo.retomar()
	assert_bool(demo.esta_ativo()).is_true().override_failure_message(
		"retomar() não voltou a EXECUTANDO"
	)
	assert_str(demo.ambiente_atual()).is_equal(antes).override_failure_message(
		"RF-009: retomar() mudou o ambiente (reiniciou o ciclo)"
	)


## 7 — T019 / T020 (contract §2): a pool de NPCs é fixa e limitada a
## `demo_npc_max` mesmo após muitos updates (nasce reposição contínua).
func test_07_pool_de_npcs_limitada() -> void:
	_config_temporario({"demo_npc_intervalo": 0.0})
	for i in 30:
		demo._process(0.1)
		assert_int(demo.npc_ativos()).is_less_equal(
			int(GameConfig.demo_npc_max)
		).override_failure_message(
			"FR-017/contract §2: npc_ativos() passou de demo_npc_max"
		)
	assert_int(demo._pool.size()).is_equal(int(GameConfig.demo_npc_max))\
		.override_failure_message("contract §2: a pool não foi fixada em demo_npc_max")


## 8 — T019 / T020: NPC que cruza a borda inferior é reciclado
## (`npc_ativos()` diminui); sem reposição disponível (intervalo alto) a
## contagem zera.
func test_08_npc_que_cruza_borda_e_reciclado() -> void:
	_config_temporario({"demo_npc_intervalo": 0.0})
	demo._process(0.1)
	assert_int(demo.npc_ativos()).is_greater(0).override_failure_message(
		"preparação: nenhum NPC nasceu com intervalo 0"
	)

	_config_temporario({"demo_npc_intervalo": 999.0})
	demo._process(10.0)
	assert_int(demo.npc_ativos()).is_zero().override_failure_message(
		"FR-017/contract §2: NPCs cruzaram a borda e não foram reciclados"
	)


## 9 — T019: iniciar() → encerrar() → iniciar() nunca acumula NPCs nem
## duplica a pool (SC-007).
func test_09_reinicio_nunca_acumula() -> void:
	_config_temporario({"demo_npc_intervalo": 0.0})
	demo._process(0.1)
	assert_int(demo.npc_ativos()).is_greater(0)

	demo.encerrar()
	assert_int(demo.npc_ativos()).is_zero().override_failure_message(
		"encerrar() não reciclou os NPCs ativos"
	)

	demo.iniciar()
	demo.set_process(false)
	assert_int(demo.npc_ativos()).is_zero().override_failure_message(
		"iniciar() reabriu com NPCs ativos de antes"
	)
	assert_int(demo._pool.size()).is_equal(int(GameConfig.demo_npc_max))\
		.override_failure_message("iniciar() duplicou a pool de NPCs")

	demo._process(0.1)
	assert_int(demo.npc_ativos()).is_greater(0).override_failure_message(
		"após o reinício a demo parou de nascer NPCs"
	)


## 10 — T019 / RF-009: pausar congela a posição dos NPCs; retomar retoma o
## movimento com exatamente `demo_velocidade` — sem drift residual.
func test_10_pausa_congela_e_retoma_npcs() -> void:
	_config_temporario({"demo_npc_intervalo": 0.0})
	demo._process(0.1)
	var alvo := _primeiro_ativo()
	assert_bool(alvo != null).is_true().override_failure_message(
		"preparação: nenhum NPC ativo para observar"
	)
	var pos0: Vector2 = alvo.position

	demo.pausar()
	demo._process(1.0)
	assert_that(alvo.position).is_equal(pos0).override_failure_message(
		"RF-009: pausar() não congelou a posição dos NPCs"
	)

	demo.retomar()
	demo._process(0.25)
	var esperado: float = pos0.y + float(GameConfig.demo_velocidade) * 0.25
	assert_float(alvo.position.y).is_equal_approx(esperado, 0.01)\
		.override_failure_message(
			"RF-009: retomar() não retomou o movimento na velocidade esperada"
		)
	assert_float(alvo.position.x).is_equal_approx(pos0.x, 0.001)\
		.override_failure_message("o movimento da demo deslocou o eixo X")


## 11 — T019 / FR-017: a velocidade dos NPCs da demo é IDÊNTICA com o
## DifficultyManager em modos diferentes — a demo nunca lê dificuldade.
func test_11_velocidade_npc_ignora_dificuldade() -> void:
	_config_temporario({"demo_npc_intervalo": 0.0})
	var dificuldade := DifficultyManager.new()

	dificuldade.definir_modo("relaxing")
	var desloc_relaxing := _medir_deslocamento_npcs()

	demo.encerrar()
	demo.iniciar()
	demo.set_process(false)
	dificuldade.definir_modo("challenge")
	var desloc_challenge := _medir_deslocamento_npcs()

	assert_float(desloc_challenge).is_equal_approx(desloc_relaxing, 0.01)\
		.override_failure_message(
			"FR-017: a demo variou a velocidade dos NPCs com o modo de "
				+ "dificuldade (%.2f vs %.2f)" % [desloc_relaxing, desloc_challenge]
		)


## 12 — T019 / SC-009 automatizada: ≥2 ciclos completos de ambiente com a
## demo ativa deixam um ProgressManager sintético e um FuelSystem sintético
## IDÊNTICOS — guarda de regressão contra wiring futuro indevido (FR-013/
## FR-018).
func test_12_isolamento_de_dados_progresso_e_combustivel() -> void:
	var progresso := ProgressManager.new()
	progresso.carregar_de({})
	var progresso_antes: Dictionary = progresso.dados_para_salvar()

	var combustivel := FuelSystem.new()
	combustivel.reset()
	var carga_antes: float = combustivel.get_atual()
	var capacidade_antes: float = combustivel.get_capacidade()
	assert_bool(carga_antes > 0.0).is_true().override_failure_message(
		"preparação: FuelSystem sintético sem carga inicial"
	)

	# ≥2 ciclos completos (2 voltas na sequência) com a demo ativa.
	for i in GameConfig.environment_sequence.size() * 2:
		demo._process(float(GameConfig.demo_duracao_ambiente) + 0.01)
		var antes: String = demo.ambiente_atual()
		var depois: String = await _aguardar_troca(antes)
		assert_str(depois).is_not_equal(antes).override_failure_message(
			"a demo travou no ciclo %d" % i
		)

	assert_dict(progresso.dados_para_salvar()).is_equal(progresso_antes)\
		.override_failure_message(
			"FR-018: a demonstração alterou dados do ProgressManager"
		)
	assert_float(combustivel.get_atual()).is_equal_approx(carga_antes, 0.001)\
		.override_failure_message(
			"FR-018: a demonstração alterou a carga de combustível"
		)
	assert_float(combustivel.get_capacidade()).is_equal_approx(capacidade_antes, 0.001)\
		.override_failure_message(
			"FR-018: a demonstração alterou a capacidade de combustível"
		)


## 14 — Regressão (RF-009: a demo "encerra imediatamente ao iniciar corrida,
## sem interferir na inicialização da corrida"): a demo é o ÚLTIMO filho de
## mundo e desenha ACIMA de `PlayerVehicle`/`TrafficLayer` — visível fora do
## menu ela cobre o carro do jogador e os NPCs de corrida (o cenário parece
## continuar em demonstração). `iniciar()` mostra, `encerrar()` esconde;
## `pausar()` mantém visível (cenário congelado atrás de Configurações) e
## `retomar()` continua visível.
func test_14_visivel_somente_no_menu() -> void:
	demo.iniciar()
	assert_bool(demo.visible).is_true().override_failure_message(
		"iniciar() não mostrou a demo"
	)

	demo.encerrar()
	assert_bool(demo.visible).is_false().override_failure_message(
		"RF-009: encerrar() não escondeu a demo — ela cobre o jogador e o "
			+ "trânsito da corrida"
	)

	demo.iniciar()
	demo.set_process(false)
	demo.pausar()
	assert_bool(demo.visible).is_true().override_failure_message(
		"pausar() escondeu a demo (Configurações deve abrir sobre o cenário congelado)"
	)

	demo.retomar()
	assert_bool(demo.visible).is_true().override_failure_message(
		"retomar() não manteve a demo visível"
	)

	demo.encerrar()
	assert_bool(demo.visible).is_false().override_failure_message(
		"segundo encerrar() deixou a demo visível"
	)


## Primeiro NPC ativo da pool (para observação direta nos testes).
func _primeiro_ativo() -> TrafficVehicle:
	for veiculo in demo._pool:
		if veiculo != null and veiculo.is_active():
			return veiculo
	return null


## Garante 1 NPC ativo e mede o deslocamento vertical em 0,25 s.
func _medir_deslocamento_npcs() -> float:
	if demo.npc_ativos() == 0:
		demo._process(0.01)
	var alvo := _primeiro_ativo()
	if alvo == null:
		return -1.0
	var y0: float = alvo.position.y
	demo._process(0.25)
	return alvo.position.y - y0


## 13 — Regressão do aceite manual T024 (2026-10-18): a ordem de criação dos
## filhos da demo espelha o gameplay.tscn (Background → Decoration → Road →
## NPCs → fade). Road DEPOIS do fundo, senão o fundo cobre o asfalto e o
## asset `estrada_2_vias.png` some da tela.
func test_13_ordem_de_desenho_espelha_a_corrida() -> void:
	demo.iniciar()
	assert_int(demo._fundo.get_index()).is_less(demo._estrada.get_index())\
		.override_failure_message(
			"T024: fundo criado DEPOIS da Road — cobre o asfalto da demo"
		)
	assert_int(demo._decoracao.get_index()).is_less(demo._estrada.get_index())\
		.override_failure_message(
			"T024: decoração deve ficar sob a Road (ordem do gameplay.tscn)"
		)
	assert_int(demo._pool[0].get_index()).is_greater(demo._estrada.get_index())\
		.override_failure_message("NPCs devem desenhar ACIMA da Road")
	assert_int(demo._fade_rect.get_index()).is_greater(demo._pool[0].get_index())\
		.override_failure_message("o fade deve permanecer o último filho")
