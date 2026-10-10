class_name FuelHud
extends Control

## Indicador de combustível (SPEC-007, Clarificação 2026-10-09) — somente
## OBSERVADOR: nunca escreve no FuelSystem nem em outro sistema (H5/SC-015).
## Sem polling por frame: só reage ao sinal `fuel_changed` + derivados (R7).
## Sem sons, animações ou ProgressBar — retângulos planos, escala inteira,
## sem AA (pixel-art; contrato hud_indicator.md).

## Cores expostas para os testes do contrato (não são números de balance —
## são o resultado visual das regras H2/H3).
const COR_PADRAO := Color(0.18, 0.72, 0.31)
const COR_BAIXO := Color(0.85, 0.2, 0.15)

@onready var _fundo: ColorRect = $Fundo
@onready var _preenchimento: ColorRect = $Preenchimento
@onready var _rotulo: Label = $Rotulo

## Instância observada — nunca substituída por escrita externa.
var _fuel_system: FuelSystem = null


## Conecta `fuel_changed` (e faz o sync inicial). Chamado UMA vez pelo
## GameplayManager._ready; re-chamadas não duplicam conexões (H4).
func setup(fuel_system: FuelSystem) -> void:
	if _fuel_system != null and _fuel_system.fuel_changed.is_connected(_on_fuel_changed):
		_fuel_system.fuel_changed.disconnect(_on_fuel_changed)
	_fuel_system = fuel_system
	if _fuel_system == null:
		return
	_fuel_system.fuel_changed.connect(_on_fuel_changed)
	_on_fuel_changed(_fuel_system.get_atual(), _fuel_system.get_capacidade())


## H1 — largura = round(clamp(atual/capacidade, 0, 1) × largura do trilho);
## H2/H3 — cor + rótulo acompanham o estado derivado, com texto vindo sempre
## de GameConfig.fuel_low_label (§VI: nenhum literal fixo neste script).
func _on_fuel_changed(atual: float, capacidade: float) -> void:
	var proporcao: float = 0.0
	if capacidade > 0.0:
		proporcao = clampf(atual / capacidade, 0.0, 1.0)
	_preenchimento.size.x = roundi(proporcao * _fundo.size.x)

	var baixo: bool = _fuel_system != null and _fuel_system.esta_baixo()
	_rotulo.text = GameConfig.fuel_low_label
	_rotulo.visible = baixo
	_preenchimento.color = COR_BAIXO if baixo else COR_PADRAO
