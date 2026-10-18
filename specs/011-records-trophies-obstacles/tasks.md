# Tasks: Recordes, Persistência, Troféus, Pontuação e Obstáculos (SPEC-011)

**Input**: Design documents from `/specs/011-records-trophies-obstacles/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (progress_manager_api.md, obstacle_integration.md, ui_progress_display.md), quickstart.md

**Tests**: Incluídos — exigidos pela constituição §VIII e pelos SCs da spec (SC-002/003/004/007/009/010/011) e pelo padrão das SPEC-007…010 (suítes novas ao lado das legadas, sem tocar nas existentes).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project Godot**: `src/` e `tests/unit/` na raiz do repositório; wiring por código no `GameplayManager` (padrão das specs anteriores); zero mudanças em `gameplay.tscn`.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Sementes de configuração e chaves de UI que todos os stories usam (research R13, contract obstacle_integration §5, contract ui_progress_display §3)

- [X] T001 [P] Adicionar blocos novos em src/config/game_config.gd: `score_peso_distancia/score_peso_trofeu/score_peso_penalidade/score_historico_max`, `poca_aderencia_fator/poca_duracao/poca_recuperacao_frac`, `cascalho_velocidade_fator/cascalho_duracao/cascalho_aderencia_fator`, `obstaculo_intervalo_km/obstaculo_max_ativos/obstaculo_min_spacing/obstaculo_npc_spacing/obstaculo_start_offset_km/obstaculo_finish_offset_km/obstaculo_peso_poca/obstaculo_peso_cascalho`, `trofeu_assets`, `obstaculo_poca_path/obstaculo_cascalho_path/obstaculo_tamanho_poca/obstaculo_tamanho_cascalho`, `save_arquivo` (padrões do research R13)
- [X] T002 [P] Adicionar as 7 chaves novas de `ui_strings` em src/config/game_config.gd (`score_label`, `victory_score`, `record_label`, `accumulated_label`, `trophy_format`, `obstacles_available`, `obstacles_locked`) e verificar que os 5 assets (`assets/trofeus/trofeu-*.png`, `assets/obstaculos/poca.png`, `assets/obstaculos/cascalho.png`) têm `*.import` gerados

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Camada de persistência e domínio de progressão que todos os user stories consomem (research R2, data-model §1/§3, contracts/progress_manager_api.md)

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T003 [P] Criar tests/unit/save_manager_test.gd: round-trip gravar→carregar em `user://` temporário (removido no teardown), arquivo ausente ⇒ `{}`, JSON corrompido ⇒ `{}` sem tocar o arquivo, falha de gravação preserva o arquivo anterior (SC-010)
- [X] T004 [P] Criar tests/unit/progress_manager_test.gd: `carregar_de({})` materializa os 3 modos com defaults, tolerância a modo faltante/ciclo com duplicata/histórico acima do teto, `dados_para_salvar()` devolve o esquema v1 completo (data-model §3)
- [X] T005 Criar src/save/save_manager.gd (`SaveManager extends RefCounted`): `_init(caminho)`, `carregar()` tolerante, `gravar()` atômico tmp+rename retornando bool, zero domínio (contract progress_manager_api §4)
- [X] T006 Criar src/game/progress_manager.gd (`ProgressManager extends RefCounted`): campos `_modos`/`_historico`, `carregar_de()`, `dados_para_salvar()`, getters (`get_recorde/get_acumulada/get_trofeus/get_ciclo`) e `snapshot()` com os 3 modos sempre materializados (data-model §1)

**Checkpoint**: Persistência e domínio base prontos — user stories podem começar

---

## Phase 3: User Story 1 - Pontuar a corrida e manter recordes por modo, persistidos (Priority: P1) 🎯 MVP

**Goal**: Vitória gera exatamente 1 resultado com pontuação pela fórmula (distância + troféus − perda por colisão), recorde por modo atualizado só com pontuação estritamente maior, acumulada e histórico persistidos; derrota não registra nada

