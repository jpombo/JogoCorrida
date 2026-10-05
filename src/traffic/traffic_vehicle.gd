class_name TrafficVehicle
extends Sprite2D

## Instância visual e de estado de um veículo de trânsito.
##
## O veículo NÃO detecta nem resolve colisões nesta versão (FR-026, FR-062,
## constitution v2.0.0 §Trânsito). Ele apenas expõe identificação, posição e área
## ocupada para o SPEC-005 (FR-025, R10).

enum State { ACTIVE, INACTIVE }

## Sentido de percurso na estrada (FR-002, FR-006).
## `FORWARD` = mesmo sentido do jogador. Nesta versão todos os veículos são
## FORWARD (FR-006); `OPPOSITE` existe porque FR-008 exige que a arquitetura
## admita sentido contrário no futuro, sem que este spec o gere.
enum Direction { FORWARD = 1, OPPOSITE = -1 }

## Categoria à qual pertence (FR-002).
var category: TrafficData = null

## Posição horizontal na estrada, em pixels.
var lane_position: float = 0.0

## Ciclo de vida (FR-003). Apenas duas transições existem: activate() e deactivate().
var state: int = State.INACTIVE

## Sentido de percurso do veículo (FR-002). Sempre FORWARD nesta versão (FR-006).
var direction: int = Direction.FORWARD

## Limite direito no quadro anterior, base da interpolação de R8.
var previous_right_boundary: float = 0.0

## Progresso 0.0..1.0 do reposicionamento em andamento (R8).
var reposition_lerp: float = 0.0

## Verdadeiro depois que o veículo já teve pixel visível na tela (FR-016).
## Começa falso porque o veículo nasce acima do topo (FR-013): é o que impede
## que a reciclagem por borda o descarte no quadro seguinte ao birth.
var ja_visto: bool = false

## `y` do birth, para distinguir "ainda vai descer até a tela" de "está subindo
## e já passou do ponto de criação" (FR-016 pelo topo).
var y_nascimento: float = 0.0

## Textura já carregada, memorizada para não recarregar por recycle (FR-017).
var _textura_atual: Texture2D = null

## Deslocamento de ultrapassagem do SPEC-005 (contrato consumed_apis §4).
## Aditivo e inerte por padrão: sem chamada de `apply_overtake_offset`,
## o comportamento é idêntico ao SPEC-004 (FR-033). Nunca toca a velocidade.
var overtake: NpcOvertakeState = NpcOvertakeState.new()


func _ready() -> void:
	# Pixel art: sem interpolação (FR-047, constitution §Câmera e Apresentação).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


## Ativa e posiciona o veículo fora da área visível (FR-013, I3).
func activate(p_category: TrafficData, p_lane_position: float, y: float) -> void:
	assert(p_category != null, "TrafficVehicle.activate exige uma categoria")

	category = p_category
	lane_position = p_lane_position
	state = State.ACTIVE
	reposition_lerp = 0.0
	ja_visto = false

	# FR-011: a textura vem da pasta exclusiva da categoria e a dimensão real
	# medida nela alimenta o posicionamento e a área ocupada (R10).
	carregar_textura()

	position = Vector2(lane_position, y)
	y_nascimento = y
	visible = true


## Desativa o veículo e o devolve ao pool (FR-015, FR-016, I5).
## Ocultar não basta: o I5 exige deactivate() para que o manager saiba que o
## objeto está livre.
func deactivate() -> void:
	state = State.INACTIVE
	category = null
	visible = false
	reposition_lerp = 0.0
	ja_visto = false
	overtake.resetar()


## Inicia o deslocamento lateral de ultrapassagem (SPEC-005, FR-018/FR-019).
## Somente o CollisionSystem chama, na colisão tipo 1-3. A velocidade da
## categoria permanece intocada (FR-017) e o clamp da pista é aplicado a
## cada quadro, na altura vigente (FR-020). Ajuste 6: captura o x da faixa de
## origem para o RETORNO obrigatório ao fim da ida (FR-021).
func apply_overtake_offset(p_direcao: int, p_magnitude: float, p_duracao: float) -> void:
	overtake.iniciar(
		p_direcao,
		p_magnitude,
		p_duracao,
		GameConfig.npc_overtake_return_duration,
		position.x
	)


