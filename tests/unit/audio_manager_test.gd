extends GdUnitTestSuite

## SPEC-010 / T005 (Foundational) — `configurar()`: idempotente, 3 streams
## com loop correto (R1), volumes convertidos (R8), pools com os tamanhos
## recebidos no `cfg` e voz 0 reservada ao jogador (R5), arquivo ausente ⇒
## apenas aquele efeito mudo (SC-008/I7) e getters de estado lógico
## coerentes sem árvore (I8/I9).


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


## 2ª chamada de `configurar` é no-op: pools e streams preservados.
func test_01_configurar_idempotente() -> void:
	var am := AudioManager.new()
	am.configurar(_cfg())
	assert_bool(am.esta_configurado()).is_true()
	var totais := am.vozes_motor_totais()
	am.configurar(_cfg({"vozes_motor": 3, "colisao_path": ""}))
	assert_int(am.vozes_motor_totais()).is_equal(totais).override_failure_message(
		"Segunda chamada de configurar recriou as pools"
	)
	assert_bool(am.efeito_mudo("colisao")).is_false().override_failure_message(
		"Segunda chamada re-carregou os streams"
	)
	am.free()


## 3 streams carregados: motor (caminhão e carro) com loop, colisão sem.
func test_02_streams_carregados_com_loop() -> void:
	var am := AudioManager.new()
	am.configurar(_cfg())
	add_child(am)
	assert_bool(am._stream_colisao == null).is_false().override_failure_message(
		"AUD-001 não carregou (stream mudo)"
	)
	assert_bool(am._stream_caminhao == null).is_false().override_failure_message(
		"AUD-002 não carregou (stream mudo)"
	)
	assert_bool(am._stream_carro == null).is_false().override_failure_message(
		"AUD-003 não carregou (stream mudo)"
	)
	assert_bool((am._stream_colisao as AudioStreamMP3).loop).is_false().override_failure_message(
		"AUD-001 one-shot com loop ativado"
	)
	assert_bool((am._stream_caminhao as AudioStreamMP3).loop).is_true().override_failure_message(
		"AUD-002 sem loop (motor deve ser contínuo)"
	)
	assert_bool((am._stream_carro as AudioStreamMP3).loop).is_true().override_failure_message(
		"AUD-003 sem loop (motor deve ser contínuo)"
	)
	am.free()


## Volumes lineares convertidos uma única vez para dB (R8), com clamp.
func test_03_volumes_convertidos_com_clamp() -> void:
	var am := AudioManager.new()
	am.configurar(_cfg({"volume_motor": 0.5, "volume_colisao": 1.0}))
	assert_float(am._vozes_motor[0].volume_db).is_equal_approx(
		linear_to_db(0.5), 0.001
	).override_failure_message("volume_motor 0,5 não convertido para dB")
	assert_float(am._vozes_colisao[0].volume_db).is_equal_approx(
		linear_to_db(1.0), 0.001
	).override_failure_message("volume_colisao 1,0 não convertido para dB")
	am.free()

	var am2 := AudioManager.new()
	am2.configurar(_cfg({"volume_motor": 1.5, "volume_colisao": -2.0}))
	assert_float(am2._vozes_motor[0].volume_db).is_equal_approx(
		linear_to_db(1.0), 0.001
	).override_failure_message("volume acima de 1,0 não clampado")
	assert_float(am2._vozes_colisao[0].volume_db).is_equal(-80.0).override_failure_message(
		"volume negativo não virou mudo (-80 dB)"
	)
	am2.free()


## Pools com os tamanhos recebidos no cfg; voz 0 dedicada ao jogador e
## nunca na lista livre (R5/data-model §3).
func test_04_pools_do_cfg_e_voz_0_reservada() -> void:
	var am := AudioManager.new()
	am.configurar(_cfg({"vozes_motor": 4, "vozes_colisao": 2}))
	assert_int(am.vozes_motor_totais()).is_equal(4).override_failure_message(
		"Pool de motor não respeitou vozes_motor do cfg"
	)
	assert_int(am.vozes_colisao_ocupadas()).is_equal(0)
	assert_int(am._vozes_colisao.size()).is_equal(2)
	assert_int(am.vozes_motor_ocupadas()).is_equal(1).override_failure_message(
		"Voz 0 do jogador não conta como ocupada"
	)
	assert_int(am._livres_motor.size()).is_equal(3)
	assert_bool(0 in am._livres_motor).is_false().override_failure_message(
		"Voz 0 do jogador exposta na lista livre"
	)
	am.free()


## Arquivo ausente ⇒ apenas aquele efeito mudo, sem erro e sem derrubar os
## demais (SC-008/I7).
func test_05_arquivo_ausente_somente_aquele_efeito_mudo() -> void:
	var am := AudioManager.new()
	am.configurar(_cfg({"caminhao_path": "res://assets/audio/NAO_EXISTE.mp3"}))
	assert_bool(am.efeito_mudo("caminhao")).is_true().override_failure_message(
		"Caminhão com arquivo ausente não nasceu mudo"
	)
	assert_bool(am.efeito_mudo("colisao")).is_false()
	assert_bool(am.efeito_mudo("carro")).is_false()
	# Pool criada mesmo com um efeito mudo — jogo segue sem falha.
	assert_int(am.vozes_motor_totais()).is_equal(13)
	# Chave desconhecida também é falha segura (mudo).
	assert_bool(am.efeito_mudo("inexistente")).is_true()
	am.free()


## Estado lógico coerente sem árvore (I8): gates e getters refletem as
## viradas e o gate do jogador (I9 — só toca após acelerar em PLAYING).
func test_06_estado_logico_e_getters() -> void:
	var am := AudioManager.new()
	am.configurar(_cfg())
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	assert_bool(am.voz_jogador_tocando()).is_false().override_failure_message(
		"Entrada em PLAYING ligou o jogador sem o gate (I9)"
	)
	am.ao_aceleracao_jogador(true)
	assert_bool(am.voz_jogador_tocando()).is_true().override_failure_message(
		"Gate ativo não refletido no getter lógico (I8)"
	)
	am.ao_aceleracao_jogador(false)
	assert_bool(am.voz_jogador_tocando()).is_false()
	am.ao_alterar_estado(GameState.State.MENU, GameState.State.PLAYING)
	assert_bool(am.voz_jogador_tocando()).is_false()
	am.free()
