# Quickstart Validation Guide: Road Scrolling System

**Feature**: 002-road-scrolling-system
**Date**: 2026-09-18

## Prerequisites

- Godot Engine 4.x instalado
- Assets em `assets/estrada/estrada_2_vias.png`, `estrada_expansao_4_vias.png`, `estrada_reducao_2_vias.png`
- SPEC-001 implementado e funcionando
- Projeto aberto no Godot Editor

## Setup

1. Abrir projeto no Godot Editor
2. Verificar que `game_config.gd` está como autoload
3. Verificar que `estrada_2_vias.png` existe em `assets/estrada/`
4. Verificar Input Map configurado (WASD/setas)

## Validation Scenarios

### Scenario 1: Estrada Parada (CA-06)

**Objetivo**: Verificar que estrada fica parada com velocidade zero

**Passos**:
1. Iniciar jogo (F5)
2. Navegar MENU → READY → PLAYING
3. Não pressionar nenhum botão
4. Verificar: estrada visível e parada
5. Verificar: sem scrolling occur

**Expected**: Estrada permanece estática enquanto velocidade = 0

---

### Scenario 2: Scrolling ao Acelerar (CA-03, CA-04)

**Objetivo**: Verificar que estrada rola ao acelerar

**Passos**:
1. Em PLAYING, pressionar W/↑ (acelerar)
2. Verificar: estrada começa a se mover para baixo
3. Continuar acelerando
4. Verificar: velocidade de scrolling aumenta
5. Atingir velocidade máxima
6. Verificar: scrolling estável e contínuo

**Expected**: Scrolling proporcional à velocidade, sem mudanças bruscas

---

### Scenario 3: Frenagem (CA-05)

**Objetivo**: Verificar que scrolling reduz ao frear

**Passos**:
1. Acelerar até velocidade máxima
2. Pressionar S/↓ (frear)
3. Verificar: velocidade de scrolling diminui
4. Continuar freando
5. Verificar: scrolling para completamente quando velocidade = 0

**Expected**: Scrolling acompanha frenagem naturalmente

---

### Scenario 4: Inércia (CA-07)

**Objetivo**: Verificar desaceleração natural do scrolling

**Passos**:
1. Acelerar até velocidade alta
2. Soltar acelerador (não frear)
3. Verificar: scrolling desacelera gradualmente
4. Aguardar parada completa
5. Verificar: estrada para suavemente

**Expected**: Scrolling preserva sensação de inércia

---

### Scenario 5: Loop de Segmentos (CA-08, CA-09)

**Objetivo**: Verificar reciclagem contínua de segmentos

**Passos**:
1. Acelerar até velocidade constante
2. Observar por 30 segundos
3. Verificar: sem gaps ou cortes visíveis
4. Verificar: transições entre segmentos são suaves
5. Verificar: estrada sempre cobre a tela

**Expected**: Loop perfeito sem interrupções visuais

---

### Scenario 6: Movimento Lateral Durante Scrolling (CA-14, CA-15)

**Objetivo**: Verificar que movimento lateral continua funcionando

**Passos**:
1. Acelerar para manter scrolling
2. Pressionar A/← (mover esquerda)
3. Verificar: carro se move para esquerda
4. Pressionar D/→ (mover direita)
5. Verificar: carro se move para direita
6. Testar combinação diagonal (W/↑ + A/←)
7. Verificar: movimento diagonal funciona

**Expected**: Controles laterais funcionam normalmente durante scrolling

---

### Scenario 7: Limites da Estrada (CA-14)

**Objetivo**: Verificar que limites laterais são mantidos

**Passos**:
1. Acelerar para manter scrolling
2. Mover para limite esquerdo (A/↓ contínuo)
3. Verificar: carro para em road_left_boundary
4. Mover para limite direito (D/→ contínuo)
5. Verificar: carro para em road_right_boundary

**Expected**: Limites laterais respeitados durante scrolling

---

### Scenario 8: Segmentos de Expansão (CA-10)

**Objetivo**: Verificar renderização de expansão com limites trapezodais

**Passos**:
1. Inserir segmento de expansão na sequência (via editor ou código)
2. Acelerar para manter scrolling
3. Verificar: asset de expansão renderiza corretamente
4. Verificar: transição visual é suave
5. Verificar: limites laterais Expansão gradualmente de narrow (144px) para wide (176px)
6. Verificar: carro NÃO perde velocidade vertical durante expansão
7. Verificar: carro pode se mover lateralmente conforme limites expandem

**Expected**: Expansão renderiza com interpolação trapezoidal, sem perda de velocidade

---

### Scenario 9: Segmentos de Redução (CA-11)

**Objetivo**: Verificar renderização de redução com limites trapezodais

**Passos**:
1. Inserir segmento de redução na sequência (via editor ou código)
2. Acelerar para manter scrolling
3. Verificar: asset de redução renderiza corretamente
4. Verificar: transição visual é suave
5. Verificar: limites laterais estreitam gradualmente de wide (176px) para narrow (144px)
6. Verificar: carro NÃO é jogado para pista interna abruptamente
7. Verificar: carro acompanha redução gradual dos limites conforme segmento passa

**Expected**: Redução renderiza com interpolação trapezoidal, transição gradual sem empurrão

---

### Scenario 10: Fallback de Asset (CA-13)

**Objetivo**: Verificar comportamento com asset ausente

**Passos**:
1. Renomear `estrada_2_vias.png` temporariamente
2. Iniciar jogo
3. Verificar: warning no console
4. Verificar: placeholder visual exibido
5. Verificar: jogo continua funcionando
6. Restaurar asset original

**Expected**: Jogo usa placeholder e continua funcionando

---

## Automated Tests

```bash
# Executar testes unitários (se GdUnit4 configurado)
# No Godot Editor: Scene → Run Tests
# Ou via CLI:
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
```

### Testes Obrigatórios

1. `test_road_scrolling_speed_proportional`
2. `test_road_stops_at_zero_speed`
3. `test_road_loop_no_gaps`
4. `test_road_boundary_left`
5. `test_road_boundary_right`
6. `test_road_lateral_movement_during_scroll`
7. `test_road_diagonal_movement_during_scroll`
8. `test_segment_recycling`
9. `test_pool_initialization`
10. `test_fallback_placeholder`

## Success Criteria Validation

| SC | Description | How to Validate |
|----|-------------|-----------------|
| SC-001 | Scrolling inicia em < 0.5s | Cronometrar tempo até scrolling começar |
| SC-002 | Scrolling proporcional (correlação > 0.95) | Medir velocidade de scrolling vs velocidade do jogador |
| SC-003 | Loop sem gaps por 5 min | Observar por 5 minutos sem interrupções |
| SC-004 | Movimento lateral sem lag | Testar inputs laterais durante scrolling |
| SC-005 | Desaceleração natural | Testar inércia e verificar suavidade |
| SC-006 | Transições renderizam corretamente | Inserir segmentos de expansão/redução |
| SC-007 | Zero erros em 5 min | Monitorar console |
| SC-008 | 60 FPS estável | Monitorar FPS durante gameplay |
