class_name DecorationElement
extends Sprite2D

## Elemento decorativo em cena: um sprite posicionado numa lateral da estrada,
## numa das profundidades, que acompanha o deslocamento e é reciclado.
##
## NÃO expõe área de colisão e NÃO participa de nenhum sistema de física:
## FR-049 exclui decoração de colisão de forma definitiva, inclusive entre
## decorações.

enum Side { LEFT, RIGHT }

## Elemento da biblioteca ao qual pertence.
var data: DecorationData = null

## Lado da estrada (FR-032).
var side: int = Side.LEFT

## Profundidade, da mais próxima (0) à mais distante (FR-034).
var depth_index: int = 0

## Participa do deslocamento e do recycle.
var active: bool = false

## Verdadeiro depois que o elemento já teve pixel visível na tela (FR-043).
## Começa falso porque o elemento nasce acima do topo (FR-041, D3): é o que
## impede que a reciclagem por borda o descarte no quadro seguinte ao birth.
var ja_visto: bool = false

## Limite lateral vigente no quadro anterior, base da interpolação de R8.
var previous_lane_limit: float = 0.0

## Progresso 0.0..1.0 do reposicionamento lateral em andamento (R8).
var reposition_lerp: float = 0.0

## Textura memorizada para não recarregar por recycle.
var _textura_atual: Texture2D = null


func _ready() -> void:
	# Pixel art: sem interpolação (FR-047).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


## Ativa e posiciona o elemento fora da área visível e já fora da estrada
## (FR-041, FR-042, D3).
func activate(p_data: DecorationData, p_side: int, p_depth_index: int, y: float) -> void:
	data = p_data
	side = p_side
	depth_index = p_depth_index
	active = true
	ja_visto = false

	_carregar_textura()

	# Âncora base-centro (research.md R5): a base do elemento fica sobre a linha
	# da profundidade, e o crescimento para cima não invade a profundidade vizinha.
	update_anchor()

	position.y = y
	previous_lane_limit = 0.0
	reposition_lerp = 0.0
	visible = true


## Marca inativo e devolve ao pool (FR-043, D4).
func deactivate() -> void:
	active = false
	data = null
	visible = false
	ja_visto = false


## Reposiciona a âncora base-centro (R5).
## Reaplicada quando a textura muda, porque a altura define o deslocamento.
func update_anchor() -> void:
	var altura: float = get_dimensao().y
	centered = false
	offset = Vector2(-get_dimensao().x * 0.5, altura)


## Lado da estrada (contrato §7).
func get_side() -> int:
	return side


## Profundidade atribuída (contrato §7).
func get_depth_index() -> int:
	return depth_index


## Desloca pela velocidade derivada da estrada e reposiciona lateralmente ao
## estreitar (FR-039, FR-051, FR-052).
func update_scroll(delta: float, road_speed: float, bounds: Dictionary) -> void:
	if not active:
		return

	# A estrada é a referência de 100% (FR-058); a decoração tem multiplicador
	# próprio (FR-039).
	position.y += road_speed * GameConfig.decoration_speed_multiplier * delta

	_reposicionar_lateral(delta, bounds)


## Reposicionamento lateral CONTÍNUO por `lerpf` durante o estreitamento
## (FR-051, research.md R8).
##
## Interpola do limite antigo para o novo com o MESMO fator `t` da transição da
## estrada. Reposicionar de uma vez para o limite novo produziria salto visível,
## que FR-051 proíbe.
func _reposicionar_lateral(delta: float, bounds: Dictionary) -> void:
	var limite_novo: float = _limite_da_profundidade(bounds)

	if previous_lane_limit <= 0.0:
		# Primeiro quadro: já nasce no limite vigente (D2).
		position.x = lerpf(position.x, limite_novo, 1.0)
		previous_lane_limit = limite_novo
		reposition_lerp = 1.0
		return

	var reducao: float = previous_lane_limit - limite_novo
	if absf(reducao) <= 0.001:
		# Largura estável: nada a fazer, mas o referencial é atualizado.
		previous_lane_limit = limite_novo
		reposition_lerp = 0.0
		return

	# `t` é o progresso da transição. Usa-se a própria redução como medida: Road já
	# interpolou o limite, e o elemento precisa acompanhar o movimento da borda.
	var passo: float = clampf(absf(reducao) / maxf(1.0, GameConfig.decoration_depth_spacing), 0.0, 1.0)
	reposition_lerp = minf(reposition_lerp + passo, 1.0)

	# `lerpf` do limite antigo para o novo: o deslocamento por quadro é
	# proporcional ao que falta, e decai ao se aproximar — sem salto.
	position.x = lerpf(previous_lane_limit, limite_novo, reposition_lerp)

	# Nunca invade a área trafegável nem a margem de segurança (D2, SC-021).
	position.x = _limitar_contra_a_estrada(position.x, bounds)

	previous_lane_limit = limite_novo


