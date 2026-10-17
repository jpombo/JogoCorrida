class_name SaveManager
extends RefCounted

## I/O de persistência (SPEC-011, FR-021/FR-022; research R1/R2; contracts/
## progress_manager_api.md §4): só grava e carrega JSON — zero domínio (não
## sabe o que é "recorde"). Caminho injetável para testes. Gravação atômica
## (tmp + rename): falha no meio preserva o arquivo válido anterior (edge
## case "falha de gravação"); carga ausente/inválida devolve `{}` sem tocar
## no disco e sem nunca sobrescrever dados válidos com defaults.

var caminho: String


func _init(p_caminho: String = "") -> void:
	caminho = p_caminho if p_caminho != "" else String(GameConfig.save_arquivo)


## `{}` se ausente, ilegível ou JSON inválido — nunca grava, nunca lança
## erro (FR-022, SC-010).
func carregar() -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var arquivo = FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return {}
	var texto: String = arquivo.get_as_text()
	arquivo.close()
	var dados: Variant = JSON.parse_string(texto)
	if dados is Dictionary:
		return dados
	return {}


## Escrita atômica: serializa em `<arquivo>.tmp` e renomeia por cima — no
## mesmo filesystem o rename é atômico. `false` em qualquer falha (inclusive
## falha de ESCRITA no meio — o `.tmp` parcial é removido, nunca renomeado
## por cima do dado válido); o arquivo anterior permanece intacto.
func gravar(dados: Dictionary) -> bool:
	var tmp: String = caminho + ".tmp"
	var arquivo = FileAccess.open(tmp, FileAccess.WRITE)
	if arquivo == null:
		return false
	var ok: bool = _escrever(arquivo, JSON.stringify(dados, "  "))
	arquivo.close()
	if not ok:
		_remover_tmp(tmp)
		return false
	var origem: String = ProjectSettings.globalize_path(tmp)
	var destino: String = ProjectSettings.globalize_path(caminho)
	if DirAccess.rename_absolute(origem, destino) == OK:
		return true
	_remover_tmp(tmp)
	return false


## Checagem real de I/O (T039, edge case "falha de gravação" — FR-022):
## `store_string` não propaga erro; só `get_error()` denuncia a escrita
## parcial (disco cheio). Seam de teste para simular essa falha.
func _escrever(arquivo: FileAccess, texto: String) -> bool:
	arquivo.store_string(texto)
	arquivo.flush()
	return arquivo.get_error() == OK


func _remover_tmp(tmp: String) -> void:
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
