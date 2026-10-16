extends GdUnitTestSuite

## SPEC-010 / T009 (US2) — vozes de motor: mapeamento por `category.id`
## (R6), 1:1 veículo→voz (I1), pool cheia ⇒ silêncio, ciclo de vida liga/
## para (SC-003/SC-004), gate do jogador (FR-003/Q3/I9) e `loop = true`
## em todos os streams de motor (R1).


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


## R6 — caminhão recebe AUD-002, demais categorias e o jogador AUD-003.
func test_01_mapeamento_por_categoria() -> void:
	var am := _am(_cfg())
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	var caminhao := _npc("caminhao")
	var passeio := _npc("passeio")
	am.ao_veiculo_surgir(caminhao)
	am.ao_veiculo_surgir(passeio)
	assert_bool(
		am._vozes_motor[am._dicionario[caminhao]].stream == am._stream_caminhao
	).is_true().override_failure_message("Caminhão não recebeu AUD-002")
	assert_bool(
		am._vozes_motor[am._dicionario[passeio]].stream == am._stream_carro
	).is_true().override_failure_message("Passeio não recebeu AUD-003")
	assert_bool(am._vozes_motor[0].stream == am._stream_carro).is_true().override_failure_message(
		"Voz do jogador não é AUD-003"
	)
	caminhao.free()
	passeio.free()
	am.free()


## I1 — 1 voz por veículo: spawn duplicado é no-op; saída desconhecida é
## no-op; saída conhecida devolve a slot.
func test_02_um_por_veiculo_e_noops() -> void:
	var am := _am(_cfg())
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	var npc := _npc("passeio")
	am.ao_veiculo_surgir(npc)
	var indice: int = am._dicionario[npc]
	var ocupadas := am.vozes_motor_ocupadas()
	am.ao_veiculo_surgir(npc)
	assert_int(am.vozes_motor_ocupadas()).is_equal(ocupadas).override_failure_message(
		"Spawn duplicado ocupou uma segunda voz"
	)
	assert_int(am._dicionario[npc]).is_equal(indice)
	am.ao_veiculo_sair(npc)
	assert_bool(am._dicionario.has(npc)).is_false()
	var ocupadas_apos := am.vozes_motor_ocupadas()
	am.ao_veiculo_sair(npc)  # desconhecido ⇒ no-op
	assert_int(am.vozes_motor_ocupadas()).is_equal(ocupadas_apos)
	npc.free()
	am.free()


## Pool cheia ⇒ o novo NPC é registrado sem voz (silêncio, -1), sem erro.
func test_03_pool_cheia_registra_sem_voz() -> void:
	var am := _am(_cfg({"vozes_motor": 2}))  # 1 jogador + 1 NPC
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	var a := _npc("passeio")
	var b := _npc("esporte")
	am.ao_veiculo_surgir(a)
	am.ao_veiculo_surgir(b)
	assert_int(am._dicionario[a]).is_greater_equal(0)
	assert_int(am._dicionario[b]).is_equal(-1).override_failure_message(
		"Pool cheia deveria registrar o NPC sem voz (silêncio)"
	)
	a.free()
	b.free()
	am.free()


## SC-003/SC-004 — nascido antes do PLAYING fica parado; a virada liga;
## saída (reciclagem ou fim de PLAYING) para — zero som órfão.
func test_04_ciclo_de_vida_liga_para() -> void:
	var am := _am(_cfg())
	var npc := _npc("passeio")
	am.ao_veiculo_surgir(npc)  # pré-largada: registrado parado
	var indice: int = am._dicionario[npc]
	assert_bool(am._vozes_motor[indice].playing).is_false().override_failure_message(
		"NPC tocou antes do PLAYING"
	)
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.READY)
	assert_bool(am._vozes_motor[indice].playing).is_true().override_failure_message(
		"Virada para PLAYING não ligou o NPC"
	)
	am.ao_veiculo_sair(npc)
	assert_bool(am._vozes_motor[indice].playing).is_false().override_failure_message(
		"Reciclagem deixou som órfão"
	)
	# Fim de PLAYING também silencia o que está em voo. O re-spawn pode
	# receber outra voz livre (lista FIFO) — índice relido do dicionário.
	am.ao_veiculo_surgir(npc)
	indice = am._dicionario[npc]
	assert_bool(am._vozes_motor[indice].playing).is_true().override_failure_message(
		"Re-spawn em PLAYING não religou o motor"
	)
	am.ao_alterar_estado(GameState.State.VICTORY, GameState.State.PLAYING)
	assert_bool(am._vozes_motor[indice].playing).is_false().override_failure_message(
		"Saída de PLAYING não parou o motor do NPC"
	)
	npc.free()
	am.free()


## FR-003/Q3/I9 — a entrada em PLAYING não liga o jogador sozinha; o gate
## liga com `true` em PLAYING, silencia com `false`, e `true` fora de
## PLAYING é ignorado.
func test_05_gate_do_jogador() -> void:
	var am := _am(_cfg())
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	assert_bool(am._vozes_motor[0].playing).is_false().override_failure_message(
		"Entrada em PLAYING ligou o jogador sem o gate (I9)"
	)
	am.ao_aceleracao_jogador(true)
	assert_bool(am._vozes_motor[0].playing).is_true().override_failure_message(
		"Gate true em PLAYING não ligou a voz do jogador"
	)
	assert_bool(am.voz_jogador_tocando()).is_true()
	am.ao_aceleracao_jogador(false)
	assert_bool(am._vozes_motor[0].playing).is_false().override_failure_message(
		"Gate false não silenciou a voz do jogador"
	)
	# Fora de PLAYING o play físico é suprimido (flag armazenado, I8).
	am.ao_alterar_estado(GameState.State.MENU, GameState.State.PLAYING)
	am.ao_aceleracao_jogador(true)
	assert_bool(am._vozes_motor[0].playing).is_false()
	assert_bool(am.voz_jogador_tocando()).is_false()
	am.free()


## R1 — todos os streams de motor com loop; jogador + NPCs tocam juntos.
func test_06_streams_com_loop_e_simultaneidade() -> void:
	var am := _am(_cfg())
	am.ao_alterar_estado(GameState.State.PLAYING, GameState.State.MENU)
	var caminhao := _npc("caminhao")
	var passeio := _npc("passeio")
	am.ao_veiculo_surgir(caminhao)
	am.ao_veiculo_surgir(passeio)
	am.ao_aceleracao_jogador(true)
	var tocando := 0
	for voz in am._vozes_motor:
		if voz.stream != null:
			assert_bool((voz.stream as AudioStreamMP3).loop).is_true().override_failure_message(
				"Stream de motor sem loop (não-contínuo)"
			)
		if voz.playing:
			tocando += 1
	assert_int(tocando).is_greater_equal(3).override_failure_message(
		"Jogador + 2 NPCs deveriam tocar simultaneamente (tocando=%d)" % tocando
	)
	caminhao.free()
	passeio.free()
	am.free()
