extends GdUnitTestSuite

## SPEC-010 / T013 (US3) — nos 3 modos da SPEC-009 a atividade completa de
## áudio (configurar, spawns dos 3 tipos, colisão, gate e viradas de
## estado) não altera `DifficultyManager.fator_velocidade_total()`, nem as
## bases de `GameConfig` (FR-005/SC-005/I6, research R10); os efeitos
## AUD-002/003 seguem ativos em cada modo.


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


func _npc(categoria_id: String) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


func test_01_audio_nao_muta_fatores_dos_modos() -> void:
	for modo in GameConfig.difficulty_modes.keys():
		var dm := DifficultyManager.new()
		dm.definir_modo(modo)
		var fator_antes: float = dm.fator_velocidade_total()
		var max_antes: float = GameConfig.max_speed
		var bases_antes := {}
		for id in GameConfig.TRAFFIC_CATEGORIES:
			bases_antes[id] = float(GameConfig.TRAFFIC_CATEGORIES[id]["max_speed_kmh"])

		var am := AudioManager.new()
		am.configurar(_cfg())
		add_child(am)
		am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
		var caminhao := _npc("caminhao")
		var passeio := _npc("passeio")
		var esporte := _npc("esporte")
		var max_speeds_antes: Array[float] = [
			caminhao.category.max_speed,
			passeio.category.max_speed,
			esporte.category.max_speed,
		]
		am.ao_veiculo_surgir(caminhao)
		am.ao_veiculo_surgir(passeio)
		am.ao_veiculo_surgir(esporte)
		am.tocar_colisao()
		am.ao_aceleracao_jogador(true)

		# Efeitos ativos no modo (AUD-002 no caminhão, AUD-003 nos demais).
		assert_bool(am.motor_tocando(caminhao)).is_true().override_failure_message(
			"Caminhão mudo no modo %s" % modo
		)
		assert_bool(am.motor_tocando(passeio)).is_true().override_failure_message(
			"Passeio mudo no modo %s" % modo
		)
		assert_bool(am.motor_tocando(esporte)).is_true().override_failure_message(
			"Esporte mudo no modo %s" % modo
		)
		assert_int(am.vozes_colisao_ocupadas()).is_equal(1).override_failure_message(
			"Colisão muda no modo %s" % modo
		)

		# Viradas de estado completas sem tocar balanceamento.
		am.ao_alterar_estado(GameState.State.PAUSED, GameState.State.PLAYING)
		am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.PAUSED)
		am.ao_alterar_estado(GameState.State.MENU, GameState.State.PLAYING)

		# Bases intocadas (FR-005/I6).
		assert_float(dm.fator_velocidade_total()).is_equal(fator_antes).override_failure_message(
			"Áudio alterou o fator do modo %s" % modo
		)
		assert_float(GameConfig.max_speed).is_equal(max_antes).override_failure_message(
			"Áudio alterou GameConfig.max_speed no modo %s" % modo
		)
		# T021 — as 4 categorias da tabela (inclui esporte e utilitario).
		for id in bases_antes:
			assert_float(
				float(GameConfig.TRAFFIC_CATEGORIES[id]["max_speed_kmh"])
			).is_equal(bases_antes[id]).override_failure_message(
				"Áudio alterou a base de %s no modo %s" % [id, modo]
			)
		# T021 — TrafficData.max_speed das 3 instâncias spawnadas.
		var max_speeds_depois: Array[float] = [
			caminhao.category.max_speed,
			passeio.category.max_speed,
			esporte.category.max_speed,
		]
		for i in max_speeds_antes.size():
			assert_float(max_speeds_depois[i]).is_equal(max_speeds_antes[i]).override_failure_message(
				"Áudio alterou TrafficData.max_speed[%d] no modo %s" % [i, modo]
			)

		caminhao.free()
		passeio.free()
		esporte.free()
		am.free()