**Independent Test**: Vencer corridas nos 3 modos conferindo fórmula e independência de recordes; fechar/reabrir e conferir restauração; perder corrida e conferir zero registro/zero alteração de recorde

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T007 [P] [US1] Criar tests/unit/score_calculation_test.gd: fórmula do data-model §2 (distância × peso, troféus × peso, perda × peso, clamp ≥ 0), consumo normal gera 0 de penalidade, perda contada 1× (SC-002/SC-003, FR-004…FR-007)
- [X] T008 [P] [US1] Estender tests/unit/progress_manager_test.gd: primeiro resultado inicializa recorde, superação estrita atualiza, empate/menor não atualiza, nenhum cruzamento entre modos, histórico com trim no teto, derrota não cria resultado (SC-001/SC-011)
- [X] T009 [US1] Criar tests/unit/progress_flow_test.gd: com `GameplayManager` sintético, vitória chama `processar_vitoria` **uma** vez + `save.gravar` **uma** vez na ordem certa (pontuação antes do recorde antes do save), derrota chama `processar_derrota` + save sem resultado (SC-003/SC-011, research R7)

### Implementation for User Story 1

- [X] T010 [US1] Implementar `calcular_pontuacao()` e `processar_vitoria()` em src/game/progress_manager.gd registrando o resultado com o conjunto completo de data-model.md §1.1 (modo, ambiente, distancia, pontuacao, trofeus, perda_colisao e data_hora via `Time.get_datetime_string_from_system()` — `""` se indisponível) na ordem: marcar ambiente → pontuar → recorde → acumulada → histórico → snapshot
- [X] T011 [US1] Implementar `processar_derrota()` (zerar ciclo do modo, totais preservados, snapshot sem pontuacao) em src/game/progress_manager.gd
- [X] T012 [US1] Adicionar acumulador `perda_colisao_corrida` + `get_perda_colisao_corrida()` em src/fuel/fuel_system.gd: incrementa com o delta real descontado em `on_player_collision()`, zera em `reset()` (research R4)
- [X] T013 [US1] Integrar no orquestrador src/game/gameplay_manager.gd: campos `progress_manager`/`save_manager`, criação + `carregar_de(carregar())` no `_ready()`, ramo de vitória (capturar `ambiente_atual()` → `registra_vitoria()` → `processar_vitoria(...)` → `save.gravar(...)` 1×) e ramo de derrota (`processar_derrota` → save 1×) em `_avaliar_transicoes()`, guards `if` para testes sintéticos

**Checkpoint**: US1 completa — corrida pontua, recorde por modo persiste entre sessões

---

## Phase 4: User Story 2 - Conquistar troféus por completar os quatro ambientes, por modo (Priority: P2)

**Goal**: Ciclo de 4 ambientes distintos concede exatamente +1 troféu por modo, repetição no-op, derrota zera o ciclo preservando o total, independência total entre modos, exibição de ícone 32 px + contador + progresso "k/4" com troca de modo sem mistura

**Independent Test**: Vencer os 4 ambientes no Relaxante conferindo +1 e ciclo zerado; repetir ciclos; derrota no meio do ciclo zera só o ciclo; alternar modos no menu e conferir ícone/números

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T014 [P] [US2] Estender tests/unit/progress_manager_test.gd: 4 ambientes distintos → exatamente +1 troféu e ciclo zerado; ambiente repetido no ciclo → no-op preservando pendentes; 3 ciclos → 3 troféus; derrota zera ciclo e preserva total; operações em um modo não tocam outro (SC-004/SC-005, FR-009…FR-011)

### Implementation for User Story 2

- [X] T015 [US2] Implementar `marcar_ambiente()` e a concessão de troféu/ciclo dentro de `processar_vitoria()` em src/game/progress_manager.gd (contagem usa o total **após** marcar — FR-006)
- [X] T016 [P] [US2] Acrescentar à `UIManager` o ícone `TextureRect` 32×32 (filtro NEAREST, textura de `GameConfig.trofeu_assets[modo]`, carregada 1× no `_ready` com guarda `ResourceLoader.exists`) + `_rotulo_trofeus` no painel do menu e nos painéis de vitória/Fim de Jogo em src/ui/ui_manager.gd (contract ui_progress_display §2)
- [X] T017 [US2] Estender `atualizar_modo(rotulo, modo_id)` para trocar ícone + bloco de troféus do menu junto com a linha "Modo"; repassar o id em src/game/gameplay_manager.gd no handler de `select_next_mode` (SC-006, US2 AS7)
- [X] T018 [US2] Ligar os fluxos em src/game/gameplay_manager.gd: `atualizar_painel_progresso(progresso.snapshot(modo))` em `_show_menu()`, após o save da vitória e após o save da derrota (snapshot com dados de troféus atualizados)

