# Data Model: Sistema de Dificuldade e Balanceamento (SPEC-009)

**Data**: 2026-10-12 | **Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

## 1. Visão geral

Três entidades novas (itens da spec §Key Entities) e nenhuma mudança de forma nas entidades existentes — os sistemas das SPEC-001–008 ganham apenas campos de fator (research R1/R7/R11).

```text
GameConfig (autoload, dados)
├── difficulty_modes ──────────────┐
├── environment_sequence           │  leitura
├── difficulty_cycle_bonus_increment
└── ui_strings (rótulos novos)     │
                                   ▼
                     DifficultyManager (sessão/corrida)
                                   ▲ injetado por referência
        ┌──────────────────────────┼──────────────────────────┐
        ▼                          ▼                          ▼
 VehicleController         TrafficManager/FuelSystem/    UIManager (rótulo)
 (fator_dificuldade)       FuelCanManager (fatores)

 RaceProgression (sessão) ──fator_ciclo──▶ DifficultyManager
        ▲ registra_vitoria/zerar_ciclo
        │
 GameplayManager (_avaliar_transicoes / handlers de fim)
```

## 2. Modo de Jogo (dados — `GameConfig.difficulty_modes`)

Cada entrada: `id: String` → `Dictionary` com 5 multiplicadores (FR-001/FR-002):

| Campo | Tipo | Relaxante | Normal | Desafio |
|-------|------|----------:|-------:|--------:|
| `velocidade` | float | 1,0 | 3,0 | 4,0 |
| `densidade` | float | 0,70 | 1,00 | 1,20 |
| `frequencia_galoes` | float | 1,50 | 1,00 | 0,65 |
| `penalidade_colisao` | float | 0,50 | 1,00 | 1,50 |
| `distancia_galoes` | float | 0,80 | 1,00 | 1,20 |

**Validações** (implementadas no `DifficultyManager`, fallback seguro):
- `definir_modo(id)` com chave ausente/nula → `difficulty_default_mode` ("normal") + `push_warning`.
- Fator ausente em uma entrada (`get`) → 1,0 naquele campo (modo parcialmente inválido não quebra a corrida).
- Fatores sempre > 0 (config de calibração; testes cobrem o caminho feliz e o fallback).

## 3. Configuração Efetiva da Corrida (derivada — `DifficultyManager`)

Estado em memória, válido de `_on_start_race` ao fim da corrida (FR-006):

| Campo | Origem | Fórmula |
|-------|--------|---------|
| `modo` | seleção do menu | id do modo vigente (default "normal") |
| `fator_ciclo` | `RaceProgression.fator_ciclo()` | `1 + difficulty_cycle_bonus_increment × ciclos_concluidos` |
| `fator_velocidade_total()` | modo × ciclo | `difficulty_modes[modo].velocidade × fator_ciclo` |
| `efetiva(base)` | R1 | `base × fator_velocidade_total()` |
| `fator_densidade()` | modo | `difficulty_modes[modo].densidade` |
| `fator_frequencia_galoes()` | modo | `difficulty_modes[modo].frequencia_galoes` |
| `fator_penalidade_colisao()` | modo | `difficulty_modes[modo].penalidade_colisao` |
| `fator_distancia_galoes()` | modo | `difficulty_modes[modo].distancia_galoes` |

**Invariantes testáveis**:
- Relaxante no ciclo 1 → todos os fatores efetivos = 1,0 (regressão zero, R12).
- Velocidade efetiva máxima: jogador 125×fator / NPCs 90/90/100/120×fator km/h (SC-001/SC-002).
- `fator_ciclo` só muda entre corridas, nunca durante (FR-006).
- Consumo por km constante: `_taxa_consumo` escala pelo mesmo fator (R3, SC-008).
- Penalidade efetiva = `collision_fuel_penalty[ambiente] × fator_penalidade_colisao` (SC-007).

**Consumidores e pontos de aplicação**:

| Consumidor | Campo/aplicação | Ponto |
|------------|-----------------|-------|
| `VehicleController` | `fator_dificuldade` (float) | teto/aceleração/frenagem/decel; razão da posição vertical |
| `TrafficManager` | referência `dificuldade` | densidade-alvo × fator; semeia fator nos nascimentos |
| `TrafficVehicle` | `fator_dificuldade` (float) | `get_speed() = category.max_speed × fator` |
| `FuelSystem` | `fator_velocidade`, `fator_penalidade_colisao` | `_taxa_consumo`; `on_player_collision` |
| `FuelCanManager` | referência `dificuldade` | taxa × fator_freq; intervalo × fator_dist |
| `UIManager` | rótulo do modo | linha "Modo" do menu (exibição) |

## 4. Progresso da Sessão (`RaceProgression`)

| Campo | Tipo | Inicial | Regra |
|-------|------|---------|-------|
| `posicao` | int | 0 | índice em `GameConfig.environment_sequence`; avança `(pos+1) % 4` na vitória; derrota → 0 |
| `vitorias_ciclo` | int | 0 | +1 por vitória; ao atingir 4 → zera e `ciclos_concluidos++` |
| `ciclos_concluidos` | int | 0 | só cresce; nunca é zerado em sessão (FR-023) |

| Operação | Efeitos | Gatilho |
|----------|---------|---------|
| `ambiente_atual()` | `environment_sequence[posicao]` (fallback PLAINS) | início de corrida, "Continuar próxima fase" |
| `registra_vitoria()` | `vitorias+1`; se `== 4`: `ciclos+1`, `vitorias=0`; `posicao=(pos+1)%4` | vitória, antes de `game_state.victory()` |
| `zerar_ciclo_por_derrota()` | `posicao=0`, `vitorias=0`; ciclos preservados | derrota, antes de `game_state.game_over()` |
| `fator_ciclo()` | `1 + 0,002 × ciclos` | refresh por corrida no `_on_start_race` |

**Transição de ambiente**: escrita em `GameConfig.current_environment_id` + propagação existente por quadro (fundo/decoração) — research R9. **Nunca persistido** em disco (FR-023).

## 5. Entidades existentes (intocadas em forma)

| Entidade | Mudança | Onde |
|----------|---------|------|
| `GameConfig` | +bloco `## Dificuldade e Progressão (SPEC-009)` | dados dos modos, sequência, incremento, rótulos |
| `VehicleController` | +`fator_dificuldade: float = 1.0` | cálculo vertical (R1/R2) |
| `TrafficData` | nenhuma | `max_speed` permanece a base |
| `TrafficVehicle` | +`fator_dificuldade: float = 1.0` | `get_speed()` |
| `TrafficManager` | +`dificuldade` (ref), +`fator_dificuldade` (seed) | densidade e nascimento (R5/R11) |
| `FuelSystem` | +`fator_velocidade`, +`fator_penalidade_colisao` | consumo e penalidade (R3/R7) |
| `FuelCanManager` | +`dificuldade` (ref) | geração (R6) |
| `UIManager` | +linha de modo, +sinal `continue_next_phase`, opções de fim | R10 |
| `GameState` | nenhuma | transições intactas |
| `EnvironmentManager` | nenhuma | propagação continua no GameplayManager |
