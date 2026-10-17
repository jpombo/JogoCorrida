extends GdUnitTestSuite

## SPEC-011 / T003 (Foundational) — SaveManager: round-trip gravar→carregar
## em `user://` temporário, arquivo ausente ⇒ `{}`, JSON corrompido ⇒ `{}` sem
## tocar o arquivo e falha de gravação preservando o arquivo anterior
## (escrita atômica tmp+rename — SC-010, contract progress_manager_api §4).

const ARQUIVO: String = "user://spec011_save_test.json"
const TMP: String = ARQUIVO + ".tmp"


func before_test() -> void:
	_limpar()


func after_test() -> void:
	_limpar()


func _limpar() -> void:
	if FileAccess.file_exists(ARQUIVO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO))
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TMP)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


## SC-010 — round-trip: gravar devolve true, carregar devolve o mesmo
## dicionário e o arquivo fica em `user://` no caminho configurado.
func test_01_round_trip() -> void:
	var sm := SaveManager.new(ARQUIVO)
	var dados := {"versao": 1, "modos": {"normal": {"recorde": 12.5}}, "historico": []}
	assert_bool(sm.gravar(dados)).is_true().override_failure_message(
		"gravar falhou em caminho válido de user://"
	)
	assert_bool(FileAccess.file_exists(ARQUIVO)).is_true()

	var sm2 := SaveManager.new(ARQUIVO)
	var carregado: Dictionary = sm2.carregar()
	assert_bool(carregado.is_empty()).is_false()
	assert_int(int(carregado.get("versao", 0))).is_equal(1)
	assert_float(float(carregado["modos"]["normal"]["recorde"])).is_equal_approx(12.5, 0.001)


## SC-010 — arquivo ausente: `{}` sem erro e sem criar nada em disco.
func test_02_arquivo_ausente_devolve_vazio() -> void:
	var sm := SaveManager.new(ARQUIVO)
	var carregado: Dictionary = sm.carregar()
	assert_bool(carregado.is_empty()).is_true()
	assert_bool(FileAccess.file_exists(ARQUIVO)).is_false()


## FR-022 — JSON corrompido: `{}` sem derrubar e SEM sobrescrever o arquivo
## inválido (carga nunca escreve).
func test_03_json_corrompido_devolve_vazio_sem_tocar_arquivo() -> void:
	var f = FileAccess.open(ARQUIVO, FileAccess.WRITE)
	f.store_string("{isto nao e json valido!!")
	f.close()

	var sm := SaveManager.new(ARQUIVO)
	var carregado: Dictionary = sm.carregar()
	assert_bool(carregado.is_empty()).is_true()

	var texto_depois: String = ""
	var f2 = FileAccess.open(ARQUIVO, FileAccess.READ)
	if f2 != null:
		texto_depois = f2.get_as_text()
		f2.close()
	assert_str(texto_depois).is_equal("{isto nao e json valido!!")


## Edge case "falha de gravação" — o `.tmp` virou DIRETÓRIO, o open de
## escrita falha, `gravar` devolve false e o arquivo válido anterior
## permanece intacto (garantia da escrita atômica).
func test_04_falha_de_gravacao_preserva_anterior() -> void:
	var sm := SaveManager.new(ARQUIVO)
	var dados := {"versao": 1, "modos": {}, "historico": []}
	assert_bool(sm.gravar(dados)).is_true()
	# Ocupa o caminho do tmp com um diretório ⇒ open(WRITE) falha.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))

	assert_bool(sm.gravar({"versao": 1, "modos": {"x": 1}, "historico": []})).is_false()

	var carregado: Dictionary = sm.carregar()
	assert_bool(carregado.has("modos")).is_true()
	assert_bool(carregado["modos"] is Dictionary and (carregado["modos"] as Dictionary).is_empty()).is_true()
	assert_bool(carregado.has("x") or (carregado.get("modos") as Dictionary).has("x")).is_false()
	# Remove o diretório que bloqueou o tmp (limpeza do teste).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


## Seam de teste: falha no MEIO da escrita (disco cheio) — o `gravar` deve
## reportar false, remover o `.tmp` parcial e preservar o arquivo válido
## (edge case "falha de gravação", FR-022/SC-010, T039).
class SaveComFalhaDeEscrita extends SaveManager:
	func _escrever(_arquivo: FileAccess, _texto: String) -> bool:
		return false


func test_05_escrita_parcial_preserva_o_anterior() -> void:
	var sm := SaveManager.new(ARQUIVO)
	assert_bool(sm.gravar(
		{"versao": 1, "modos": {"normal": {"recorde": 9.9}}, "historico": []}
	)).is_true()

	var falho := SaveComFalhaDeEscrita.new(ARQUIVO)
	assert_bool(falho.gravar(
		{"versao": 1, "modos": {"normal": {"recorde": 1.0}}, "historico": []}
	)).is_false().override_failure_message(
		"escrita parcial não foi reportada como falha"
	)
	assert_bool(FileAccess.file_exists(TMP)).is_false().override_failure_message(
		".tmp parcial ficou para trás"
	)

	var dados: Dictionary = SaveManager.new(ARQUIVO).carregar()
	var recorde: float = float((dados["modos"] as Dictionary)["normal"]["recorde"])
	assert_float(recorde).is_equal_approx(9.9, 0.001).override_failure_message(
		"escrita parcial destruiu o arquivo válido anterior"
	)