## Verdadeiro enquanto o veículo está em cena (consumido pelo I5 e pelo SPEC-005).
func is_active() -> bool:
	return state == State.ACTIVE


## Identificador da categoria (FR-025, contrato §6).
func get_category_id() -> String:
	return category.id if category != null else ""


## Área ocupada, para o SPEC-005 (FR-025, R10).
## Nenhum sistema deste spec consome o retorno: FR-026 e FR-062 proíbem colisão
## nesta versão, e o dado existe pronto para o SPEC-005.
func get_occupied_area() -> Rect2:
	var dimensoes: Vector2 = category.size if category != null else Vector2.ZERO
	return Rect2(position - dimensoes * 0.5, dimensoes)


## Velocidade do veículo: a da categoria, constante enquanto ATIVE (FR-011, R10).
## O movimento aparente vem da diferença para o jogador, não desta velocidade.
func get_speed() -> float:
	return category.max_speed if category != null else 0.0


## Sentido de percurso (FR-002). Multiplica deslocamentos no eixo do percurso:
## +1 no sentido do jogador, -1 no contrário (reservado para spec futura — FR-006).
func get_direction() -> int:
	return direction


## Desloca pela diferença de velocidade em relação à estrada e reposiciona
## continuamente quando a faixa estreita (FR-007, FR-019, FR-021, R8).
##
## `road_speed` é a velocidade de scroll da estrada em unidades por segundo.
## O veículo sobe quando é mais lento que o jogador e desce quando é mais rápido.
##
## `dy_limite` é o teco de descida (`INF` quando não há limite) ou o piso de
## subida (`-INF`) imposto pelo gestor para nunca invadir `traffic_min_spacing`
## no veículo à frente (FR-019, SC-006). O deslocamento aparente continua o de
## FR-007 enquanto houver folga; é só o fechamento que é truncado.
func update_scroll(delta: float, road_speed: float, bounds: Dictionary, dy_limite: float) -> void:
	if state != State.ACTIVE:
		return

	var direita: float = bounds.get("right", GameConfig.road_right_boundary)

	# Velocidade relativa: (velocidade do veículo - velocidade da estrada).
	# A estrada é a referência de 100% (FR-058).
	var dy: float = -(get_speed() - road_speed) * delta
	if dy > 0.0:
		dy = minf(dy, dy_limite)
		# FR-006 / SC-003: o sentido na tela só inverte quando a diferença para
		# o jogador inverte — o espaçamento nunca joga o veículo para trás.
		dy = maxf(dy, 0.0)
	elif dy < 0.0:
		dy = maxf(dy, dy_limite)
		dy = minf(dy, 0.0)
	position.y += dy

	_reposicionar_se_estreitou(delta, bounds, direita)
	_aplicar_overtake(delta, bounds, direita)

	# O ponto de referência lateral é recalculado a cada quadro para que o
	# reposicionamento do quadro seguinte parta do limite vigente (R8).
	previous_right_boundary = direita


## Reposicionamento contínuo ao estreitamento (FR-021, R8).
##
## Interpola do limite antigo para o novo com o MESMO fator `t` da transição,
## em vez de saltar para o limite mais próximo — o salto é proibido por FR-051.
func _reposicionar_se_estreitou(delta: float, bounds: Dictionary, direita: float) -> void:
	if previous_right_boundary <= 0.0:
		# Primeiro quadro do veículo: já nasce dentro da faixa vigente (I2).
		lane_position = position.x
		return

	if direita >= previous_right_boundary - 0.001:
		# Faixa estável ou alargando: nada a fazer.
		reposition_lerp = 0.0
		return

	# `t` avança com o tempo de transição da estrada. Usa-se a largura como
	# progresso porque Road já interpolou o limite que estamos seguindo.
	var reducao: float = previous_right_boundary - direita
	var largura_antiga: float = 176.0
	reposition_lerp = minf(reposition_lerp + (reducao / largura_antiga), 1.0)
	_reaplicar_limite(direita)