**Checkpoint**: US1 + US2 completas — troféus por modo exibidos e persistidos

---

## Phase 5: User Story 3 - Enfrentar os obstáculos poça de água e cascalho (Priority: P3)

**Goal**: Poça reduz aderência lateral temporariamente (recuperação gradual) e cascalho reduz velocidade temporariamente; spawn válido em todos os ambientes, sem sobreposição/bloqueio total, detecção confiável no Desafio, combustível intocado, efeitos congelados na pausa

**Independent Test**: Atravessar poça e cascalho nos 3 modos medindo efeito e retorno automático; sonda de 100 encontros em Desafio sem atravessamento; conferir combustível inalterado e posicionamento na pista

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T019 [P] [US3] Criar tests/unit/obstacle_manager_test.gd: spawn por distância no intervalo configurado, rejeição/reagendamento fora dos limites da pista, por espaçamento entre obstáculos, por proximidade de NPC e do jogador, gate `disponivel == false` ⇒ zero spawn, `reset()` devolve a pool e zera a distância (FR-017, research R6)
- [X] T020 [P] [US3] Criar tests/unit/obstacle_effects_test.gd: efeito da poça reduz a resposta lateral e rampa de volta ao normal dentro da duração ±10%; cascalho limita o teto da velocidade e expira; colisão repetida renova sem empilhar; `reset()` limpa os efeitos; **sonda de 100 encontros por obstáculo em Desafio com 0 atravessamentos** (SC-008/SC-009, FR-014…FR-016/FR-020)

### Implementation for User Story 3

- [X] T021 [US3] Criar src/obstacles/obstacle.gd (`Obstacle`): sprite + hitbox explícito de `GameConfig.obstaculo_tamanho_*`, estados do pool, sem `_process` próprio
- [X] T022 [US3] Criar src/obstacles/obstacle_manager.gd (`ObstacleManager extends Node`): `configurar()` com carregamento guardado dos sprites, pool de `obstaculo_max_ativos`, `update(delta, road, snapshot_npc, track, player)` com rolagem, spawn por distância com sortio de tipo pelos pesos e validações (reagendar +0,1 km), detecção AABB por quadro chamando `player.controller.aplicar_efeito_*` e reciclagem imediata, `definir_disponivel()`, `reset()` (contract obstacle_integration §1)
- [X] T023 [US3] Estender src/player/vehicle_controller.gd: campos dos 2 efeitos, `aplicar_efeito_poca()` (sobrescrita, rampa de recuperação, multiplicação em `_apply_lateral_physics` junto a `control_factor`) e `aplicar_efeito_cascalho()` (teto `max_speed × fator_dificuldade_total × fator` limitado por quadro em `_apply_vertical_physics`, estabilidade via `cascalho_aderencia_fator`), tick no `_process`, limpeza em `reset()` (research R5)
- [X] T024 [US3] Integrar em src/game/gameplay_manager.gd: campo `obstacles_layer`, criação/`configurar()`/`add_child` no `_ready()`, novo passo 3.5 em `_processar_playing()` (após os galões, guards `if`), `reset()` no `_reset_corrida()`

**Checkpoint**: US3 completa — obstáculos rodam nos 3 modos com efeitos temporizados

---

## Phase 6: User Story 4 - Desbloquear obstáculos no Relaxante e integrar tudo à interface e ao fluxo (Priority: P4)

**Goal**: Relaxante nasce com obstáculos bloqueados e desbloqueia para sempre com o 1º troféu do modo (persistido, derivado); Normal/Desafio livres desde a 1ª corrida; UI mostra pontuação da corrida (só vitória), acumulada, recorde, troféus e estado dos obstáculos nas 3 telas, sem nada novo durante a corrida

