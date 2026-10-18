# Contrato: Indicador de Combustível — HUD (SPEC-007, Clarification 2026-10-09)

**Implementador**: `src/ui/fuel_hud.gd` + nó em `src/game/gameplay.tscn`
**Papel**: **somente observador** — nunca escreve no `FuelSystem` nem em qualquer outro sistema (§Sistema de Combustível: "a UI SHOULD observar o sistema… em vez de modificar").

## Composição (cena)

```
FuelHudLayer (CanvasLayer)
└── FuelHudRoot (Control, retângulo total, mouse_filter = IGNORE)
    ├── Fundo        (ColorRect)  # trilho, canto superior esquerdo, escala inteira
    ├── Preenchimento (ColorRect) # largura = round(proporção × largura_trilho)
    └── Rótulo       (Label)      # texto = GameConfig.fuel_low_label; visível ⇔ estado baixo
```

## Interface

```gdscript
func setup(fuel_system: FuelSystem) -> void
    # Conecta fuel_changed (e estado baixo); chamado UMA vez pelo GameplayManager._ready.

func _on_fuel_changed(atual: float, capacidade: float) -> void
    # Preenchimento.size.x = round(clamp(atual/capacidade, 0, 1) × largura_trilho)
    # Atualiza cor + visibilidade do rótulo a partir de fuel_system.esta_baixo().
```

## Regras observáveis (testadas — T26)

| # | Regra |
|---|---|
| H1 | Proporção da barra **sempre** igual a `atual / capacidade` (clamp `[0,1]`) após cada `fuel_changed` |
| H2 | Enquanto `esta_baixo()` ⇒ rótulo **visível** e cor do preenchimento trocada (FR-025, Clarificação B: cor + rótulo **estático**, persistente enquanto a condição durar) |
| H3 | Estado não-baixo ⇒ rótulo oculto e cor padrão |
| H4 | `setup()` é idempotente o bastante para re-setup em reinício (conexões não duplicam) |
| H5 | O HUD **não** modifica combustível: após qualquer interação sua, `fuel_system.get_atual()` inalterado (franja do §Sistema de Combustível) |

## Proibições

- Sem sons, animações, sprites ou ícones novos (escopo do indicador — Clarificação 2026-10-09: **mínimo**);
- Sem `ProgressBar`/Theme (não há tema no projeto; pixel-art ⇒ retângulos planos, escala inteira, sem AA);
- Sem literal "BAIXO" no script — texto vem de `GameConfig.fuel_low_label` (§VI, testável por FR-026);
- Sem polling por frame: só sinal (`fuel_changed`) + derivados (R7).