## Aplica o limite vigente mantendo o veículo dentro da área trafegável (I2).
func _reaplicar_limite(direita: float) -> void:
	var esquerda: float = GameConfig.road_left_boundary
	var meia_largura: float = category.size.x * 0.5
	# Mantém a margem lateral sem permitir que o veículo saia da pista.
	var limite_esquerdo: float = esquerda + meia_largura
	var limite_direito: float = direita - meia_largura
	if limite_direito < limite_esquerdo:
		# Faixa mais estreita que o próprio veículo: centraliza.
		limite_esquerdo = (esquerda + direita) * 0.5
		limite_direito = limite_esquerdo
	lane_position = clampf(lane_position, limite_esquerdo, limite_direito)
	position.x = lane_position


## Deslocamento lateral da ultrapassagem (SPEC-005): aplica o incremento do
## quadro com clamp nos limites vigentes; sem espaço, para no limite — a
## ultrapassagem conclui assim que houver espaço (spec §Edge Cases).
## Ajuste 6: após a IDA, a fase de RETORNO leva o veículo de volta ao x da
## faixa de origem (clampado nos limites vigentes) e só então encerra — é o
## que garante que o NPC volte ao corredor da própria velocidade (FR-021).
func _aplicar_overtake(delta: float, bounds: Dictionary, direita: float) -> void:
	if not overtake.ativo():
		return

	var esquerda: float = float(bounds.get("left", GameConfig.road_left_boundary))
	var meia_largura: float = category.size.x * 0.5
	var limite_esq: float = esquerda + meia_largura
	var limite_dir: float = direita - meia_largura

	if overtake.em_retorno():
		var alvo: float = clampf(overtake.x_origem, limite_esq, limite_dir)
		var dif: float = alvo - position.x
		var passo_max: float = (
			overtake.magnitude * delta / maxf(overtake.duracao_retorno, 0.001)
		)
		var passo: float = clampf(dif, -passo_max, passo_max)
		position.x = clampf(position.x + passo, limite_esq, limite_dir)
		lane_position = position.x
		if absf(alvo - position.x) <= 0.05:
			overtake.encerrar()
		return

	var incremento: float = overtake.proximo_incremento(delta)
	if is_zero_approx(incremento):
		overtake.confirmar_aplicado(0.0)
		return
	var alvo: float = clampf(position.x + incremento, limite_esq, limite_dir)
	var efetivo: float = alvo - position.x
	position.x = alvo
	lane_position = alvo
	overtake.confirmar_aplicado(efetivo)


## Carrega a textura da pasta `assets_path` da categoria e mede a dimensão real
## do asset, registrando em `category.size` (FR-011, FR-012, R10).
##
## A pasta é a unidade de classificação: a lógica nunca compara o nome do arquivo.
## Se o asset sorteado faltar, tenta os demais da mesma categoria antes de
## desistir, e o jogo continua jogável.
func carregar_textura() -> void:
	if category == null or category.assets.is_empty():
		return

	# A dimensão é medida uma vez por categoria e reaproveitada nos recycles.
	if _textura_atual != null and category.size != Vector2.ZERO:
		texture = _textura_atual
		return

	var indice: int = randi() % category.assets.size()
	var candidato: String = category.texture_path_for(category.assets[indice])
	if _tentar_carregar(candidato):
		return

	for nome in category.assets:
		var caminho: String = category.texture_path_for(nome)
		if _tentar_carregar(caminho):
			return

	push_warning("TrafficVehicle: nenhum asset carregável na categoria '%s'" % category.id)


func _tentar_carregar(caminho: String) -> bool:
	if caminho.is_empty() or not ResourceLoader.exists(caminho):
		return false

	var t: Texture2D = load(caminho)
	if t == null:
		return false

	texture = t
	_textura_atual = t
	# A dimensão real medida é a fonte da verdade para posicionamento e área
	# ocupada — não uma configuração, e não um hitbox (R10).
	category.size = Vector2(t.get_width(), t.get_height())
	return true