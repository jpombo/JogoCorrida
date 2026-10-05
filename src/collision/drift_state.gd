class_name DriftState
extends RefCounted

## Máquina de estados do drift do jogador (SPEC-005, FR-015, data-model §2).
## Sequência única: NORMAL → IMPACTO → DRIFT → RECUPERACAO → NORMAL.
## Pertence exclusivamente ao jogador; uma nova colisão substitui o drift anterior
## pela última classificação (spec §Edge Cases).

enum Phase { NORMAL, IMPACTO, DRIFT, RECUPERACAO }

var fase: int = Phase.NORMAL
var direcao: int = -1          # -1 esquerda, +1 direita
var forca: float = 0.0         # deslocamento lateral inicial (px/s)
var duracao: float = 0.0       # segundos da fase DRIFT
var tempo_decorrido: float = 0.0
var fator_controle: float = 1.0  # vigente; 1.0 fora do drift

var _forca_restante: float = 0.0


## Inicia (ou substitui) o drift com a classificação mais recente.
## A sequência é FR-015: entra em IMPACTO e `update()` transita para DRIFT.
func iniciar(p_direcao: int, p_forca: float, p_duracao: float) -> void:
	assert(p_direcao != 0, "DriftState.iniciar exige direção -1 ou +1")
	direcao = p_direcao
	forca = maxf(p_forca, 0.0)
	duracao = maxf(p_duracao, 0.001)
	tempo_decorrido = 0.0
	_forca_restante = forca
	fator_controle = GameConfig.drift_control_factor
	fase = Phase.IMPACTO


## Avança o estado, aplica o deslocamento lateral do impacto ao jogador e
## publica o fator de controle vigente. Limites da estrada vêm por quadro,
## da altura atual do jogador (FR-022, R7) — nunca de largura memorizada.
## `player` precisa expor `position`, e `controller` `control_factor`.
func update(delta: float, player: Node2D, limite_esq: float, limite_dir: float) -> void:
	match fase:
		Phase.NORMAL:
			return
		Phase.IMPACTO:
			fase = Phase.DRIFT
		Phase.DRIFT:
			tempo_decorrido += delta
			var restante: float = maxf(1.0 - tempo_decorrido / duracao, 0.0)
			_forca_restante = forca * restante
			player.position.x = clampf(
				player.position.x + direcao * _forca_restante * delta,
				limite_esq, limite_dir
			)
			# Controle nunca abaixo do fator configurado durante o drift (SC-004).
			fator_controle = GameConfig.drift_control_factor
			if tempo_decorrido >= duracao:
				fase = Phase.RECUPERACAO
		Phase.RECUPERACAO:
			# Retorno gradual até 100% à taxa configurável (FR-014).
			fator_controle = minf(
				fator_controle + GameConfig.drift_recovery_rate * delta, 1.0
			)
			if fator_controle >= 1.0:
				fator_controle = 1.0
				_forca_restante = 0.0
				fase = Phase.NORMAL

	if player.get("controller") != null:
		player.controller.control_factor = fator_controle


## Verdadeiro enquanto há influência do impacto ou recuperação em curso.
func ativo() -> bool:
	return fase != Phase.NORMAL
