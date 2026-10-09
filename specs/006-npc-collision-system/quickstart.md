# Quickstart: Sistema de Colisão entre NPCs (SPEC-006)

Guia de validação executável da feature. Pré-requisito: imports de assets gerados (abrir o editor Godot uma vez na máquina — ver AGENTS.md).

## Setup

```bash
export GODOT_BIN=~/Downloads/_installers/Godot_v4.7.2-stable_linux.x86_64
```

## Validação 1 — suíte unitária (headless)

```bash
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
```

Esperado: **todas as suítes verdes** — as 24 existentes (SPECs 001–005, sem regressão — SC-016) **mais as 9 novas** `npc_*_test.gd`. O runner sai com exit 101 quando está tudo verde.

Cobertura das suítes novas (contratos em `contracts/`, entidades em `data-model.md`):

| Suíte | O que prova (SCs principais) |
|-------|------------------------------|
| `npc_prediction_test` | US2/US8, R1: Cenário 1 100% / Cenário 2 0%; mesma velocidade 0; trajetórias distintas 0; reavaliação pós-frenagem (SC-001–SC-003, SC-012/SC-013) |
| `npc_collision_detection_test` | US1/US3: interseção → 1 colisão; classificação longitudinal/lateral; causador/atingido; intensidade proporcional (SC-004, FR-011/FR-012) |
| `npc_collision_drift_test` | US1/US3/US6: direção oposta ao impacto, determinística na margem neutra; substituição de drift; fases normal→colisão→drift→recuperação→normal; **velocidade idêntica em todas as fases** (SC-005, SC-014) |
| `npc_collision_bounds_test` | US4: fallback para lado oposto na borda; transferência ao causador quando sem espaço; 0 veículos fora dos limites nas transições 2↔4 vias (SC-006, SC-007, SC-018) |
| `npc_collision_chain_test` | US5: A→B→C; profundidade máxima respeitada; 0 processados duplicados (0 loops); caducidade; cadeias paralelas com ids próprios (SC-008) |
| `npc_collision_cooldown_test` | US5: A↔B bloqueado durante o cooldown enquanto B↔C ocorre; rearmento só após separação (SC-009) |
| `npc_collision_spawn_test` | US7: nenhum nascimento sobreposto; conflito na janela identificado; conflito pós-descarte aceito; adiamento ao quadro seguinte sem perder o nascimento (SC-010) |
| `npc_collision_event_test` | US6: evento único com os 7 campos; 0 eventos sob cooldown/bloqueio de cadeia (FR-041, SC-008/SC-009) |
| `npc_collision_regression_test` | US9: NPC deslocado que toca o jogador → exatamente 1 evento SPEC-005 e 0 desta spec; teto de 5 NPCs avaliados (SC-011, SC-015, SC-016) |

> Suítes de regressão das SPECs 001–005 (`collision_*_test.gd`, `test_traffic_*`, etc.) continuam obrigatoriamente verdes com o novo sistema ativo (SC-016).

## Validação 2 — cenários jogáveis (aceite manual)

Rodar a cena principal (`F5` no editor) e executar as Acceptance Scenarios do `spec.md` (referência oficial das US1–US9). Destaques:

1. **US1**: dois NPCs na mesma trajetória (esporte atrás de caminhão) → contato, classificação **longitudinal**, drift no caminhão para o lado oposto ao impacto; esporte sem drift e **sem mudança de velocidade**. Repetir pelos dois lados e com par colado na margem neutra (direção estável, sem oscilar).
2. **US2**: mesmo par com distância grande demais (encontro só após reciclagem) → **nenhuma** previsão; par de mesma velocidade e par em trajetórias distintas → nenhuma previsão. Só o cenário curto prevê/colide (SC-001).
3. **US3**: NPC deslocado invade a coluna do vizinho → classificação **lateral**, intensidade proporcional à diferença de velocidade, causador intacto.
4. **US4**: em pista de 2 vias, atingido colado na borda → drift inverte para o lado com espaço; sem espaço em nenhum lado → deslocamento vai ao **causador**; transição completa 2→4→2 vias sem que nenhum veículo saia da área trafegável.
5. **US5**: três NPCs em fila → cadeia A→B→C registrada; quarto elo além da profundidade máxima não processa; A↔B em cooldown com B↔C livre; colisões independentes no mesmo instante → cadeias com ids distintos.
6. **US6**: após o impacto, o NPC atravessa normal→colisão→drift→recuperação→normal e **fica onde o drift terminou** (sem voltar à faixa); velocidade igual antes/durante/depois; evento com os 7 campos observável.
7. **US7**: forçar nascimento rápido atrás de lento → reposiciona/outra faixa/adia ao quadro seguinte (nunca some até o próximo intervalo); nascimento com encontro pós-descarte → aceito.
8. **US8**: formação segura com jogador a 125 → **frear** → nova aproximação passa a ser detectada; sem mudança de velocidade relevante → nada muda.
9. **US9 / SC-019**: ambiente **Gelo** com 5 NPCs + transição de vias + colisão NPC×NPC que termina em contato com o jogador → 1 evento do SPEC-005; FPS 60 (piso 30) em partida contínua (monitorar com o debug do Godot). Complementar com o endurance do T051: **3 rodadas de ~10 minutos** (2 vias, 4 vias e a transição completa 2→4→2) verificando 0 veículos fora da área trafegável (SC-006/SC-018) e queda recorrente de FPS (SC-019).

## Validação 3 — configurabilidade (SC-017)

Alterar em `GameConfig` (sem tocar código): `npc_collision_cooldown`, `npc_drift_force_min/max`, `npc_max_chain_depth`, `npc_chain_timeout`, `npc_border_margin`, `npc_spawn_safety_distance`, `npc_reevaluation_interval`, `npc_player_speed_change_threshold`. Esperado: cada alteração produz efeito observável em jogo e/ou nos testes (cooldown mais/menos longo, drift mais/menos amplo, cadeia mais/menos profunda, detecção de borda antes/depois, adiamento de spawn, sensibilidade da reavaliação).
