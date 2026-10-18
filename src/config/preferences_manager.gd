class_name PreferencesManager
extends RefCounted

## SPEC-012 — domínio e validação das preferências do jogador (áudio geral +
## resolução; contracts/preferences_manager_api.md §1–2, research R1).
## `RefCounted`, sem nós: I/O 100% delegado ao `SaveManager` existente com
## caminho injetável (mesmo padrão do SaveManager original). Arquivo
## SEPARADO de `user://progresso.json` (Clarificação Q1, FR-010) — o
## ProgressManager nunca lê/estes dados. `carregar()` nunca grava e nunca
## falha; validação é CAMPO A CAMPO (recuperação parcial); `definir_*` com
## valor inválido é no-op total (nem estado, nem gravação).

## Estado corrente — defaults do `GameConfig` (FR-009).
var audio_ativo: bool = GameConfig.preferencias_padrao_audio
var resolucao: Vector2i = GameConfig.preferencias_resolucao_padrao

## Par de I/O — caminho injetável para testes (research R1).
var _save: SaveManager


func _init(caminho: String = GameConfig.preferencias_arquivo) -> void:
	_save = SaveManager.new(caminho)


## Lê o arquivo validando campo a campo (nunca grava, nunca falha — o
## comportamento falha-seguro já é do `SaveManager.carregar()`):
## - `versao` ausente/diferente de 1 ⇒ mantém TODOS os defaults (contracts §2);
## - `audio` não-bool ⇒ default do áudio, preservando a resolução válida;
## - `resolucao` fora do conjunto ⇒ default da resolução, preservando o áudio
##   válido (recuperação parcial).
func carregar() -> void:
	var dados: Dictionary = _save.carregar()
	if dados.is_empty():
		return
	if not _versao_valida(dados.get("versao")):
		return
	if dados.has("audio") and dados["audio"] is bool:
		audio_ativo = bool(dados["audio"])
	if dados.has("resolucao"):
		var candidata := _ler_resolucao(dados["resolucao"])
		if candidata.x > 0:
			resolucao = candidata


## Grava o esquema v1 completo; `false` em falha (arquivo anterior intacto —
## escrita atômica do SaveManager).
func salvar() -> bool:
	return _save.gravar(dados_para_salvar())


## Mutação + persistência. `valor` fora de `preferencias_resolucoes` ⇒ no-op
## total (nem estado, nem gravação).
func definir_audio_ativo(valor: bool) -> void:
	audio_ativo = valor
	salvar()


func definir_resolucao(valor: Vector2i) -> void:
	if not resolucao_valida(valor):
		return
	resolucao = valor
	salvar()


## Esquema v1 (data-model §2): `{"versao": 1, "audio": bool, "resolucao": [w, h]}`.
func dados_para_salvar() -> Dictionary:
	return {
		"versao": 1,
		"audio": audio_ativo,
		"resolucao": [resolucao.x, resolucao.y],
	}


## Conjunto válido = `GameConfig.preferencias_resolucoes` (FR-004).
func resolucao_valida(valor: Vector2i) -> bool:
	return GameConfig.preferencias_resolucoes.has(valor)


## `versao` só vale como número inteiro/real com valor 1 — JSON devolve
## número como float; string "1" não é versão válida.
func _versao_valida(valor: Variant) -> bool:
	if not (valor is int or valor is float):
		return false
	return int(valor) == 1


## Extrai `resolucao` de um valor JSON não confiável. Retorna `Vector2i.ZERO`
## quando o valor não é um par numérico de tamanho 2 (tipo interno malformado
## nunca propaga erro — "nunca falha"). A pertinência ao conjunto válido é
## checada pela chamada.
func _ler_resolucao(valor: Variant) -> Vector2i:
	if not (valor is Array):
		return Vector2i.ZERO
	var arr := valor as Array
	if arr.size() != 2:
		return Vector2i.ZERO
	if not (arr[0] is int or arr[0] is float):
		return Vector2i.ZERO
	if not (arr[1] is int or arr[1] is float):
		return Vector2i.ZERO
	var candidata := Vector2i(int(arr[0]), int(arr[1]))
	if not resolucao_valida(candidata):
		return Vector2i.ZERO
	return candidata