## Distância do centro do elemento até a borda da área trafegável, no seu lado,
## já com a margem de segurança e a meia-largura do asset.
func _limite_da_profundidade(bounds: Dictionary) -> float:
	var esquerda: float = bounds.get("left", GameConfig.road_left_boundary)
	var direita: float = bounds.get("right", GameConfig.road_right_boundary)
	var margem: float = GameConfig.decoration_safety_margin
	var meia: float = get_dimensao().x * 0.5
	var afastamento: float = margem + meia + float(depth_index) * GameConfig.decoration_depth_spacing

	return esquerda - afastamento if side == Side.LEFT else direita + afastamento


## Impede que o elemento entre na área trafegável + margem (D2, FR-033).
func _limitar_contra_a_estrada(x: float, bounds: Dictionary) -> float:
	var esquerda: float = bounds.get("left", GameConfig.road_left_boundary)
	var direita: float = bounds.get("right", GameConfig.road_right_boundary)
	var margem: float = GameConfig.decoration_safety_margin
	var meia: float = get_dimensao().x * 0.5

	if side == Side.LEFT:
		return minf(x, esquerda - margem - meia)
	return maxf(x, direita + margem + meia)


## Verdadeiro quando nenhum pixel do elemento está na área visível (FR-043, D4).
##
## D4 exige reciclagem por QUALQUER borda, mas só depois que o elemento passou
## pela tela. Um elemento nasce acima do topo (FR-041, D3), então a checagem da
## borda superior precisa de `ja_visto` para não descartar todo elemento no
## quadro seguinte ao do birth — o que produzia um flick de um único quadro.
func is_fully_outside(view_rect: Rect2) -> bool:
	var dimensoes: Vector2 = get_dimensao()
	if dimensoes == Vector2.ZERO:
		return true

	var esquerda: float = position.x - dimensoes.x * 0.5
	var direita: float = position.x + dimensoes.x * 0.5
	var topo: float = position.y - dimensoes.y
	var base: float = position.y

	if direita < view_rect.position.x or esquerda > view_rect.end.x:
		return true

	if base >= view_rect.position.y and topo <= view_rect.end.y:
		# Há pixel visível: o elemento está na tela.
		ja_visto = true
		return false

	if not ja_visto:
		# Nasceu acima do topo (FR-041) e ainda não entrou: permanece ativo,
		# aguardando descer até a área visível.
		return base > view_rect.end.y

	return true


## Dimensão real em uso: a do asset se já medida, senão a da textura carregada.
func get_dimensao() -> Vector2:
	if data != null and data.size != Vector2.ZERO:
		return data.size
	if texture != null:
		return Vector2(texture.get_width(), texture.get_height())
	return Vector2.ZERO


## Verdadeiro enquanto o elemento está em cena.
func is_active() -> bool:
	return active


func _carregar_textura() -> void:
	if data == null:
		return

	if not data.texture_path.is_empty() and ResourceLoader.exists(data.texture_path):
		var t: Texture2D = load(data.texture_path)
		texture = t
		_textura_atual = t
		if data.size == Vector2.ZERO:
			data.size = Vector2(t.get_width(), t.get_height())
		# FR-046: o asset já vem reescalonado do asset; decoration_scale é aplicado
		# pelo manager sobre o elemento, não pela preparação.
		scale = Vector2.ONE * GameConfig.decoration_scale
		return

	# Asset declarado ausente: o elemento é ignorado, mas o jogo continua
	# jogável (caso de borda "Biblioteca de decoração vazia ou asset ausente").
	push_warning("DecorationElement: asset ausente '%s'" % data.texture_path)
	data = null
	active = false