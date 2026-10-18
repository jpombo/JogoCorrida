extends GdUnitTestSuite

## SPEC-012 / T004 — mute central de áudio (contracts settings/research R2,
## FR-002/FR-003): `AudioManager.set_geral_ativo` opera o bus Master via
## `AudioServer` (bus 0), é idempotente e `geral_ativo()` reflete o último
## estado. Seguro em headless — o driver dummy mantém o mixer funcional.

var _audio: AudioManager


func before_test() -> void:
	_audio = AudioManager.new()
	add_child(_audio)
	# Estado base conhecido para todos os casos.
	AudioServer.set_bus_mute(0, false)


func after_test() -> void:
	# Nunca vazar mute para as demais suítes da rodada.
	AudioServer.set_bus_mute(0, false)
	_audio.queue_free()


## 1 — Desligar ⇒ bus Master (índice 0) mudo; ligar ⇒ restaurado.
func test_01_desligar_e_reativar_muta_bus_master() -> void:
	assert_str(AudioServer.get_bus_name(0)).is_equal("Master")
	assert_bool(AudioServer.is_bus_mute(0)).is_false()

	_audio.set_geral_ativo(false)
	assert_bool(AudioServer.is_bus_mute(0)).is_true().override_failure_message(
		"FR-002: set_geral_ativo(false) deve mutar o bus Master"
	)

	_audio.set_geral_ativo(true)
	assert_bool(AudioServer.is_bus_mute(0)).is_false().override_failure_message(
		"FR-003: set_geral_ativo(true) deve restaurar o bus Master"
	)


## 2 — Idempotência: repetir a mesma chamada não oscila o estado.
func test_02_chamadas_repetidas_idempotentes() -> void:
	_audio.set_geral_ativo(false)
	_audio.set_geral_ativo(false)
	assert_bool(AudioServer.is_bus_mute(0)).is_true()

	_audio.set_geral_ativo(true)
	_audio.set_geral_ativo(true)
	assert_bool(AudioServer.is_bus_mute(0)).is_false()


## 3 — `geral_ativo()` reflete o último estado aplicado (true no nascimento).
func test_03_geral_ativo_reflete_ultimo_estado() -> void:
	assert_bool(_audio.geral_ativo()).is_true().override_failure_message(
		"estado inicial deve ser ligado"
	)
	_audio.set_geral_ativo(false)
	assert_bool(_audio.geral_ativo()).is_false()
	_audio.set_geral_ativo(true)
	assert_bool(_audio.geral_ativo()).is_true()
