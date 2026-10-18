extends GdUnitTestSuite

## SPEC-010 / T012 (US3) — matriz de reprodução por estado (data-model §5):
## PLAYING liga NPCs (jogador só pelo gate — I9), PAUSED suspende com
## `stream_paused` e a retomada restaura sem reiniciar (SC-006),
## VICTORY/GAME_OVER/MENU/READY/estado desconhecido param tudo (SC-007),
## colisão em voo acompanha a virada, a última virada do quadro vence e o
## orquestrador deriva a pool de motor de `traffic_max_vehicles + 1` (R5).


func _cfg(overrides: Dictionary = {}) -> Dictionary:
	var cfg := {
		"colisao_path": "res://assets/audio/colisao.mp3",
		"caminhao_path": "res://assets/audio/caminhao.mp3",
		"carro_path": "res://assets/audio/carro.mp3",
		"vozes_colisao": 3,
		"vozes_motor": 13,
		"volume_motor": 0.8,
		"volume_colisao": 1.0,
		"categoria_caminhao": "caminhao",
	}
	cfg.merge(overrides, true)
	return cfg


func _am(cfg: Dictionary) -> AudioManager:
	var am := AudioManager.new()
	am.configurar(cfg)
	add_child(am)
	return am


func _npc(categoria_id: String) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


## SC-006/SC-007 — matriz completa: PLAYING liga NPCs e não o jogador;
## PAUSED suspende e a retomada restaura sem reiniciar; VICTORY/GAME_OVER/
## MENU/READY param tudo com `stream_paused` resetado; desconhecido ⇒
## falha segura.
func test_01_matriz_completa_de_estados() -> void:
	var am := _am(_cfg())
	var npc := _npc("passeio")
	am.ao_veiculo_surgir(npc)
	var indice: int = am._dicionario[npc]

	# PLAYING: NPC ligado; jogador só pelo gate (I9).
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.READY)
	assert_bool(am._vozes_motor[indice].playing).is_true().override_failure_message(
		"PLAYING não ligou o NPC registrado"
	)
	assert_bool(am.voz_jogador_tocando()).is_false().override_failure_message(
		"PLAYING ligou o jogador sem o gate (I9)"
	)

	# PAUSED: stream_paused em todas as vozes, posição mantida.
	am.ao_alterar_estado(GameState.State.PAUSED, GameState.State.PLAYING)
	assert_bool(am._vozes_motor[indice].stream_paused).is_true().override_failure_message(
		"PAUSED não suspendeu o motor"
	)

	# Retomada: stream_paused=false sem reiniciar o loop (SC-006).
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.PAUSED)
	assert_bool(am._vozes_motor[indice].stream_paused).is_false()
	assert_bool(am._vozes_motor[indice].playing).is_true().override_failure_message(
		"Retomada reiniciou o motor em vez de restaurar"
	)

	# VICTORY: stop + stream_paused resetado (próxima corrida limpa).
	am.ao_alterar_estado(GameState.State.VICTORY, GameState.State.PLAYING)
	assert_bool(am._vozes_motor[indice].playing).is_false().override_failure_message(
		"VICTORY não parou o motor"
	)
	assert_bool(am._vozes_motor[indice].stream_paused).is_false()

	# PLAYING → GAME_OVER: stop.
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.VICTORY)
	assert_bool(am._vozes_motor[indice].playing).is_true()
	am.ao_alterar_estado(GameState.State.GAME_OVER, GameState.State.PLAYING)
	assert_bool(am._vozes_motor[indice].playing).is_false().override_failure_message(
		"GAME_OVER não parou o motor"
	)

	# PLAYING → READY: stop ("não na preparação da largada").
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.GAME_OVER)
	assert_bool(am._vozes_motor[indice].playing).is_true()
	am.ao_alterar_estado(GameState.State.READY, GameState.State.PLAYING)
	assert_bool(am._vozes_motor[indice].playing).is_false().override_failure_message(
		"READY não parou o motor (preparação deve ser muda)"
	)

	# Estado desconhecido ⇒ falha segura (para tudo).
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.READY)
	assert_bool(am._vozes_motor[indice].playing).is_true()
	am.ao_alterar_estado(-1, GameState.State.PLAYING)
	assert_bool(am._vozes_motor[indice].playing).is_false().override_failure_message(
		"Estado desconhecido não parou tudo (falha segura)"
	)
	npc.free()
	am.free()