**Independent Test**: Relaxante sem troféus ⇒ zero obstáculos; 1º troféu no Relaxante ⇒ desbloqueio permanente após reinício; troféus de Normal/Desafio não desbloqueiam; telas de fim com todos os números corretos

### Tests for User Story 4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T025 [P] [US4] Estender tests/unit/progress_manager_test.gd: `obstaculos_disponiveis("relaxing")` false com 0 troféus e true com ≥1; `normal`/`challenge` sempre true; troféus de outros modos nunca desbloqueiam o Relaxante; desbloqueio sobrevive a `carregar_de(dados_para_salvar())` (SC-007, FR-018/FR-019)
- [X] T026 [P] [US4] Estender tests/unit/obstacle_manager_test.gd (fluxo): corrida com `definir_disponivel(false)` ⇒ 0 nascimentos em updates longos; `definir_disponivel(true)` ⇒ nascimentos ocorrem; gate preservado após `reset()` (SC-007)

### Implementation for User Story 4

- [X] T027 [US4] Implementar `obstaculos_disponiveis()` em src/game/progress_manager.gd (regra derivada do research R2/R12 — sem campo persistido)
- [X] T028 [US4] Implementar `atualizar_painel_progresso(dados)` em src/ui/ui_manager.gd: recorde, acumulada, `victory_score` só quando `pontuacao > 0` (oculto em derrota/menu), obstáculos disponíveis/bloqueados; idempotente e tolerante a snapshot vazio (contract ui_progress_display §1/§5)
- [X] T029 [US4] Ligar em src/game/gameplay_manager.gd: `obstacles_layer.definir_disponivel(progresso.obstaculos_disponiveis(dificuldade.get_modo()))` no `_reset_corrida()`; chamadas de `atualizar_painel_progresso` já posicionadas na US1/US2 garantem as 3 telas; conferir que **nada** novo aparece em PLAYING (FR-023)
- [X] T030 [US4] Ajustar/validar o layout do bloco de progresso nas 3 telas (posições Y do contract ui_progress_display §2) sem sobreposição com opções/marcadores existentes em 640×480 (SC-012, US4 AS9)

**Checkpoint**: Todas as user stories funcionais e independentes

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Validação de regressão, aceite manual e calibração

- [X] T031 Rodar a suíte completa 2× (`GODOT_BIN=... bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit`) confirmando exit 101, suíte legada intacta (0 ajustes em testes existentes) e console sem erros (SC-012) — **concluído em 2026-10-17: 74 suítes, 467 casos (414 legados + 53 novos), exit 101 em 2 execuções consecutivas, zero falhas, 0 testes legados ajustados** *(reexecutado após o ajuste da poça — Phase 8: 74 suítes, 472 casos, exit 101 nas 2 rodadas pós-ajuste)*
- [X] T032 Executar com o usuário o aceite manual do quickstart.md §3.1–§3.7 (19 passos: defaults, pontuação/recorde, colisão, derrota, troféus, obstáculos, persistência) — *1ª rodada em 2026-10-17: achado registrado na Phase 8 (comportamento da poça); **revalidação do passo 13 concluída em 2026-10-17 pelo usuário: testes executados com sucesso, sem novos achados** (T035–T044 aplicados)*
- [X] T033 Se o §4 registrar achados de balanceamento, aplicar os ajustes **apenas** em src/config/game_config.gd conforme os gatilhos do quickstart §5 (research R13) e revalidar a suíte — *§4 sem achados de balanceamento na revalidação de 2026-10-17: nenhum valor de calibração ajustado*
- [X] T034 Registrar o estado da SPEC-011 e os ajustes pós-implementação (se houver) em AGENTS.md, quickstart.md e nos contratos alterados — sincronizando decisões finais *(concluído em 2026-10-17: AGENTS.md com o bloco SPEC-011 + ajuste da poça; quickstart e contratos sincronizados no T037)*

---

## Phase 8: Ajuste pós-implementação — comportamento da poça (2026-10-17)

**Purpose**: resposta ao achado do aceite manual (T032) — a poça deixou de reduzir aderência lateral e passou a desviar o jogador em meio carro, permanecendo inerte na pista

