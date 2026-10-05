# Quickstart: Sistema de Colisão e Drift (SPEC-005)

Guia de validação executável da feature. Pré-requisito: imports de assets gerados (abrir o editor Godot uma vez na máquina — ver AGENTS.md).

## Setup

```bash
export GODOT_BIN=~/Downloads/_installers/Godot_v4.7.2-stable_linux.x86_64
```

## Validação 1 — suíte unitária (headless)

```bash
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
```

Esperado: todas as suítes verdes — 24 suítes, 160 casos, incluindo as 8 suítes de colisão (`collision_*_test.gd`) e as anteriores sem regressão (SC-010). O runner sai com exit 101 quando está tudo verde.

Cobertura por suíte (ver contratos em `contracts/` e entidades em `data-model.md`):

| Suíte | O que prova |
|-------|-------------|
| `collision_detection_test` | SC-001: interseção de hitbox ↔ exatamente uma colisão; sem interseção, nenhuma |
| `collision_classification_test` | FR-002–FR-005: 3 tipos, margem neutra determinística, direção do drift |
| `collision_drift_test` | FR-009–FR-015, SC-003/SC-004: perda no intervalo, fator de controle, recuperação até 100% |
| `collision_overtake_test` | FR-017–FR-021, SC-006/SC-014: NPC não perde velocidade, desloca para o lado oposto, conclui a ida e retorna à faixa de origem (ajuste 6) |
| `collision_cooldown_test` | FR-026–FR-028, SC-005: uma penalização por sobreposição; par distinto colide normalmente |
| `collision_event_test` | FR-029/FR-030, SC-008: evento com os 6 dados; zero eventos sob cooldown |
| `collision_hitbox_test` | FR-006–FR-008, SC-009: troca de sprite não altera resultado |
| `collision_accel_lockout_test` | FR-035/FR-036, SC-013 (ajuste 4): aceleração desconsiderada na janela pós-colisão, frenagem válida, inerte sem colisão |

> **Ajustes pós-implementação (2026-10-05)**: os ajustes 1–3 e 5 (separação no nascimento, velocidades por corredor, densidade mínima e travamento de velocidade entre categorias) pertencem ao SPEC-004 e têm suítes próprias em `tests/unit/` — `test_traffic_separation.gd`, `test_traffic_density.gd` e `test_traffic_speed_ordering.gd` — ver `specs/004-traffic-and-decoration/quickstart.md`. O ajuste 6 (retorno do NPC à faixa após a ultrapassagem) é desta spec e está coberto em `collision_overtake_test.gd`.

## Validação 2 — cenários jogáveis (aceite manual)

Rodar a cena principal (`F5` no editor) e executar os cenários de aceitação das US1–US8 do `spec.md` — referência oficial dos testes obrigatórios (ver Clarifications, sessão 2026-10-05). Destaques:

1. **US1**: acelerar até a traseira de um NPC pela esquerda e pela direita → perda de velocidade + drift para o lado correspondente; NPC mantém velocidade. Em seguida, **continuar com o acelera pressionado**: durante a janela `collision_accel_lockout_time` a velocidade não sobe (o jogador fica atrás alguns instantes); depois ela recomeça a subir.
2. **US3**: reduzir velocidade e deixar um NPC rápido bater na traseira → NPC desloca para o lado oposto e ultrapassa; velocidade do NPC inalterada. Em seguida (ajuste 6), o NPC deve **voltar à faixa de origem** em `npc_overtake_return_duration` segundos — depois disso as categorias seguem suas taxas normais (caminhão a 72 px/s, não preso na taxa de passeio — SC-014).
3. **US4**: durante o drift, esquerda/direita respondem reduzidos e voltam gradualmente a 100%.
4. **US5**: manter sobreposição → uma única penalização; segundo NPC encostando → nova colisão.
5. **US8 / SC-011**: partida sem contato nos 4 ambientes → comportamento idêntico às SPECs 001–004; colisões contínuas → FPS dentro da meta 60/piso 30 (monitorar com o debug do Godot).

## Validação 3 — configurabilidade (SC-012)

Alterar em `GameConfig` (sem tocar código): `drift_control_factor`, `collision_cooldown_time`, `npc_overtake_magnitude`, `collision_accel_lockout_time`, hitboxes. Esperado: mudança observável em jogo/testes em cada parâmetro — drift mais/menos controlável, cooldown mais/menos longo, ultrapassagem mais/menos ampla, janela de aceleração pós-colisão mais/menos longa, área de contato ajustada.
