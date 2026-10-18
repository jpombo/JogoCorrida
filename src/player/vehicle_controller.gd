class_name VehicleController
extends RefCounted

## Velocidade atual do veículo
var speed: float = 0.0

## Velocidade lateral atual
var lateral_speed: float = 0.0

## Fator de controle lateral vigente (SPEC-005, contrato consumed_apis §3).
## 1.0 = controle pleno; o DriftState reduz e recupera gradualmente (FR-013/014).
## Inerte por padrão: sem colisão, o comportamento é idêntico ao SPEC-001 (FR-034).
var control_factor: float = 1.0

## Tempo restante em que a aceleração é desconsiderada (ajuste 4 da SPEC-005).
## Armando na colisão; enquanto > 0, segurar "accelerate" aplica apenas a
## desaceleração natural — a frenagem continua válida. Inerte em 0.0 (FR-034).
var aceleracao_bloqueada: float = 0.0

## Bloqueio de aceleração com combustível esgotado (SPEC-008, FR-015, R5).
## Derivado POR QUADRO pelo GameplayManager a partir do valor atual do tanque
## (Clarificação: sem latch; a coleta desbloqueia no mesmo instante). Distinto
## e independente do lockout temporizado da SPEC-005. Frenagem e desaceleração
## natural continuam valendo — o carro não para instantaneamente (FR-015).
var aceleracao_bloqueada_por_combustivel: bool = false

## Fator de dificuldade da corrida (SPEC-009, R1/R2): escala teto,
## aceleração, frenagem e desaceleração natural JUNTOS, preservando as
## razões e a curva normalizada (SC-003). Lateral nunca escalado (R2).
## Default 1,0 = comportamento SPEC-001 intacto (R12); injetado por corrida
## pelo GameplayManager. `reset()` NÃO o toca — o valor da sessão permanece
## e é reafirmado na largada (contracts/difficulty_manager_api.md §4).
var fator_dificuldade: float = 1.0

## Efeito temporizado do CASCALHO (SPEC-011, FR-015/FR-016; research R5):
## limita o teto da velocidade a `max_speed × fator_dificuldade × fator` a
## cada quadro; a estabilidade opcional entra em `efeito_aderencia_cascalho`
## (config 1,0 = desligada). Inerte. A POÇA não tem mais efeito temporal —
## no aceite T032 ela virou desvio lateral de meio carro aplicado pelo
## `ObstacleManager` (FR-014 ajustado).
var efeito_velocidade_tempo: float = 0.0
var efeito_velocidade_fator: float = 1.0
var efeito_aderencia_cascalho: float = 1.0

## Delta do frame atual
var current_delta: float = 0.0

## Limites laterais atuais da estrada
var current_left_boundary: float = 248.0
var current_right_boundary: float = 392.0

## Se o veículo está em movimento
var is_moving: bool:
	get:
		return speed > 0.0

## Signals
signal speed_changed(new_speed: float)
signal position_changed(new_position: Vector2)
signal boundary_reached(side: String)

## Processar inputs e atualizar física
func _process(delta: float) -> void:
	current_delta = delta
	if aceleracao_bloqueada > 0.0:
		aceleracao_bloqueada = max(aceleracao_bloqueada - delta, 0.0)
	# SPEC-011 / FR-016: o efeito de obstáculo (cascalho) só avança enquanto o
	# processamento do jogador está ligado (PLAYING) — a pausa congela via
	# `set_process(false)` do PlayerVehicle (congelamento por construção).
	if efeito_velocidade_tempo > 0.0:
		efeito_velocidade_tempo = maxf(efeito_velocidade_tempo - delta, 0.0)
	_apply_vertical_physics(delta)
	_apply_lateral_physics(delta)
	speed_changed.emit(speed)

## Cascalho (SPEC-011, FR-015): renovação por SOBRESCRITA — colisão
## repetida durante o efeito redefine fator e duração, nunca empilha
## intensidade nem dobra o tempo (FR-016); `fator_aderencia` é a
## estabilidade opcional (1,0 = off).
func aplicar_efeito_cascalho(
	duracao: float, fator_velocidade: float, fator_aderencia: float = 1.0
) -> void:
	efeito_velocidade_tempo = maxf(duracao, 0.0)
	efeito_velocidade_fator = clampf(fator_velocidade, 0.001, 1.0)
	efeito_aderencia_cascalho = maxf(fator_aderencia, 0.001)

