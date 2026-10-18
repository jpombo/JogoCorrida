class_name NpcDriftState
extends RefCounted

## Estado pós-colisão de um NPC (SPEC-006, FR-021, data-model §4).
##
## Sequência única: NORMAL → IMPACTO → DRIFT → RECUPERACAO → NORMAL, sem
## outros estados. Um único drift ativo por veículo: `iniciar()` SUBSTITUI
## qualquer drift em curso reiniciando direção, força e duração (FR-014,
## Clarificação Q4).
##
## Encerrada a recuperação o NPC PERMANECE na posição lateral alcançada — não
## há retorno à faixa de origem (FR-022, Clarificação Q1); ele fica sujeito
## apenas aos limites da pista e à trajetória atual do agrupamento do
## SPEC-004.
##
## A velocidade do veículo NUNCA é tocada aqui nem em nenhum outro método
## desta classe (FR-017, SC-014): toda resposta ao impacto é lateral.

enum Fase { NORMAL, IMPACTO, DRIFT, RECUPERACAO }

var fase: int = Fase.NORMAL

## Direção do deslocamento: −1 esquerda, +1 direita (FR-015).
var direcao: int = 0

## Força (px/s) e duração (s) da fase DRIFT, interpoladas pela intensidade.
var forca: float = 0.0
var duracao: float = 0.0

## Tempo decorrido na fase corrente.
var tempo_decorrido: float = 0.0

## Progresso 0.0…1.0 da RECUPERACAO, à taxa `npc_drift_recovery_rate` (FR-023).
var fator_recuperacao: float = 1.0

## Deslocamento lateral acumulado em módulo — limitado por
## `npc_displacement_limit` (FR-020).
var deslocamento_acumulado: float = 0.0

## Cadeia da qual este drift é continuação (0 = impacto raiz, cadeia própria).
## É o estado que permite o ELO de encadeamento: o próximo impacto em que este
## veículo for o causador herda esta cadeia (FR-024, Clarificação Q5).
var cadeia_id: int = 0

## Profundidade da cadeia neste elo (1 no raiz) — FR-025.
var profundidade: int = 0

var _forca_restante: float = 0.0


## Inicia OU SUBSTITUI o drift pelo impacto mais recente (FR-014).
func iniciar(
	p_direcao: int,
	p_forca: float,
	p_duracao: float,
	p_cadeia_id: int = 0,
	p_profundidade: int = 1
) -> void:
	assert(p_direcao != 0, "NpcDriftState.iniciar exige direção −1 ou +1")
	direcao = p_direcao
	forca = maxf(p_forca, 0.0)
	duracao = maxf(p_duracao, 0.001)
	tempo_decorrido = 0.0
	fator_recuperacao = 0.0
	deslocamento_acumulado = 0.0
	_forca_restante = forca
	cadeia_id = p_cadeia_id
	profundidade = p_profundidade
	fase = Fase.IMPACTO


func ativo() -> bool:
	return fase != Fase.NORMAL


## Avança as fases e devolve o deslocamento lateral EFETIVO do quadro (px com
## sinal), já limitado por `npc_displacement_limit` (FR-020) e pelos limites
## da pista na altura do veículo (FR-018).
##
## `posicao_atual` é o x vigente do veículo: o estado é RefCounted e não
## conhece o nó (data-model §4), então o chamador injeta a posição.
## `limite_esq`/`limite_dir` vêm dos limites vigentes do Road NA ALTURA DO
## VEÍCULO, consultados por quadro — nunca largura memorizada (FR-040, R3).
func proximo_deslocamento(
	delta: float, posicao_atual: float, limite_esq: float, limite_dir: float
) -> float:
	match fase:
		Fase.NORMAL:
			return 0.0
		Fase.IMPACTO:
			fase = Fase.DRIFT
			# Clamp já no primeiro quadro: a pista pode ter encolhido entre o
			# contato e agora (FR-018, FR-020). Correção de pista não conta no
			# teto de deslocamento — só o drift empurra para fora.
			return clampf(posicao_atual, limite_esq, limite_dir) - posicao_atual
		Fase.DRIFT:
			tempo_decorrido += delta
			var restante: float = maxf(1.0 - tempo_decorrido / duracao, 0.0)
			_forca_restante = forca * restante
			var desejado: float = direcao * _forca_restante * delta
			var aplicado: float = _limitar_deslocamento(
				desejado, posicao_atual, limite_esq, limite_dir
			)
			if tempo_decorrido >= duracao:
				fase = Fase.RECUPERACAO
				fator_recuperacao = 0.0
			return aplicado
		Fase.RECUPERACAO:
			# Sem retorno à origem (Q1): só mantém o veículo dentro dos
			# limites VIGENTES — clamp contínuo por quadro, mesmo com o
			# corredor encolhendo (FR-022, FR-040) — e completa a recuperação
			# gradual (FR-023). A correção da pista não incrementa
			# deslocamento_acumulado: o teto é do drift, não da estreitura.
			var correcao: float = clampf(posicao_atual, limite_esq, limite_dir) - posicao_atual
			fator_recuperacao = minf(
				fator_recuperacao + GameConfig.npc_drift_recovery_rate * delta, 1.0
			)
			if fator_recuperacao >= 1.0:
				fase = Fase.NORMAL
				cadeia_id = 0
				profundidade = 0
			return correcao
	return 0.0


## Aplica o deslocamento respeitando o teto acumulado e a janela da pista.
func _limitar_deslocamento(
	desejado: float, posicao_atual: float, limite_esq: float, limite_dir: float
) -> float:
	var restante: float = maxf(GameConfig.npc_displacement_limit - deslocamento_acumulado, 0.0)
	var limitado: float = clampf(desejado, -restante, restante)
	var alvo: float = clampf(posicao_atual + limitado, limite_esq, limite_dir)
	var efetivo: float = alvo - posicao_atual
	deslocamento_acumulado += absf(efetivo)
	return efetivo


## Encerra o drift (usado quando o veículo é reciclado — deactivate()).
func resetar() -> void:
	fase = Fase.NORMAL
	direcao = 0
	forca = 0.0
	duracao = 0.0
	tempo_decorrido = 0.0
	fator_recuperacao = 1.0
	deslocamento_acumulado = 0.0
	cadeia_id = 0
	profundidade = 0
	_forca_restante = 0.0
