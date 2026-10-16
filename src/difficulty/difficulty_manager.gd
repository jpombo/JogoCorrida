class_name DifficultyManager
extends RefCounted

## Configuração efetiva de dificuldade da corrida (SPEC-009, R8): dono do
## modo vigente e dos 5 fatores por modo lidos de `GameConfig.
## difficulty_modes`. Componente próprio por responsabilidade (constitution
## §III) — instanciado pelo GameplayManager e injetado por referência nos
## sistemas (contracts/difficulty_manager_api.md §2). Não conhece
## RaceProgression: o fator de ciclo chega via `aplicar_fator_ciclo` (evita
## acoplamento cíclico — quem sincroniza é o GameplayManager).
##
## Leituras são puras (sem efeitos colaterais, sem alocação por quadro).
## Fator ausente na config → 1,0 naquele campo (fallback seguro, FR-002);
## modo inválido → "normal" + push_warning (FR-001).

## Ordem estrutural do ciclo do menu: relaxante → normal → desafio →
## relaxante (contracts/difficulty_manager_api.md §1).
const ORDEM_CICLO: Array[String] = ["relaxing", "normal", "challenge"]

## Modo vigente (validado — nunca mantém id inválido).
var _modo: String = "normal"

## Fator de ciclo gravado por corrida (1,0 = ciclo 1, sem bônus).
var _fator_ciclo: float = 1.0


func _init() -> void:
	_modo = _modo_valido_ou_padrao(String(GameConfig.difficulty_default_mode))


## Define o modo vigente. Chave ausente/nula cai no default configurado
## ("normal") com warning — a corrida nunca quebra por modo inválido.
func definir_modo(id: String) -> void:
	if _valido(id):
		_modo = id
		return
	var padrao: String = String(GameConfig.difficulty_default_mode)
	push_warning(
		"[SPEC-009] Modo de dificuldade inválido '%s' — usando '%s'" % [id, padrao]
	)
	_modo = _modo_valido_ou_padrao(padrao)


## Cicla relaxante → normal → desafio → relaxante; retorna o novo id.
func ciclar_modo() -> String:
	var indice: int = ORDEM_CICLO.find(_modo)
	if indice < 0:
		# Estado corrupto (config mutada em teste): retoma pela trilha válida.
		_modo = _modo_valido_ou_padrao("normal")
		indice = ORDEM_CICLO.find(_modo)
	_modo = ORDEM_CICLO[(indice + 1) % ORDEM_CICLO.size()]
	return _modo


func get_modo() -> String:
	return _modo


## Grava o fator de ciclo da corrida (RaceProgression.fator_ciclo()).
## Valor não positivo é descartado (fallback seguro — nunca < 1,0).
func aplicar_fator_ciclo(f: float) -> void:
	_fator_ciclo = f if f > 0.0 else 1.0


func fator_ciclo() -> float:
	return _fator_ciclo


func multiplicador_velocidade() -> float:
	return _fator_de("velocidade")


func fator_velocidade_total() -> float:
	return multiplicador_velocidade() * _fator_ciclo


## Aplica o fator total a uma base (velocidade-base nunca mutada, R1).
func efetiva(base: float) -> float:
	return base * fator_velocidade_total()


func fator_densidade() -> float:
	return _fator_de("densidade")


func fator_frequencia_galoes() -> float:
	return _fator_de("frequencia_galoes")


func fator_penalidade_colisao() -> float:
	return _fator_de("penalidade_colisao")


func fator_distancia_galoes() -> float:
	return _fator_de("distancia_galoes")


## Leitura pura de um fator do modo vigente; campo/entrada ausente → 1,0.
func _fator_de(campo: String) -> float:
	var entrada: Variant = GameConfig.difficulty_modes.get(_modo, null)
	if entrada is Dictionary:
		var valor: Variant = entrada.get(campo, null)
		if valor is float or valor is int:
			return float(valor)
	return 1.0


func _valido(id: String) -> bool:
	return GameConfig.difficulty_modes.has(id)


## Resolve um id para um modo presente na config; se nem o candidato nem
## "normal" existirem, mantém "normal" (leituras caem em 1,0 — seguro).
func _modo_valido_ou_padrao(id: String) -> String:
	if _valido(id):
		return id
	if _valido("normal"):
		return "normal"
	return "normal"
