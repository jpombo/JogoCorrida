extends GdUnitTestSuite

## SPEC-010 / T006 (US1) — `tocar_colisao()`: gating por estado (só
## PLAYING), exatamente 1 reprodução por chamada (I3/SC-002), roubo LRU em
## pool exausta, efeito mudo ⇒ no-op (SC-008), guarda de árvore (I8) e
## devolução da voz pelo `finished` (data-model §4).


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


## SC-007/FR-006 — em MENU/READY/PAUSED/VICTORY/GAME_OVER nada reproduz;
## só PLAYING emite.
func test_01_somente_em_play() -> void:
	var am := _am(_cfg())
	for estado in [
		GameState.State.MENU, GameState.State.READY, GameState.State.PAUSED,
		GameState.State.VICTORY, GameState.State.GAME_OVER,
	]:
		am.ao_alterar_estado(estado, GameState.State.PLAYING)
		am.tocar_colisao()
		assert_int(am.vozes_colisao_ocupadas()).is_equal(0).override_failure_message(
			"Colisão reproduziu no estado %d" % estado
		)
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	am.tocar_colisao()
	assert_int(am.vozes_colisao_ocupadas()).is_equal(1).override_failure_message(
		"PLAYING não reproduziu a colisão"
	)
	assert_bool(am._vozes_colisao[0].playing).is_true().override_failure_message(
		"PLAYING não iniciou a reprodução física da colisão"
	)
	am.free()


## I3/SC-002 — cada chamada ocupa exatamente 1 voz (1 play por evento).
func test_02_uma_reproducao_por_chamada() -> void:
	var am := _am(_cfg({"vozes_colisao": 3}))
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	am.tocar_colisao()
	assert_int(am.vozes_colisao_ocupadas()).is_equal(1)
	am.tocar_colisao()
	assert_int(am.vozes_colisao_ocupadas()).is_equal(2)
	am.tocar_colisao()
	assert_int(am.vozes_colisao_ocupadas()).is_equal(3)
	# T022 — prova física de 1 play por evento: as 3 vozes em reprodução.
	assert_bool(am._vozes_colisao[0].playing).is_true()
	assert_bool(am._vozes_colisao[1].playing).is_true()
	assert_bool(am._vozes_colisao[2].playing).is_true()
	am.free()


## I3/SC-002 — pool exausta rouba a voz de `iniciada_em` menor (re-carimba)
## em vez de descartar o evento.
func test_03_pool_exausta_rouba_mais_antiga() -> void:
	var am := _am(_cfg({"vozes_colisao": 2}))
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	am.tocar_colisao()  # voz 0
	am._iniciada_em[0] = 1000
	am.tocar_colisao()  # voz 1
	am._iniciada_em[1] = 2000
	var agora := Time.get_ticks_msec()
	am.tocar_colisao()  # pool exausta → rouba a voz 0 (1000 < 2000)
	assert_int(am.vozes_colisao_ocupadas()).is_equal(2)
	assert_bool(am._iniciada_em.has(0)).is_true().override_failure_message(
		"Voz roubada perdeu o carimbo LRU"
	)
	assert_int(am._iniciada_em[0]).is_greater_equal(agora).override_failure_message(
		"Voz mais antiga não foi re-carimbada (roubo LRU)"
	)
	am.free()


## SC-008 — efeito mudo ⇒ no-op, sem erro.
func test_04_efeito_mudo_noop() -> void:
	var am := _am(_cfg({"colisao_path": ""}))
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	am.tocar_colisao()
	assert_int(am.vozes_colisao_ocupadas()).is_equal(0).override_failure_message(
		"Efeito mudo reproduziu"
	)
	am.free()


## I8/R2 — fora da árvore o play físico é suprimido sem erro; a execução
## segue e o estado lógico permanece coerente.
func test_05_fora_da_arvore_sem_erro() -> void:
	var am := AudioManager.new()
	am.configurar(_cfg())
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	am.tocar_colisao()
	assert_int(am.vozes_colisao_ocupadas()).is_equal(0).override_failure_message(
		"Voz ocupada fora da árvore (play físico deveria ser suprimido)"
	)
	assert_bool(am.esta_configurado()).is_true()
	am.free()


## Devolução da voz pelo `finished` — slot volta à lista livre.
func test_06_finished_devolve_voz() -> void:
	var am := _am(_cfg({"vozes_colisao": 2}))
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	am.tocar_colisao()  # voz 0 (pop_front)
	assert_int(am.vozes_colisao_ocupadas()).is_equal(1)
	am._vozes_colisao[0].finished.emit()  # fim natural do one-shot
	assert_int(am.vozes_colisao_ocupadas()).is_equal(0).override_failure_message(
		"finished não devolveu a voz à lista livre"
	)
	assert_int(am._livres_colisao.size()).is_equal(2)
	# Reuso imediato da voz devolvida.
	am.tocar_colisao()
	assert_int(am.vozes_colisao_ocupadas()).is_equal(1)
	am.free()
