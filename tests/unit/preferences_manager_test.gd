extends GdUnitTestSuite

## SPEC-012 / T002 — PreferencesManager (contracts/preferences_manager_api.md
## §1–2): round-trip gravação/carga, arquivo ausente ⇒ defaults SEM gravação,
## JSON corrompido ⇒ defaults, `versao` desconhecida ⇒ todos os defaults,
## validação campo a campo (recuperação parcial preservando o campo vizinho
## válido) e `definir_resolucao` inválido ⇒ no-op total (sem mudança de
## estado e sem regravação do arquivo).

var _caminho: String


func before_test() -> void:
	_caminho = "user://teste_pref_%d.json" % (Time.get_ticks_msec() + randi() % 100000)
	_limpar()


func after_test() -> void:
	_limpar()


func _limpar() -> void:
	if FileAccess.file_exists(_caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_caminho))
	if FileAccess.file_exists(_caminho + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_caminho + ".tmp"))


func _escrever_bruto(texto: String) -> void:
	var arquivo = FileAccess.open(_caminho, FileAccess.WRITE)
	arquivo.store_string(texto)
	arquivo.close()


func _ler_bruto() -> String:
	if not FileAccess.file_exists(_caminho):
		return ""
	var arquivo = FileAccess.open(_caminho, FileAccess.READ)
	var texto: String = arquivo.get_as_text()
	arquivo.close()
	return texto


## 1 — Round-trip: mutação persiste e uma nova instância restaura (SC-002).
func test_01_round_trip_gravacao_e_carga() -> void:
	var pref := PreferencesManager.new(_caminho)
	assert_bool(pref.audio_ativo).is_true()
	assert_that(pref.resolucao).is_equal(Vector2i(640, 480))

	pref.definir_audio_ativo(false)
	pref.definir_resolucao(Vector2i(1024, 768))
	assert_bool(FileAccess.file_exists(_caminho)).is_true().override_failure_message(
		"definir_* deve persistir em disco no caminho injetado"
	)

	var recarregada := PreferencesManager.new(_caminho)
	recarregada.carregar()
	assert_bool(recarregada.audio_ativo).is_false().override_failure_message(
		"round-trip: audio_ativo não restaurou o false persistido"
	)
	assert_that(recarregada.resolucao).is_equal(Vector2i(1024, 768)).override_failure_message(
		"round-trip: resolucao não restaurou 1024×768 persistido"
	)


## 2 — Arquivo ausente: defaults na carga e NENHUMA gravação (SC-003).
func test_02_arquivo_ausente_defaults_sem_gravacao() -> void:
	var pref := PreferencesManager.new(_caminho)
	pref.carregar()
	assert_bool(pref.audio_ativo).is_true()
	assert_that(pref.resolucao).is_equal(Vector2i(640, 480))
	assert_bool(FileAccess.file_exists(_caminho)).is_false().override_failure_message(
		"carregar() nunca grava — o arquivo não pode surgir na carga"
	)


## 3 — JSON corrompido: defaults sem erro de console (edge case da spec).
func test_03_json_corrompido_defaults() -> void:
	_escrever_bruto("{ isto nao é json válido ]")
	var pref := PreferencesManager.new(_caminho)
	pref.carregar()
	assert_bool(pref.audio_ativo).is_true()
	assert_that(pref.resolucao).is_equal(Vector2i(640, 480))


## 4 — `versao` ausente/diferente de 1 ⇒ TODOS os defaults, mesmo que os
## campos estejam individualmente válidos (contracts §2).
func test_04_versao_desconhecida_todos_defaults() -> void:
	_escrever_bruto('{"versao": 99, "audio": false, "resolucao": [1024, 768]}')
	var pref := PreferencesManager.new(_caminho)
	pref.carregar()
	assert_bool(pref.audio_ativo).is_true().override_failure_message(
		"versao desconhecida deve cair no default de áudio (true)"
	)
	assert_that(pref.resolucao).is_equal(Vector2i(640, 480)).override_failure_message(
		"versao desconhecida deve cair no default de resolução"
	)


## 5 — Validação campo a campo: campo inválido recupera o DEFAULT próprio e
## preserva o campo vizinho válido (recuperação parcial, contracts §2).
func test_05_recuperacao_parcial_campo_a_campo() -> void:
	_escrever_bruto('{"versao": 1, "audio": "sim", "resolucao": [1024, 768]}')
	var pref := PreferencesManager.new(_caminho)
	pref.carregar()
	assert_bool(pref.audio_ativo).is_true().override_failure_message(
		"audio não-bool deve cair no default sem derrubar a resolução"
	)
	assert_that(pref.resolucao).is_equal(Vector2i(1024, 768)).override_failure_message(
		"resolução válida deve sobreviver ao campo de áudio inválido"
	)

	_escrever_bruto('{"versao": 1, "audio": false, "resolucao": [800, 600]}')
	var pref2 := PreferencesManager.new(_caminho)
	pref2.carregar()
	assert_bool(pref2.audio_ativo).is_false().override_failure_message(
		"áudio válido deve sobreviver à resolução inválida"
	)
	assert_that(pref2.resolucao).is_equal(Vector2i(640, 480)).override_failure_message(
		"resolução fora do conjunto deve cair no default"
	)


## 6 — `definir_resolucao` inválido ⇒ no-op TOTAL: nem estado, nem gravação.
func test_06_definir_resolucao_invalida_noop_total() -> void:
	var pref := PreferencesManager.new(_caminho)
	pref.definir_resolucao(Vector2i(1024, 768))
	var antes: String = _ler_bruto()

	pref.definir_resolucao(Vector2i(800, 600))
	assert_that(pref.resolucao).is_equal(Vector2i(1024, 768)).override_failure_message(
		"resolução inválida não pode mudar o estado (no-op)"
	)
	assert_str(_ler_bruto()).is_equal(antes).override_failure_message(
		"resolução inválida não pode regravar o arquivo (no-op de gravação)"
	)


## 7 — `dados_para_salvar()` no esquema v1 (data-model §2): versao int 1,
## audio bool e resolucao Array de 2 inteiros.
func test_07_dados_para_salvar_esquema_v1() -> void:
	var pref := PreferencesManager.new(_caminho)
	pref.definir_audio_ativo(false)
	pref.definir_resolucao(Vector2i(1024, 768))
	var dados: Dictionary = pref.dados_para_salvar()

	assert_int(dados.size()).is_equal(3)
	assert_int(dados.get("versao", 0)).is_equal(1)
	assert_bool(dados.get("audio", true)).is_false()
	var res: Variant = dados.get("resolucao", [])
	assert_bool(res is Array and (res as Array).size() == 2).is_true()
	assert_int(int((res as Array)[0])).is_equal(1024)
	assert_int(int((res as Array)[1])).is_equal(768)