## Calcular física vertical (aceleração, frenagem, inércia).
## SPEC-009 / R1-R2: teto, aceleração, frenagem e desaceleração natural
## escalados pelo MESMO fator — tempo até a máxima invariante (SC-003).
func _apply_vertical_physics(delta: float) -> void:
	var fator: float = fator_dificuldade
	if (
		Input.is_action_pressed("accelerate")
		and not Input.is_action_pressed("brake")
		and aceleracao_bloqueada <= 0.0
		and not aceleracao_bloqueada_por_combustivel
	):
		speed = min(speed + GameConfig.acceleration * fator * delta, GameConfig.max_speed * fator)
	elif Input.is_action_pressed("brake"):
		speed = max(speed - GameConfig.brake_force * fator * delta, 0.0)
	else:
		speed = max(speed - GameConfig.natural_deceleration * fator * delta, 0.0)
	# SPEC-011 / FR-015: enquanto o cascalho está ativo o teto EFETIVO é
	# rebaixado e o speed é limitado a cada quadro — redução imediata e
	# perceptível; ao expirar o teto normal volta sozinho (FR-016).
	if efeito_velocidade_tempo > 0.0:
		var teto_efeito: float = (
			GameConfig.max_speed * fator * efeito_velocidade_fator
		)
		if speed > teto_efeito:
			speed = teto_efeito

## Calcular física lateral (independente do vertical).
## A resposta é multiplicada por `control_factor` (SPEC-005): durante o drift
## o jogador mantém controle parcial, nunca zero (FR-013).
## SPEC-011 / FR-014: só o CASCALHO entra como fator ADICIONAL
## multiplicativo sobre os três termos laterais (a poça não mexe em
## aderência — T032; seu efeito é o desvio em `_impacto_obstaculo`);
## o DriftState permanece intocado (research R5).
func _apply_lateral_physics(delta: float) -> void:
	var aderencia: float = _fator_aderencia_efetivo()
	var aceleracao: float = GameConfig.lateral_acceleration * control_factor * aderencia
	var teto: float = GameConfig.lateral_speed * control_factor * aderencia
	if Input.is_action_pressed("move_left"):
		lateral_speed = max(lateral_speed - aceleracao * delta, -teto)
	elif Input.is_action_pressed("move_right"):
		lateral_speed = min(lateral_speed + aceleracao * delta, teto)
	else:
		var desaceleracao: float = GameConfig.lateral_deceleration * aderencia
		if lateral_speed > 0:
			lateral_speed = max(lateral_speed - desaceleracao * delta, 0.0)
		else:
			lateral_speed = min(lateral_speed + desaceleracao * delta, 0.0)

## Fator de aderência vigente: só a estabilidade do cascalho (1,0 = off).
## A poça saiu do domínio do veículo no aceite T032 — ela desvia o carro
## via ObstacleManager sem deixar efeito residual (FR-014 ajustado; R12).
func _fator_aderencia_efetivo() -> float:
	if efeito_velocidade_tempo > 0.0:
		return efeito_aderencia_cascalho
	return 1.0

## Retornar posição Y normalizada baseada na velocidade.
## SPEC-009: a normalização usa o teto EFETIVO (max_speed × fator) — a mesma
## razão de velocidade ocupa a mesma altura em qualquer modo (SC-003).
func get_vertical_position() -> float:
	var teto: float = GameConfig.max_speed * maxf(fator_dificuldade, 0.001)
	var speed_ratio: float = clampf(speed / teto, 0.0, 1.0)
	return lerp(GameConfig.vertical_position_max, GameConfig.vertical_position_min, speed_ratio)

## Retornar direção lateral (-1.0, 0.0, ou 1.0)
func get_horizontal_direction() -> float:
	if lateral_speed < -0.1:
		return -1.0
	elif lateral_speed > 0.1:
		return 1.0
	return 0.0

## Respeitar limites da estrada (considerando metade da largura do carro)
func _clamp_position(current_x: float) -> float:
	var old_x = current_x
	var half_width = 16.0  # Metade da largura do sprite (32px)
	var min_x = current_left_boundary + half_width
	var max_x = current_right_boundary - half_width
	
	# Se o carro está fora dos novos limites, mover suavemente para dentro
	if current_x < min_x:
		current_x = min(current_x + 200.0 * current_delta, min_x)
	elif current_x > max_x:
		current_x = max(current_x - 200.0 * current_delta, max_x)
	
	if current_x != old_x:
		var side = "left" if current_x < old_x else "right"
		boundary_reached.emit(side)
	
	return current_x

## Atualizar limites da estrada (chamado quando a pista muda de tipo)
func update_boundaries(left: float, right: float) -> void:
	current_left_boundary = left
	current_right_boundary = right

## Resetar estado para valores iniciais
func reset() -> void:
	speed = 0.0
	lateral_speed = 0.0
	control_factor = 1.0
	aceleracao_bloqueada = 0.0
	aceleracao_bloqueada_por_combustivel = false
	# SPEC-011 / FR-016: o efeito de cascalho morre com a corrida.
	efeito_velocidade_tempo = 0.0
	efeito_velocidade_fator = 1.0
	efeito_aderencia_cascalho = 1.0
	current_left_boundary = GameConfig.road_left_boundary
	current_right_boundary = GameConfig.road_right_boundary
