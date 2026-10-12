class_name FuelCan
extends Node2D

## Galão de gasolina (SPEC-008, FR-019…FR-023): sprite `gasolina.png` 32×51
## (FR-021; sem redesenho) + retângulo de contato PRÓPRIO — não entra em
## nenhum sistema de colisão (research R8). Sem velocidade própria: só a
## rolagem da estrada o move (Clarificação).

enum Estado { ATIVO, COLETADO }

const TEXTURA_PADRAO: String = "res://assets/decoracao/gasolina.png"

## Estado de coleta: `COLETADO` ⇒ devolução imediata ao pool (FR-030).
var estado: int = Estado.ATIVO

## Dimensão do retângulo de contato (32×51 por padrão; lida da textura).
var tamanho: Vector2 = Vector2(32.0, 51.0)

var sprite: Sprite2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preparar()


## Constrói o visual se ainda não existir. Chamado pelo manager também fora da
## árvore de cena (testes headless instanciam sem `_ready`).
func preparar() -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	_carregar_textura()


## Retângulo de contato em coordenadas de mundo, centrado na posição — área
## própria de coleta (R8), independente de `player_hitbox_size`.
func area_contato() -> Rect2:
	return Rect2(position - tamanho * 0.5, tamanho)


## Reapresenta o galão na corrida: posição, visibilidade e estado reiniciados
## (FR-031, SC-011).
func ativar(pos: Vector2) -> void:
	position = pos
	visible = true
	estado = Estado.ATIVO


## Devolução ao pool: oculta e rearma o estado (reciclagem nunca ressuscita
## um coletado — FR-030).
func reset_para_pool() -> void:
	visible = false
	estado = Estado.ATIVO


func _carregar_textura() -> void:
	if ResourceLoader.exists(TEXTURA_PADRAO):
		var textura = load(TEXTURA_PADRAO)
		if textura != null:
			sprite.texture = textura
			tamanho = textura.get_size()
			return
	push_warning("FuelCan: textura não encontrada — placeholder 32x51")
	var imagem := Image.create(32, 51, false, Image.FORMAT_RGBA8)
	imagem.fill(Color(0.9, 0.75, 0.1))
	sprite.texture = ImageTexture.create_from_image(imagem)