## SC-006 — colisão em voo pausa junto na PAUSED, retoma na PLAYING e morre
## nas saídas de PLAYING.
func test_02_colisao_em_voo_pausa_e_morre() -> void:
	var am := _am(_cfg())
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	am.tocar_colisao()
	assert_int(am.vozes_colisao_ocupadas()).is_equal(1)

	am.ao_alterar_estado(GameState.State.PAUSED, GameState.State.PLAYING)
	assert_bool(am._vozes_colisao[0].stream_paused).is_true().override_failure_message(
		"Colisão em voo não pausou junto"
	)

	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.PAUSED)
	assert_bool(am._vozes_colisao[0].stream_paused).is_false()
	assert_int(am.vozes_colisao_ocupadas()).is_equal(1).override_failure_message(
		"Retomada reiniciou a colisão em voo"
	)

	am.ao_alterar_estado(GameState.State.GAME_OVER, GameState.State.PLAYING)
	assert_bool(am._vozes_colisao[0].playing).is_false().override_failure_message(
		"Colisão em voo sobreviveu à saída de PLAYING"
	)
	assert_int(am.vozes_colisao_ocupadas()).is_equal(0)
	am.free()


## R4 — duas viradas no mesmo quadro: a última vence (encaminhamento
## síncrono por transição).
func test_03_ultima_virada_vence() -> void:
	var am := _am(_cfg())
	var npc := _npc("passeio")
	am.ao_veiculo_surgir(npc)
	var indice: int = am._dicionario[npc]

	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	am.ao_alterar_estado(GameState.State.PAUSED, GameState.State.PLAYING)
	# Godot 4: stream_paused=true ⇒ playing==false (suspenso, não parado).
	assert_bool(am._vozes_motor[indice].playing).is_false().override_failure_message(
		"PLAYING→PAUSED não suspendeu o motor (playing ainda true)"
	)
	assert_bool(am._vozes_motor[indice].stream_paused).is_true().override_failure_message(
		"PLAYING→PAUSED não marcou stream_paused"
	)

	# Retomada: stream_paused=false restaura playing=true SEM play() novo
	# (prova física de "restaurar sem reiniciar" — SC-006).
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.PAUSED)
	assert_bool(am._vozes_motor[indice].stream_paused).is_false()
	assert_bool(am._vozes_motor[indice].playing).is_true().override_failure_message(
		"Retomada não restaurou o motor sem play() novo"
	)

	# Última virada do quadro (MENU) vence — tudo parado.
	am.ao_alterar_estado(GameState.State.MENU, GameState.State.PLAYING)
	assert_bool(am._vozes_motor[indice].playing).is_false().override_failure_message(
		"Última virada (MENU) não venceu"
	)
	npc.free()
	am.free()


