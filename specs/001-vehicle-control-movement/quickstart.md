# Quickstart Validation Guide: Vehicle Control and Movement

**Feature**: 001-vehicle-control-movement
**Date**: 2026-09-18

## Prerequisites

- Godot Engine 4.x instalado
- Assets em `assets/player/azul/azul.png` e `assets/player/vermelho/vermelho.png`
- Projeto aberto no Godot Editor

## Setup

1. Abrir projeto no Godot Editor
2. Verificar que `game_config.gd` está como autoload (Project → Project Settings → AutoLoad)
3. Verificar Input Map configurado (Project → Project Settings → Input Map):
   - `accelerate` → W, ↑
   - `brake` → S, ↓
   - `move_left` → A, ←
   - `move_right` → D, →

## Validation Scenarios

### Scenario 1: Controle Básico (US1)

**Objetivo**: Verificar que veículo responde aos 4 controles

**Passos**:
1. Iniciar jogo (F5)
2. Navegar MENU → READY → PLAYING
3. Pressionar W/↑ por 2 segundos
4. Verificar: veículo move-se para cima (velocidade aumenta)
5. Soltar W/↑
6. Verificar: veículo desacelera gradualmente (inércia)
7. Pressionar S/↓
8. Verificar: veículo freia e volta parabaixo

**Expected**: Veículo responde progressivamente aos controles

---

### Scenario 2: Movimento Lateral (US1)

**Objetivo**: Verificar movimento esquerda/direita

**Passos**:
1. Em PLAYING, pressionar A/←
2. Verificar: veículo move-se para esquerda dentro dos limites
3. Soltar A/←, pressionar D/→
4. Verificar: veículo move-se para direita dentro dos limites

**Expected**: Movimento lateral suave, respeita limites

---

### Scenario 3: Posição Vertical vs Velocidade (US2)

**Objetivo**: Verificar relação velocidade/posição

**Passos**:
1. Iniciar com velocidade 0
2. Verificar: posição Y ≈ 95% da tela (vertical_position_max)
3. Acelerar até max_speed
4. Verificar: posição Y ≈ 60% da tela (vertical_position_min)
5. Desacelerar completamente
6. Verificar: posição retorna para ~95%

**Expected**: Posição interpola suavemente conforme velocidade

---

### Scenario 4: Movimento Diagonal (US3)

**Objetivo**: Verificar combinação de eixos

**Passos**:
1. Pressionar W/↑ (acelerar) + A/← (esquerda) simultaneamente
2. Verificar: veículo desloca-se diagonalmente para cima/esquerda
3. Soltar A/←, pressionar D/→
4. Verificar: veículo desloca-se diagonalmente para cima/direita

**Expected**: Trajetória diagonal natural, sem aumento artificial de velocidade

---

### Scenario 5: Limites da Estrada (US4)

**Objetivo**: Verificar que veículo não sai da pista

**Passos**:
1. Mover veículo para limite esquerdo (A/← contínuo)
2. Verificar: veículo para em road_left_boundary, não ultrapassa
3. Mover para limite direito (D/→ contínuo)
4. Verificar: veículo para em road_right_boundary, não ultrapassa

**Expected**: Veículo sempre dentro dos limites, sem teleportação

---

### Scenario 5B: Posição Vertical e Margens (FR-022, FR-027)

**Objetivo**: Verificar posicionamento vertical correto do veículo

**Passos**:
1. Iniciar jogo (F5)
2. Verificar: veículo inicia na base da tela (y ≈ 456px, margem de 24px)
3. Acelerar ao máximo (W/↑ por ~2.5s)
4. Verificar: veículo sobe até y ≈ 288px (60% da tela, 1 carro abaixo do meio)
5. Soltar acelerador e aguardar inércia
6. Verificar: veículo desce até a base (y ≈ 456px)
7. Verificar: base do sprite alinhada com margem de segurança (não cortada)

**Expected**: Veículo mantém-se na faixa vertical 60%-95% da tela, com margem para sprite completo

---

### Scenario 6: Troca de Sprite (US5)

**Objetivo**: Verificar independência sprite/física

**Passos**:
1. Iniciar jogo com sprite azul (padrão)
2. Testar aceleração, frenagem, movimento lateral
3. Alterar sprite para vermelho (via GameConfig ou editor)
4. Repetir mesmos testes de movimento

**Expected**: Comportamento idêntico independente do sprite

---

### Scenario 7: Fallback de Asset (Edge Case)

**Objetivo**: Verificar comportamento com asset ausente

**Passos**:
1. Renomear/mover `assets/player/azul/azul.png`
2. Iniciar jogo
3. Verificar: log de erro no console
4. Verificar: placeholder visual (quadrado colorido) exibido
5. Verificar: física e controles funcionam normalmente

**Expected**: Jogo continua funcionando com placeholder

---

### Scenario 8: Fluxo de Estados (FR-023)

**Objetivo**: Verificar transições MENU→READY→PLAYING

**Passos**:
1. Iniciar jogo (F5)
2. Verificar: tela MENU exibida
3. Pressionar Enter/espaço para iniciar
4. Verificar: transição para READY (countdown ou mensagem)
5. Verificar: transição automática para PLAYING

**Expected**: Fluxo MENU→READY→PLAYING funciona corretamente

---

## Automated Tests

```bash
# Executar testes unitários (se GdUnit4 configurado)
# No Godot Editor: Scene → Run Tests
# Ou via CLI:
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
```

### Testes Obrigatórios

1. `test_speed_increases_with_acceleration`
2. `test_speed_decreases_with_brake`
3. `test_brake_overrides_accelerate`
4. `test_natural_deceleration`
5. `test_speed_clamped_at_max`
6. `test_speed_clamped_at_zero`
7. `test_lateral_movement_independent`
8. `test_diagonal_movement`
9. `test_boundary_collision_left`
10. `test_boundary_collision_right`
11. `test_reset`

## Success Criteria Validation

| SC | Description | How to Validate |
|----|-------------|-----------------|
| SC-001 | Veículo visível em < 2s | Cronometrar tempo até sprite aparecer |
| SC-002 | max_speed em ~2.5s | Cronometrar aceleração de 0 a 100 |
| SC-003 | Parada em ~6.7s | Cronometrar desaceleração de 100 a 0 |
| SC-004 | Freio em ~1.4s | Cronometrar frenagem de 100 a 0 |
| SC-005 | Largura total em tempo consistente | Cronometrar movimento lateral completo |
| SC-006 | Posição Y: inicia em 95%, acelera até 60% | Medir posição Y em diferentes velocidades |
| SC-007 | 100% boundary test | Testar limites esquerdo/direito |
| SC-008 | Diagonal sem aumento velocidade | Comparar velocidade total vs componentes |
| SC-009 | Troca sprite inaltera física | Comparar tempos com azul vs vermelho |
| SC-010 | 100% CA passam | Executar todos os acceptance scenarios |
| SC-011 | Testes automatizados passam | Executar GdUnit4 tests |
| SC-012 | Zero erros em 5 min | Monitorar console por 5 minutos |
| SC-013 | 60 FPS estável | Monitorar FPS durante gameplay |
