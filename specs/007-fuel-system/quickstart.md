# Quickstart — Validação da SPEC-007 (Sistema de Combustível)

**Data**: 2026-10-09 | **Objetivo**: rodar a suíte automatizada e validar manualmente os critérios de aceitação que exigem gameplay.

## 1. Pré-requisitos

```bash
# Binário do engine (versão do projeto)
export GODOT_BIN=$HOME/Downloads/_installers/Godot_v4.7.2-stable_linux.x86_64

# Imports dos assets: abrir o editor Godot UMA vez por máquina (arquivos *.import não vão para o git)
"$GODOT_BIN" -e --path . --quit
```

## 2. Suíte automatizada (SC-002/SC-003/SC-004 + testes 1–27)

```bash
GODOT_BIN=$GODOT_BIN bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
```

**Esperado**: exit **101** = verde. Baseline atual: **35 suítes / 214 casos** → com a SPEC-007: **41 suítes** (35 + 6 abaixo), regressão zero nas SPECs 001–006 (SC-017).

### Suítes novas e mapeamento

| Suíte | User story | Testes (texto) | SC principais |
|---|---|---|---|
| `fuel_consumption_test.gd` | US1 | T1–T10 | SC-001, SC-002, SC-003, SC-004, SC-005, SC-006, SC-007 |
| `fuel_depletion_test.gd` | US3 | T11–T14 | SC-007, SC-013 |
| `fuel_collision_penalty_test.gd` | US2 | T16–T25 | SC-008, SC-009, SC-010, SC-011, SC-012 |
| `fuel_low_event_test.gd` | US4 | T15 | SC-014 |
| `fuel_hud_test.gd` | US4 | T26 | SC-014, SC-015 |
| `fuel_config_test.gd` | US5 | T27 | SC-016 |

Roda só uma suíte durante o desenvolvimento:

```bash
GODOT_BIN=$GODOT_BIN bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c \
  -a res://tests/unit/fuel_consumption_test.gd
```

## 3. Validação manual (SC-017, SC-018, SC-019 + critérios que o headless não cobre)

Abrir a cena principal e jogar:

```bash
"$GODOT_BIN" -e --path . res://src/game/gameplay.tscn   # F5 / Play
```

| # | Passo | Esperado |
|---|---|---|
| 1 | Iniciar corrida (menu → Enter) | Barra de combustível cheia no canto superior esquerdo; **nenhuma** mensagem de baixo |
| 2 | Dirigir em velocidade alta vs. baixa | A barra drena visivelmente mais rápido em alta velocidade; no **repouso** ela não se move (semente `idle = 0.0`). **Cronometragem do benchmark FR-028 (SC-018)**: tanque cheio em velocidade máxima constante deve esgotar entre **45 e 90 s** — se fora da faixa, ajustar somente `GameConfig` (T018) |
| 3 | Parar o veículo 2 s, depois andar | Consumo pausa no zero de velocidade e retoma ao sair do lugar (SC-006) |
| 4 | Deixar drenar até ≤ 20% | Preenchimento muda de cor e o rótulo **"BAIXO"** aparece e **permanece** enquanto durar a condição (Clarificação B) |
| 5 | Trocar ambiente p/ FOREST/ICE no inspector (`GameConfig.current_environment_id`) e colidir com NPC | Perda imediata de um valor fixo **entre 2% e 10% da capacidade**, **idêntico** nos dois ambientes (SC-019); acumula colisão após colisão (SC-009) |
| 6 | Repetir em PLAINS/DESERT | Colisão **não** mexe o combustível (testes 16/17) — dano só via dirigibilidade, como na SPEC-005 |
| 7 | Colidir 2× em sequência rápida | **Um** desconto por colisão real (o cooldown da 005 separa colisões legítimas) |
| 8 | Esgotar o tanque | Barra em 0, nunca negativa; **uma única** ocorrência de "esgotado" (sem flicker); após isso o veículo **continua dirigindo normalmente** — sem Game Over nesta spec (FR-030/FR-033, fronteira R11) |
| 9 | Pausar (Esc) e retomar | O tanque **não** recarrega (reset só em READY→PLAYING, R4) |
| 10 | Trocar `fuel_capacity`/`collision_fuel_penalty` no inspector e reiniciar | Comportamento muda sem tocar em código (FR-026, T27); o rótulo "BAIXO" respeita `fuel_low_label` |

## 4. Regressão

- Suíte completa (item 2) verde ⇒ SPECs 001–006 intactas.
- Sem alterações em `VehicleController`, `Road`, `TrafficManager`, `CollisionSystem` — a checagem de regressão é a própria suíte existente.
- Pendências conhecidas fora deste escopo (AGENTS.md): SPEC-006 `/speckit.analyze`, FR-046, sondas A/B/D, aceite T037/T050–T052.
