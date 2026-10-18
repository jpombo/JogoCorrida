class_name ProgressManager
extends RefCounted

## Domínio de progressão/pontuação persistente (SPEC-011, FR-001…FR-011,
## FR-019, FR-021; data-model.md §1–§2; contracts/progress_manager_api.md):
## recordes, acumulados, troféus, ciclos e histórico por modo — zero I/O e
## zero nós (research R2; o SaveManager é a metade de disco). Chaves de modo
## são exatamente as de `difficulty_modes` (research R10). O ambiente da
## progressão continua no RaceProgression (SPEC-009): `processar_vitoria`
## RECEBE o ambiente capturado antes de `registra_vitoria()` (research R7).

## Versão do esquema persistido (data-model §3).
const VERSAO_ESQUEMA: int = 1

## Os 3 modos canônicos — sempre materializados após a carga (SC-005).
const MODOS: Array[String] = ["relaxing", "normal", "challenge"]

var _modos: Dictionary = {}
var _historico: Array = []


func _init() -> void:
	_materializar_modos({})


## Carrega o dicionário persistido (ou `{}`) e completa o que faltar —
## nunca herda estado de carga anterior (idempotente). Dados desconhecidos
## são ignorados; campos inválidos caem em default seguro (FR-022).
func carregar_de(dados: Dictionary) -> void:
	_modos = {}
	_historico = []
	var bruto: Variant = dados.get("modos", {}) if dados != null else {}
	_materializar_modos(bruto if bruto is Dictionary else {})
	var hist: Variant = dados.get("historico", []) if dados != null else []
	if hist is Array:
		for entrada in hist:
			if entrada is Dictionary and _resultado_util(entrada):
				_historico.append((entrada as Dictionary).duplicate(true))
	_trim_historico()


## Esquema v1 completo (data-model §3) — o que o SaveManager serializa.
func dados_para_salvar() -> Dictionary:
	return {
		"versao": VERSAO_ESQUEMA,
		"modos": _modos.duplicate(true),
		"historico": _historico.duplicate(true),
	}


## Calcula a pontuação da corrida (FR-004…FR-007, data-model §2) com clamp
## ≥ 0 — pesos sempre de GameConfig (§IV), nunca números no código.
func calcular_pontuacao(distancia: float, trofeus: int, perda_colisao: float) -> float:
	var bruto: float = (
		maxf(distancia, 0.0) * GameConfig.score_peso_distancia
		+ float(maxi(trofeus, 0)) * GameConfig.score_peso_trofeu
		- maxf(perda_colisao, 0.0) * GameConfig.score_peso_penalidade
	)
	return maxf(bruto, 0.0)


## Marca o ambiente no ciclo do modo (FR-009): repetição é no-op total;
## ao completar o conjunto de ambientes → +1 troféu e ciclo zerado.
func marcar_ambiente(modo: String, ambiente: String) -> void:
	var m: Dictionary = _modo(modo)
	var ciclo: Array = m["ciclo"]
	if ambiente in ciclo:
		return
	ciclo.append(ambiente)
	var alvo: int = GameConfig.environment_sequence.size()
	if alvo <= 0:
		alvo = 4
	if ciclo.size() >= alvo:
		m["trofeus"] = int(m["trofeus"]) + 1
		m["ciclo"] = []


## Encerramento em vitória (FR-001/FR-003/FR-006/FR-008; research R7) —
## ordem canônica: marcar ambiente (concede troféu da própria corrida) →
## calcular pontuação → atualizar recorde (só se estritamente maior) →
## acumulada → histórico (trim no teto) → snapshot. 1 chamada por corrida é
## responsabilidade do orquestrador (latch de encerramento).
func processar_vitoria(
	modo: String,
	ambiente: String,
	distancia: float,
	perda_colisao: float,
	data_hora: String = ""
) -> Dictionary:
	marcar_ambiente(modo, ambiente)
	var trofeus: int = get_trofeus(modo)
	var pontuacao: float = calcular_pontuacao(distancia, trofeus, perda_colisao)
	var m: Dictionary = _modo(modo)
	if pontuacao > float(m["recorde"]):
		m["recorde"] = pontuacao
	m["acumulada"] = float(m["acumulada"]) + pontuacao
	if data_hora == "":
		data_hora = Time.get_datetime_string_from_system()
	_historico.append({
		"modo": modo,
		"ambiente": ambiente,
		"distancia": distancia,
		"pontuacao": pontuacao,
		"trofeus": trofeus,
		"perda_colisao": perda_colisao,
		"data_hora": data_hora,
	})
	_trim_historico()
	return snapshot(modo, pontuacao)


