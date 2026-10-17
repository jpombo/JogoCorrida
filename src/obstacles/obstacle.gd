class_name Obstacle
extends Node2D

## Obstáculo de pista (SPEC-011, FR-014/FR-015/FR-017): poça de água
## (48×35) ou cascalho (48×27) — sprite + retângulo de ativação PRÓPRIO,
## igual aos galões: fora de todo pipeline de colisão (research R6). Sem
## velocidade própria: só a rolagem da estrada o move. CASCALHO: ao ser
## atingido é reciclado imediatamente (o efeito vive no veículo). POÇA
## (FR-014 ajustado no aceite T032): desvia o jogador de meio carro e fica
## INERTE (estado ATINGIDO) — continua na pista até sair da tela.

enum Estado { ATIVO, ATINGIDO }

const TIPO_POCA: String = "poca"
const TIPO_CASCALHO: String = "cascalho"

## Tipo vigente — define textura, tamanho e qual efeito o manager aplica.
var tipo: String = TIPO_POCA

## Dimensão do retângulo de ativação (lida do config; = sprite — SC-008).
var tamanho: Vector2 = Vector2(48.0, 35.0)

var estado: int = Estado.ATIVO

var sprite: Sprite2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preparar()


## Constrói o visual se ainda não existir (chamado pelo manager também fora
## da árvore — testes headless instanciam sem `_ready`).
func preparar() -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	_definir_tipo(tipo)


## Troca o tipo (e por consequência textura/tamanho) — usado pelo manager
## no sortio de spawn.
func definir_tipo(novo: String) -> void:
	tipo = novo
	_definir_tipo(novo)


## Retângulo de ativação em coordenadas de mundo, centrado na posição.
func area_contato() -> Rect2:
	return Rect2(position - tamanho * 0.5, tamanho)


## Reapresenta o obstáculo na corrida: posição, visibilidade e estado.
func ativar(pos: Vector2) -> void:
	position = pos
	visible = true
	estado = Estado.ATIVO


## Devolução ao pool: oculta e rearma o estado.
func reset_para_pool() -> void:
	visible = false
	estado = Estado.ATIVO


func _definir_tipo(novo: String) -> void:
	if sprite == null:
		return
	if novo == TIPO_CASCALHO:
		tamanho = GameConfig.obstaculo_tamanho_cascalho
		_carregar_textura(GameConfig.obstaculo_cascalho_path, tamanho)
	else:
		tipo = TIPO_POCA
		tamanho = GameConfig.obstaculo_tamanho_poca
		_carregar_textura(GameConfig.obstaculo_poca_path, tamanho)


func _carregar_textura(caminho: String, fallback: Vector2) -> void:
	if ResourceLoader.exists(caminho):
		var textura = load(caminho)
		if textura != null:
			sprite.texture = textura
			tamanho = textura.get_size()
			return
	push_warning("Obstacle: textura não encontrada — placeholder %s" % caminho)
	var imagem := Image.create(int(fallback.x), int(fallback.y), false, Image.FORMAT_RGBA8)
	imagem.fill(Color(0.4, 0.55, 0.8) if tipo == TIPO_POCA else Color(0.6, 0.55, 0.4))
	sprite.texture = ImageTexture.create_from_image(imagem)