- [X] T035 Substituir o efeito de aderência da poça pelo desvio lateral: `game_config.gd` (remover `poca_aderencia_fator/poca_duracao/poca_recuperacao_frac`, adicionar `poca_desvio_lateral = 11,0` = meio carro), `vehicle_controller.gd` (remover campos/método/tick/resets da poça — só cascalho permanece), `obstacle_manager.gd` (`_detectar(player, road)` com branch: poça ⇒ `_desviar_jogador` pelo lado do impacto + estado `ATINGIDO` permanecendo na pista; cascalho ⇒ efeito + reciclagem imediata, inalterado), docstrings de `obstacle.gd`/`obstacle_manager.gd`
- [X] T036 Reescrever as suítes de obstáculos para o comportamento novo: `obstacle_effects_test.gd` (desvio esq/dir, clamp de borda, inércia pós-hit, permanência até sair da tela, sem aderência, cascalho inalterado, sondas 100 poças/100 cascalhos com 0 atravessamentos) e `obstacle_manager_test.gd` (`test_09` desvio/permanência + `test_09b` cascalho) — 0 testes legados ajustados
- [X] T037 Sincronizar documentos com o comportamento novo: spec.md (clarificação, narrativa US3, cenários 2–3, FR-014/FR-016/FR-026, edge case de pausa, entidade), research.md (R5/R6/R13), data-model.md (§4/§5), contracts/obstacle_integration.md (§1.4/§2/§5), quickstart.md (passo 13, gatilho de calibração §5)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup (T001/T002) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational — MVP, entrega de valor independente
- **US2 (Phase 4)**: Depends on Foundational; integra com US1 (snapshot/troféus na pontuação) mas é testável sozinha
- **US3 (Phase 5)**: Depende de Foundational só para o gate de desbloqueio (US4); os efeitos/spawn são independentes de US1/US2 e podem ser implementados em paralelo a elas
- **US4 (Phase 6)**: Depende de US2 (troféus) e US3 (obstáculos) + Foundational
- **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: Foundational only — sem dependências de outras stories
- **US2 (P2)**: Foundational; US1 apenas define o snapshot que a UI já consome
- **US3 (P3)**: Foundational; gate de disponibilidade consumido em US4
- **US4 (P4)**: US2 + US3 (desbloqueio = troféus × obstáculos) + UI própria

### Within Each User Story

- Tests written and FAIL before implementation (TDD — padrão da casa)
- Domínio antes de wiring; wiring antes de UI
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- Phase 1: T001 ∥ T002 (mesmo arquivo, mas blocos distintos — se preferir serializar, faça T001 → T002)
- Phase 2: T003 ∥ T004 (suítes distintas)
- Phase 3: T007 ∥ T008; T009 após T010/T011 (usa o orquestrador)
- Phase 4: T014 ∥ (T015…T018); T016 ∥ T015 (arquivos distintos)
- Phase 5: T019 ∥ T002? não — T019 ∥ T020 (suítes distintas); T021 ∥ T023 (arquivos distintos) ∥ T022 parcialmente (depende do contrato de T021)
- Phase 6: T025 ∥ T026
- US1 ∥ US3 podem correr em paralelo após Foundational (arquivos praticamente disjuntos: fuel/progress×obstacles/vehicle)

---

## Parallel Example: User Story 3