## Encerramento em derrota (Q1-A/Q2-B): zera o ciclo do modo vigente,
## preserva o total de troféus e NÃO cria resultado nem toca recorde.
func processar_derrota(modo: String) -> Dictionary:
	_modo(modo)["ciclo"] = []
	return snapshot(modo)


## Snapshot da UI (data-model §1.5, contract ui_progress_display §1):
## `pontuacao` sempre presente; -1 = sem pontuação de corrida (menu/derrota).
func snapshot(modo: String, pontuacao: float = -1.0) -> Dictionary:
	var m: Dictionary = _modo(modo)
	return {
		"modo": modo,
		"recorde": float(m["recorde"]),
		"acumulada": float(m["acumulada"]),
		"trofeus": int(m["trofeus"]),
		"progresso_k": (m["ciclo"] as Array).size(),
		"desbloqueado": obstaculos_disponiveis(modo),
		"pontuacao": pontuacao,
	}


## Desbloqueio dos obstáculos (FR-018/FR-019, research R2): derivado do
## total de troféus do Relaxante — Normal/Desafio sempre livres; nunca
## armazenado (troféus de outros modos não desbloqueiam — SC-007).
func obstaculos_disponiveis(modo: String) -> bool:
	if modo == "relaxing":
		return get_trofeus("relaxing") >= 1
	return true


func get_recorde(modo: String) -> float:
	return float(_modo(modo)["recorde"])


func get_acumulada(modo: String) -> float:
	return float(_modo(modo)["acumulada"])


func get_trofeus(modo: String) -> int:
	return int(_modo(modo)["trofeus"])


func get_ciclo(modo: String) -> Array:
	return _modo(modo)["ciclo"]


## Instância do modo — sempre materializada (fallback seguro p/ chave
## desconhecida vinda de dados externos).
func _modo(modo: String) -> Dictionary:
	if not _modos.has(modo):
		_modos[modo] = _defaults()
	return _modos[modo]


func _defaults() -> Dictionary:
	return {"recorde": 0.0, "acumulada": 0.0, "trofeus": 0, "ciclo": []}


func _materializar_modos(bruto: Dictionary) -> void:
	for modo in MODOS:
		_modos[modo] = _ler_modo(bruto.get(modo, {}))


## Lê uma entrada persistida com tolerância total: tipos errados caem em
## default; `ciclo` é deduplicado e só aceita ambientes da sequência.
func _ler_modo(entrada: Variant) -> Dictionary:
	var m: Dictionary = _defaults()
	if not entrada is Dictionary:
		return m
	m["recorde"] = maxf(float(entrada.get("recorde", 0.0)), 0.0)
	m["acumulada"] = maxf(float(entrada.get("acumulada", 0.0)), 0.0)
	m["trofeus"] = maxi(int(entrada.get("trofeus", 0)), 0)
	var limpo: Array = []
	var ciclo: Variant = entrada.get("ciclo", [])
	if ciclo is Array:
		for item in ciclo:
			var id := String(item)
			if id in GameConfig.environment_sequence and not id in limpo:
				limpo.append(id)
	m["ciclo"] = limpo
	return m


func _resultado_util(entrada: Dictionary) -> bool:
	return entrada.has("modo") and entrada.has("pontuacao")


func _trim_historico() -> void:
	var teto: int = maxi(GameConfig.score_historico_max, 0)
	while _historico.size() > teto:
		_historico.remove_at(0)