## T020/US3-AC1 (Phase 7) — gate do jogador na matriz: a voz 0 recebe
## `stream_paused` junto com as demais na PAUSED e a retomada segue o
## último flag — retomar acelerando ⇒ volta sem reiniciar, solto ⇒ segue
## muda.
func test_05_gate_jogador_pausa_e_retomada() -> void:
	var am := _am(_cfg())
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.READY)

	# Gate liga a voz 0 em PLAYING.
	am.ao_aceleracao_jogador(true)
	assert_bool(am.voz_jogador_tocando()).is_true().override_failure_message(
		"Gate não ligou o jogador em PLAYING"
	)
	assert_bool(am._vozes_motor[0].playing).is_true().override_failure_message(
		"Voz física do jogador não iniciou no gate"
	)

	# PAUSED: a voz 0 do jogador também é suspendida.
	am.ao_alterar_estado(GameState.State.PAUSED, GameState.State.PLAYING)
	assert_bool(am._vozes_motor[0].stream_paused).is_true().override_failure_message(
		"PAUSED não suspendeu a voz do jogador"
	)
	# Godot 4: stream_paused=true ⇒ playing==false (suspenso, não parado).
	assert_bool(am._vozes_motor[0].playing).is_false()

	# Retomada com flag preservado (true) ⇒ a voz 0 volta sem play() novo.
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.PAUSED)
	assert_bool(am._vozes_motor[0].stream_paused).is_false()
	assert_bool(am._vozes_motor[0].playing).is_true().override_failure_message(
		"Retomada não restaurou a voz do jogador com flag preservado"
	)
	assert_bool(am.voz_jogador_tocando()).is_true()

	# Flag false na corrida ⇒ a voz 0 para.
	am.ao_aceleracao_jogador(false)
	assert_bool(am._vozes_motor[0].playing).is_false().override_failure_message(
		"Forward false não parou a voz do jogador"
	)
	assert_bool(am.voz_jogador_tocando()).is_false()

	# Retomada com flag false ⇒ segue muda (o gate segue o último flag).
	am.ao_alterar_estado(GameState.State.PAUSED, GameState.State.PLAYING)
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.PAUSED)
	assert_bool(am._vozes_motor[0].playing).is_false().override_failure_message(
		"Retomada ligou o jogador com flag false"
	)
	assert_bool(am.voz_jogador_tocando()).is_false()
	am.free()


## T020/US3-AC1 (Phase 7) — forward obsoleto chega enquanto a corrida está
## pausada (flag solto durante a PAUSED): a correção acontece no ato da
## retomada, sem deixar a voz 0 tocando com flag obsoleto.
func test_06_gate_jogador_forward_obsoleto_na_pausa() -> void:
	var am := _am(_cfg())
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.READY)
	am.ao_aceleracao_jogador(true)
	am.ao_alterar_estado(GameState.State.PAUSED, GameState.State.PLAYING)
	assert_bool(am._vozes_motor[0].stream_paused).is_true()

	# Input solto durante a pausa: só o flag muda (gate físico re-avaliado
	# na retomada — em PAUSED a chamada não age sobre a voz).
	am.ao_aceleracao_jogador(false)
	assert_bool(am.voz_jogador_tocando()).is_false()

	# Retomada: flag false ⇒ a voz 0 não volta a tocar.
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.PAUSED)
	assert_bool(am._vozes_motor[0].stream_paused).is_false()
	assert_bool(am._vozes_motor[0].playing).is_false().override_failure_message(
		"Retomada manteve a voz do jogador com flag obsoleto"
	)
	assert_bool(am.voz_jogador_tocando()).is_false()
	am.free()


## R5/integração — GameplayManager em árvore cria e configura o AudioManager
## com a pool derivada de `traffic_max_vehicles + 1` (mesmo padrão de
## add_child de tests/unit/difficulty_speed_test.gd).
func test_04_integracao_gameplay_manager() -> void:
	var gm := GameplayManager.new()
	add_child(gm)
	assert_bool(gm.audio_manager != null).is_true().override_failure_message(
		"GameplayManager não criou o AudioManager em _ready"
	)
	assert_bool(gm.audio_manager.esta_configurado()).is_true()
	assert_int(gm.audio_manager.vozes_motor_totais()).is_equal(
		GameConfig.traffic_max_vehicles + 1
	).override_failure_message(
		"Pool de motor não derivada de traffic_max_vehicles + 1 (R5)"
	)
	gm.free()
	GameState.reset()