```bash
# Launch both test suites together (TDD, RED primeiro):
Task: "Criar tests/unit/obstacle_manager_test.gd (spawn/validações/gate)"
Task: "Criar tests/unit/obstacle_effects_test.gd (efeitos + sonda SC-009)"

# Then implementation in parallel where files are disjoint:
Task: "Criar src/obstacles/obstacle.gd"
Task: "Estender src/player/vehicle_controller.gd (efeitos temporizados)"

# Then the manager + wiring (sequential):
Task: "Criar src/obstacles/obstacle_manager.gd"
Task: "Integrar passo 3.5 em src/game/gameplay_manager.gd"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (config + strings)
2. Complete Phase 2: Foundational (SaveManager + ProgressManager base) — CRITICAL
3. Complete Phase 3: US1 (fórmula, recordes, encerramento, persistência)
4. **STOP and VALIDATE**: suíte verde + vencer corridas conferindo recorde persistente entre sessões
5. Entregar/demo — já há valor completo (correr, pontuar, bater recorde, recorde sobrevive ao reinício)

### Incremental Delivery

1. Setup + Foundational → fundação pronta
2. US1 → testar independentemente → **MVP**
3. US2 → testar independentemente → troféus por modo
4. US3 → testar independentemente → gameplay de obstáculos
5. US4 → desbloqueio + UI completa
6. Polish → regressão, aceite manual, calibração

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: US1 (domínio/persistência)
   - Developer B: US3 (obstáculos/efeitos — quase disjunto de US1)
   - Developer C: US2 (troféus + UI de ícone)
3. US4 integra o que estiver pronto e fecha o fluxo

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Cada user story é independente e testável; parar em qualquer checkpoint para validar
- Guards `if` nos campos novos do `GameplayManager` são obrigatórios (testes sintéticos legados — garantia R12)
- Nenhum teste legado pode ser ajustado (SC-012)
- Números de balanceamento só em `game_config.gd` (FR-026, §IV)
- Commit após cada task ou grupo lógico (não faz parte destas tasks — só quando solicitado)

---

## Phase 9: Convergence

**Purpose**: brechas apontadas pelo `/speckit.converge` (2026-10-17) entre spec/plan/tasks e o código atual

- [X] T038 CRITICAL Adicionar cobertura automatizada da seleção ponderada de tipo de obstáculo (`_sortear_tipo()` em src/obstacles/obstacle_manager.gd:250-257): peso de um tipo = 100 ⇒ sempre aquele tipo; pesos 50/50 com amostragem estatística; ambos os pesos 0 ⇒ fallback poça (Constitution §VIII — seleção determinística MUST ter cobertura automatizada) (missing)
- [X] T039 Fechar a atomicidade do SaveManager ante falha de ESCRITA parcial: em src/save/save_manager.gd checar `get_error()` após `store_string()`/`close()` antes do `rename_absolute`; em erro remover o `.tmp` e devolver `false` sem tocar no arquivo válido + teste cobrindo escrita parcial (FR-022, SC-010, Edge Case "Falha de gravação no encerramento") (partial)
- [X] T040 Limpar e esconder os obstáculos no caminho para o MENU e nos encerramentos: `obstacles_layer.reset()` em `_on_go_to_menu()` e no ramo de encerramento de src/game/gameplay_manager.gd (espelhando o `items_layer.reset()` dos galões) + ocultação em `_show_menu()`/exibição em `_show_ready()` + caso de teste de fluxo confirmando menu sem resíduo (FR-023, US4-AS9) (partial)
- [X] T041 Tornar `atualizar_painel_progresso` de src/ui/ui_manager.gd um no-op real com snapshot vazio: default `desbloqueado = false` e sem escrita de textos sem dados (contract ui_progress_display §5; Edge Case "primeira execução ⇒ obstáculos do Relaxante bloqueados") (contradicts)
- [X] T042 Remover os resíduos do ajuste T032: atualizar o comentário obsoleto em src/config/game_config.gd:641-642 (aderência/duração já removidos) e em src/player/vehicle_controller.gd:116-118 (poça não entra mais em `_apply_lateral_physics`); eliminar a chave morta `ui_strings.score_label` (única ocorrência é a definição) ou passar a exibi-la, alinhando contracts/ui_progress_display.md §3 (FR-026, Qualidade de Código) (contradicts)
- [X] T043 Acrescentar à sonda de SC-009 em tests/unit/obstacle_effects_test.gd uma variante em que o obstáculo nasce acima do jogador e é cruzado por rolagem real via `manager.update()` na velocidade do Desafio (0 atravessamentos), além do encontro instantâneo atual (SC-009) (partial)
- [X] T044 Sincronizar os contratos com o código: contracts/obstacle_integration.md §1.1 (`Node2D`, `configurar()` sem args), §1.3 (revalidação do candidato pendente em vez de "+0,1 km", validação 2D de NPC) e §4 (snapshot em `_avaliar_transicoes`), contracts/progress_manager_api.md §? (chave de modo desconhecida materializada, não "ignorada") (plan decisions) (contradicts)
