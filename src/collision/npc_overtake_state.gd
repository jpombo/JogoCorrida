class_name NpcOvertakeState
extends RefCounted

## Deslocamento lateral temporário do NPC na colisão tipo 1-3
## (SPEC-005, FR-018–FR-021, data-model §4).
## Nunca altera a velocidade do NPC — é um offset de posição com clamp.
##
## Ajuste 6 (FR-021): o deslocamento tem DUAS fases — ida até a magnitude e
## RETORNO à faixa de origem (`x_origem`) em `duracao_retorno`. Sem o retorno
## o NPC permanecia 40 px fora da faixa reservada da sua velocidade, caía no
## corredor de outra categoria e o limitador de espaçamento acoplava as duas
## velocidades (caminhões saíam em taxa de passeio depois de colisões).

enum Fase { INATIVA, IDA, RETORNO }

var fase: int = Fase.INATIVA
var direcao: int = 0        # 0 = inativo; -1 esquerda, +1 direita
var magnitude: float = 0.0  # deslocamento lateral total alvo da IDA (px)
var duracao: float = 0.0    # segundos da IDA
var duracao_retorno: float = 1.0  # segundos do RETORNO
var tempo_decorrido: float = 0.0
var aplicado: float = 0.0   # quanto já foi deslocado na IDA (px com sinal)
var x_origem: float = 0.0   # x da faixa de origem capturado no início (px)


func iniciar(
	p_direcao: int,
	p_magnitude: float,
	p_duracao: float,
	p_duracao_retorno: float = 1.0,
	p_x_origem: float = 0.0
) -> void:
	assert(p_direcao != 0, "NpcOvertakeState.iniciar exige direção -1 ou +1")
	# Nova colisão no meio de um deslocamento anterior: a faixa de origem é a
	# ORIGINAL — manter a primeira evita que colisões em cadeia "caminhem" o
	# NPC lateralmente para longe da faixa da sua velocidade.
	var manter_origem: bool = fase != Fase.INATIVA
	direcao = p_direcao
	magnitude = maxf(p_magnitude, 0.0)
	duracao = maxf(p_duracao, 0.001)
	duracao_retorno = maxf(p_duracao_retorno, 0.001)
	tempo_decorrido = 0.0
	aplicado = 0.0
	x_origem = x_origem if manter_origem else p_x_origem
	fase = Fase.IDA


func ativo() -> bool:
	return fase != Fase.INATIVA


func em_ida() -> bool:
	return fase == Fase.IDA


func em_retorno() -> bool:
	return fase == Fase.RETORNO


## Próximo incremento lateral do quadro (px com sinal) — fase de IDA, linear
## até a magnitude. Ao concluir (ou ao travar no limite da pista), muda para a
## fase de RETORNO; o deslocamento só termina quando a faixa de origem é
## reocupada (FR-021).
func proximo_incremento(delta: float) -> float:
	if fase != Fase.IDA:
		return 0.0
	tempo_decorrido += delta
	var alvo: float = direcao * magnitude * minf(tempo_decorrido / duracao, 1.0)
	var incremento: float = alvo - aplicado
	if tempo_decorrido >= duracao and is_zero_approx(incremento):
		fase = Fase.RETORNO
	return incremento


## Confirma quanto do incremento foi efetivamente aplicado após o clamp da pista.
func confirmar_aplicado(incremento_efetivo: float) -> void:
	aplicado += incremento_efetivo
	if fase == Fase.IDA and tempo_decorrido >= duracao:
		# Travou no limite da pista no fim da IDA: mesmo assim, volta à origem.
		fase = Fase.RETORNO


## Encerra o deslocamento: NPC de volta à faixa de origem (FR-021).
func encerrar() -> void:
	fase = Fase.INATIVA
	direcao = 0
	magnitude = 0.0
	duracao = 0.0
	duracao_retorno = 1.0
	tempo_decorrido = 0.0
	aplicado = 0.0
	x_origem = 0.0


func resetar() -> void:
	encerrar()
