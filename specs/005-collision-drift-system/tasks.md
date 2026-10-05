# Tasks: Sistema de Colisão e Drift

**Input**: Design documents from `/specs/005-collision-drift-system/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Incluídos — a constituição torna MUST a cobertura de testes e o padrão GdUnit4 (`tests/unit/`) vigora desde o SPEC-001. Cada história lista suas suítes antes da implementação.

**Organization**: Tarefas agrupadas por user story (US1–US8) para permitir implementação e validação independentes. Ordem das fases segue a prioridade do spec: P1 (US1, US2, US3, US4, US8) e depois P2 (US5, US6, US7).

## Format: `- [ ] [TaskID] [P?] [Story?] Description`

---

## Phase 1: Setup

**Purpose**: Estrutura do novo módulo, sem lógica

- [X] T001 Create `src/collision/` module directory per plan structure
- [X] T002 [P] Add collision/drift tunables to `src/config/game_config.gd`: `collision_speed_loss_min/max`, `drift_force_min/max`, `drift_duration_min/max`, `drift_control_factor` (0,4), `drift_recovery_rate`, `collision_cooldown_time`, `collision_neutral_margin`, `npc_overtake_magnitude`, `npc_overtake_duration`, `collision_intensity_divisor` (FR-035, data-model §5)
- [X] T003 [P] Add hitbox configuration to `src/config/game_config.gd`: `player_hitbox_size` e `npc_hitbox_size` por categoria (caminhão/esporte/passeio/utilitário), valores iniciais derivados da área visual com margens laterais reduzidas (data-model §3, Assumptions)

**Checkpoint**: GameConfig compilando com todos os parâmetros; cena principal abrindo sem custo adicional.

---

## Phase 2: Foundational (Blocking Prerequisites)

Pré-requisitos que bloqueiam todas as histórias: entidade de dados, detecção base e hooks aditivos inertes.

- [X] T004 Create `CollisionData` resource in `src/collision/collision_data.gd` com os 6 campos do contrato (`player`, `npc`, `tipo` enum 1-1/1-2/1-3, `velocidade_impacto`, `intensidade`, `direcao_drift`) per `contracts/collision_event.md`
- [X] T005 Create `CollisionSystem` skeleton in `src/collision/collision_system.gd`: sinal `collision_occurred(data)`, registro no `gameplay_manager.gd`, loop por quadro sobre NPCs ativos consumindo `TrafficVehicle.get_occupied_area()` per `contracts/consumed_apis.md` §1, sem consequências ainda
- [X] T006 [P] Add additive `control_factor: float = 1.0` hook to `src/player/vehicle_controller.gd` multiplicando a resposta lateral, inerte por padrão (FR-034) per `contracts/consumed_apis.md` §3
- [X] T007 [P] Implement player hitbox derivation in `src/collision/collision_system.gd`: `Rect2` centrado na posição do jogador a partir de `GameConfig.player_hitbox_size`, mesmo padrão de `get_occupied_area()` (data-model §3)
- [X] T008 [P] Implement per-category NPC hitbox lookup in `src/collision/collision_system.gd`: ajusta o `Rect2` de `get_occupied_area()` pelas dimensões configuradas da categoria antes da interseção (FR-007, R1)
- [X] T009 Implement frame intersection detection in `src/collision/collision_system.gd`: `intersects` jogador×cada NPC ativo, sem alocação por quadro, sem consequências ainda (R1, FR-001)
- [X] T010 Implement impact classification in `src/collision/collision_system.gd` per R2: dominância vertical/horizontal dos centros + sinal da velocidade relativa → 3 tipos; margem neutra determinística (lado com mais espaço; empate → esquerda) (FR-002–FR-005)
- [X] T011 Implement intensity computation in `src/collision/collision_system.gd` per R8: velocidade relativa normalizada por `collision_intensity_divisor`, clamp [0,1] (FR-024, FR-025)

**Checkpoint**: Detecção + classificação + intensidade funcionando isoladamente (validável pelos testes de detecção/classificação antes das consequências).

---

## Phase 3: User Story 1 - Colidir com a traseira de um NPC (P1) 🎯 MVP

**Goal**: Detectar "jogador atinge traseira do NPC", reduzir velocidade do jogador proporcionalmente à intensidade e aplicar drift lateral para o lado relativo; NPC sem penalização.

**Independent Test**: Um NPC à frente; acelerar até a traseira pela esquerda e pela direita; observar perda de velocidade no intervalo configurado e drift na direção correta (CAs 01–03, SC-001–SC-003).

### Tests (escrever e ver falhar antes da implementação)

- [X] T012 [P] [US1] Detection suite in `tests/unit/collision_detection_test.gd`: interseção ↔ exatamente uma colisão; sem interseção, nenhuma (SC-001)
- [X] T013 [P] [US1] Classification suite in `tests/unit/collision_classification_test.gd`: 3 tipos distintos, margem neutra determinística, direção do drift por posição relativa (FR-002–FR-005)
- [X] T014 [P] [US1] Drift suite (casos US1) in `tests/unit/collision_drift_test.gd`: perda dentro de min/max, velocidade nunca abaixo de zero, direção do drift por lado (FR-009–FR-011, SC-002/SC-003)

### Implementation

- [X] T015 [US1] Create `DriftState` state machine in `src/collision/drift_state.gd`: fases NORMAL→IMPACTO→DRIFT→RECUPERACAO→NORMAL, direção, força restante, tempo decorrido, fator de controle (FR-015, data-model §2)
- [X] T016 [US1] Apply player speed loss in `src/collision/collision_system.gd`: interpolação min/max pela intensidade, clamp ≥ 0, nunca parada instantânea (FR-009, FR-010)
- [X] T017 [US1] Wire impact lateral displacement in `src/collision/drift_state.gd`: deslocamento extra na direção classificada com decaimento, clamp pelos limites da estrada na altura do jogador consultados por quadro (FR-011, FR-022, R7)
- [X] T018 [US1] Connect `DriftState` to `VehicleController.control_factor` em `src/game/gameplay_manager.gd` ou wiring equivalente: controle reduzido durante drift, 1.0 fora dele (FR-013, contrato §3)
- [X] T019 [US1] Ensure NPC consequences are nil in tipo 1-1: nenhum deslocamento nem alteração de velocidade do NPC (US1-CA4, FR-017 por simetria de escopo)

**Checkpoint**: US1 validável de forma independente — T012–T014 verdes, cenário manual do quickstart 2.1 passando.

---

## Phase 4: User Story 2 - Contato lateral com um NPC (P1)

**Goal**: Classificar "colisão lateral" e aplicar a mesma regra de consequências (perda + drift para o lado relativo), estável dentro da margem neutra.

**Independent Test**: Encostar lateralmente em um NPC dos dois lados; verificar classificação "lateral" e drift na direção correta; diferença dentro da margem neutra decide de forma estável, sem oscilação (CA-04).

### Tests

- [X] T020 [P] [US2] Lateral cases em `tests/unit/collision_classification_test.gd`: dominância horizontal → tipo 1-2; drift para o lado relativo; estabilidade dentro da margem neutra sem alternância (US2-CA1–CA4)

### Implementation

- [X] T021 [US2] Verify/tune lateral classification thresholds in `src/collision/collision_system.gd` para hitboxes reais das 4 categorias (limiares derivados das dimensões das hitboxes, R2)
- [X] T022 [US2] Ensure same consequence pipeline serves tipo 1-2 em `src/collision/collision_system.gd` sem penalização ao NPC (US2-CA3)

**Checkpoint**: US2 validável de forma independente; raspagens em mudança de faixa comportam-se corretamente.

---

## Phase 5: User Story 3 - NPC atinge a traseira do jogador e ultrapassa (P1)

**Goal**: Na colisão tipo 1-3, jogador sofre perda/drift; o NPC não perde velocidade, desloca-se lateralmente para o lado oposto, conclui a ultrapassagem e retoma a trajetória.

**Independent Test**: Reduzir a velocidade, aguardar NPC rápido bater na traseira com o jogador à esquerda e à direita; verificar drift do jogador, deslocamento oposto do NPC, ultrapassagem concluída e velocidade do NPC inalterada (CA-05, SC-006).

### Tests

- [X] T023 [P] [US3] Overtake suite in `tests/unit/collision_overtake_test.gd`: velocidade do NPC inalterada, direção oposta, conclusão em pista livre, retorno à trajetória, clamp em 2/4 vias e transição (FR-017–FR-021, SC-006, SC-007)

### Implementation

- [X] T024 [US3] Create `NpcOvertakeState` in `src/collision/npc_overtake_state.gd`: direção oposta ao drift, magnitude/duração configuráveis, duração restante (data-model §4)
- [X] T025 [US3] Add additive `apply_overtake_offset(direcao, magnitude, duracao)` to `src/traffic/traffic_vehicle.gd`: offset de posição com clamp pelos `bounds` já recebidos em `update_scroll`, sem tocar velocidade nem estado do pool (contrato §4, FR-017, FR-020, FR-033)
- [X] T026 [US3] Trigger overtake on tipo 1-3 em `src/collision/collision_system.gd`, com espera no limite quando não houver espaço lateral (Edge Case, FR-020)

**Checkpoint**: US3 validável de forma independente; ultrapassagem arcade funcionando nos dois lados.

---

## Phase 6: User Story 4 - Recuperação gradual do controle (P1)

**Goal**: Durante o drift o jogador mantém controle parcial (fator configurado, padrão 40%) e a influência do impacto decai gradualmente até o controle voltar a 100% ao fim da duração.

**Independent Test**: Provocar colisão e corrigir a trajetória durante o drift: resposta reduzida, retorno progressivo e comportamento final idêntico ao pré-colisão (CA-07, SC-004).

### Tests

- [X] T027 [P] [US4] Recovery cases em `tests/unit/collision_drift_test.gd`: fator mínimo mantido durante todo o drift, interpolação até exatamente 100%, estado final idêntico, deslocamento ocorre sem input (US4-CA1–CA4, SC-004)

### Implementation

- [X] T028 [US4] Implement gradual recovery em `src/collision/drift_state.gd`: `fator_controle` interpolado até 1.0 por `drift_recovery_rate` na fase RECUPERACAO; transição para NORMAL ao atingir 1.0 (FR-014, R3)
- [X] T029 [US4] Scale drift force/duration by intensity em `src/collision/collision_system.gd`: interpolação min/max pela intensidade (FR-012, FR-025)

**Checkpoint**: US4 validável de forma independente; ciclo completo de estados observável em teste e em jogo.

---

## Phase 7: User Story 8 - Preservação das features anteriores (P1)

**Goal**: Sem contato, tudo se comporta como nas SPECs 001–004; com colisão, nenhum veículo sai dos limites trafegáveis em 2/4 vias e transições.

**Independent Test**: Partida sem colisões comportando-se identicamente às specs anteriores; suíte completa (13 suítes existentes) verde sem alterações (SC-010).

### Tests

- [X] T030 [P] [US8] Boundary-during-collision cases em `tests/unit/collision_drift_test.gd` e `tests/unit/collision_overtake_test.gd`: deslocamentos clampados nos limites vigentes por altura em 2 vias, 4 vias e transição (FR-022, FR-023, SC-007)

### Implementation

- [X] T031 [US8] Run full existing suite (`runtest.sh -a res://tests/unit`) e corrigir qualquer regressão sem alterar o comportamento das SPECs 001–004 (FR-034, SC-010)
- [X] T032 [US8] Validate zero-cost inertial state: confirmar que `control_factor = 1.0` e ausência de colisão produzem caminho de código idêntico ao anterior (revisão + teste de não-regressão)

**Checkpoint**: Regressão zero comprovada; SC-010 verde.

---

## Phase 8: User Story 5 - Cooldown por par (P2)

**Goal**: Mesma sobreposição não gera penalização repetida; cooldown controlado por par jogador↔NPC; rearme somente após separação e novo contato.

**Independent Test**: Manter veículos sobrepostos → exatamente uma penalização; segundo NPC distinto durante o cooldown → nova colisão; após cooldown com sobreposição persistente → nada até separar e retocar (CA-08, SC-005).

### Tests

- [X] T033 [P] [US5] Cooldown suite in `tests/unit/collision_cooldown_test.gd`: uma penalização por sobreposição, par distinto colide normalmente, rearma após separação, zero consequência sob cooldown (FR-026–FR-028, SC-005)

### Implementation

- [X] T034 [US5] Implement per-pair cooldown em `src/collision/collision_system.gd`: dicionário `npc_instance_id → tempo_restante`, decremento por quadro, com `collision_cooldown_time` de `GameConfig` (R5, FR-026, FR-027)
- [X] T035 [US5] Implement rearm-on-separation em `src/collision/collision_system.gd`: transição não-sobreposto→sobreposto obrigatória para nova colisão do mesmo par (US5-CA3, Assumptions)
- [X] T036 [US5] Substituir drift vigente em nova colisão válida durante drift anterior, pela última classificação (Edge Case)

**Checkpoint**: US5 validável de forma independente; justiça perceptível garantida.

---

## Phase 9: User Story 6 - Evento de colisão (P2)

**Goal**: Toda colisão válida emite `collision_occurred(CollisionData)` com os 6 dados mínimos; cooldown emite zero eventos; nenhum outro sistema é modificado.

**Independent Test**: Provocar os três tipos e capturar os eventos; conferir tipo, intensidade, direção e veículos em cada um (CA-09, SC-008).

### Tests

- [X] T037 [P] [US6] Event suite in `tests/unit/collision_event_test.gd`: payload completo e correto nos 3 tipos, exatamente um evento por colisão válida, zero sob cooldown (FR-028–FR-030, SC-008)

### Implementation

- [X] T038 [US6] Emit `collision_occurred` em `src/collision/collision_system.gd` após classificação e antes/for paralelo às consequências, montando `CollisionData` por `contracts/collision_event.md` (FR-029)
- [X] T039 [US6] Confirmar isolamento: nenhuma escrita em combustível/pontuação/dano no módulo de colisão (FR-030, revisão estática + teste)

**Checkpoint**: US6 validável de forma independente; contrato pronto para o spec de combustível.

---

## Phase 10: User Story 7 - Hitboxes independentes dos sprites (P2)

**Goal**: Detecção usa exclusivamente hitboxes configuradas; trocar/redimensionar sprite não muda nenhum resultado.

**Independent Test**: Trocar o sprite de um NPC por imagem de dimensão diferente sem tocar configuração → resultados idênticos de colisão (CA-10, SC-009).

### Tests

- [X] T040 [P] [US7] Hitbox suite in `tests/unit/collision_hitbox_test.gd`: troca de sprite não altera cenários; hitbox configurada define o contato; caminhão vs. passeio só diferem na área (FR-006–FR-008, SC-009, US7-CA1–CA3)

### Implementation

- [X] T041 [US7] Garantir que `src/collision/collision_system.gd` nunca consulta textura/sprite nem `category.size` diretamente — somente a tabela de hitboxes de `GameConfig` (FR-008, R1)
- [X] T042 [US7] Se `TrafficVehicle.get_occupied_area()` for substituído como fonte, manter o contrato e aplicar o ajuste externo, conforme `contracts/consumed_apis.md` §1 (documentar decisão no código)

**Checkpoint**: US7 validável de forma independente; independência de assets comprovada.

---

## Phase 11: Polish & Cross-Cutting

- [X] T043 [P] Validate SC-012 end-to-end: alterar cada parâmetro de `GameConfig` e observar efeito sem mudança de código (quickstart Validação 3)
- [X] T044 [P] Performance spot-check: colisões contínuas nos 4 ambientes mantêm 60 FPS meta / 30 FPS piso; detecção sem alocação por quadro (SC-011, R1)
- [X] T045 Run full suite final (`runtest.sh --headless -a res://tests/unit`) e aceite manual US1–US8 per `quickstart.md` Validação 2 — exit 101, sem regressões
- [X] T046 [P] Update `AGENTS.md` seção "Estado atual" com SPEC-005 implementada e nova contagem de suítes

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)** → **Phase 2 (Foundational)**: obrigatório; Foundational bloqueia todas as histórias.
- **US1 (Phase 3)** depende apenas de Foundational. **US2** depende de US1 (pipeline de consequências). **US4** depende de US1 (`DriftState`). **US3** depende de US1 (consequências base) — independente de US2/US4.
- **US8 (Phase 7)** pode rodar após US1; idealmente após US1–US4 para validar o conjunto completo.
- **US5** depende de US1; **US6** depende de US1 e idealmente de US5 (semântica "zero eventos sob cooldown"); **US7** depende apenas de Foundational.
- **Polish (Phase 11)** por último.

```text
Setup → Foundational → US1 ─┬─ US2 ─┐
                            ├─ US3 ─┤
                            ├─ US4 ─┼─ US5 ─ US6 ─┐
                            └─ US8 ─┴─────────────┴─ Polish
                     (US7 paralela a partir de Foundational)
```

### Parallel Opportunities

- Setup: T002 ∥ T003 (mesma arquivo, seções distintas — executar sequencial se houver conflito de edição; T001 independente).
- Foundational: T006 ∥ T007 ∥ T008 após T005; T009–T011 sequenciais no mesmo arquivo.
- Por história: todas as tarefas de teste são [P] entre si; testes de histórias distintas (T012–T014 ∥ T020 ∥ T023 ∥ T027 ∥ T033 ∥ T037 ∥ T040) podem ser escritos em paralelo.
- US7 inteira ∥ qualquer fase de US1 em diante.

## Parallel Example: User Story 1

```text
# Escrever as 3 suítes em paralelo:
Task: "Detection suite in tests/unit/collision_detection_test.gd"       (T012)
Task: "Classification suite in tests/unit/collision_classification_test.gd" (T013)
Task: "Drift suite (US1) in tests/unit/collision_drift_test.gd"         (T014)
# Depois, implementação sequencial (mesmos arquivos):
T015 → T016 → T017 → T018 → T019
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 → Phase 2 → Phase 3 (US1).
2. **STOP e validar**: T012–T014 verdes + cenário manual traseira esquerda/direita (quickstart 2.1).
3. Já há gameplay novo jogável: colisão com perda de velocidade e drift.

### Incremental Delivery

US1 (MVP) → US3 (ultrapassagem, maior valor visual) → US2 (lateral) → US4 (recuperação completa) → US8 (guarda de regressão) → US5 (robustez) → US6 (contrato de eventos) → US7 (independência de sprite) → Polish. Cada fase termina em incremento testável sem quebrar as anteriores.

## Notes

- Formato estrito: `- [ ] T### [P?] [US#?] descrição com caminho de arquivo`.
- Suítes existentes (13) nunca são modificadas — SC-010 exige regressão zero.
- Todos os valores de ajuste vivem em `GameConfig` (FR-035); nenhum magic number em lógica.

---

## Phase 12: Convergence

- [X] T048 Fazer `DriftState.iniciar()` entrar na fase IMPACTO e transitar para DRIFT no `update()` seguinte, completando a sequência normal → impacto → drift → recuperação → normal em src/collision/drift_state.gd per FR-015 (partial)
- [X] T047 [P] Adicionar casos com limites variáveis por altura (callable simulando transição 2↔4 vias) para drift do jogador e deslocamento de ultrapassagem do NPC em tests/unit/collision_drift_test.gd e tests/unit/collision_overtake_test.gd per FR-023, SC-007, US3-CA4 (partial)

---

## Phase 13: Ajustes pós-implementação (testes manuais — 2026-10-05)

> 6 ajustes pedidos pelo usuário durante o aceite manual. Ajustes 1–3 e 5 pertencem ao
> domínio do trânsito (spec do SPEC-004, ver clarificações de 2026-10-05 daquela spec);
> ajustes 4 e 6 são da SPEC-005 (FR-036/SC-013 e FR-019/FR-021/SC-014). Todos validados:
> 24 suítes, 160 casos verdes.

- [X] T049 [P] Ajuste 1 — separação no nascimento: `traffic_min_separation` em `src/config/game_config.gd` + checagem retangular `_separacao_respeitada`/`_sortear_faixa_separada` em `src/traffic/traffic_manager.gd`, com suíte nova `tests/unit/test_traffic_separation.gd` per FR-019 (SPEC-004)
- [X] T050 Ajuste 2 — `_lider_mais_proximo()` em `src/traffic/traffic_manager.gd` passa a contar apenas o líder do mesmo corredor lateral (folga X ≥ `traffic_min_separation`), preservando a velocidade da categoria em corredores distintos; teste legado SC-006 de 10 min em `tests/unit/test_memory_stability.gd` ajustado para o novo invariante per FR-007, FR-011, SC-029 (SPEC-004)
- [X] T051 Ajuste 3 — densidade mínima: `traffic_min_visible` (3), `traffic_max_visible_by_difficulty` (teto 5), `traffic_spawn_interval_filling`, `traffic_spawn_distance_variance` e `traffic_spawn_fill_distance` em `src/config/game_config.gd`; contagem `_contar_na_pista()` (margem `MARGEM_PISTA`), teto sobre ativos e reposição imediata por quadro em `src/traffic/traffic_manager.gd`; suíte nova `tests/unit/test_traffic_density.gd` (3 casos) per FR-063, FR-064, SC-028 (SPEC-004)
- [X] T052 Ajuste 3 — exceção de enchimento: `_tentar_spawn(em_enchimento)` pula o espaçamento longitudinal completo mantendo a separação retangular, nascendo a `traffic_spawn_fill_distance` acima da tela; teste FR-019 legado `test_no_immediate_overlap_after_spawn` em `tests/unit/test_traffic_manager.gd` atualizado para o novo contrato (70 px no fluxo normal, separação retangular no enchimento) per FR-019 (SPEC-004)
- [X] T053 Ajuste 4 — bloqueio da aceleração pós-colisão: `collision_accel_lockout_time` em `src/config/game_config.gd`; campo `aceleracao_bloqueada` com decremento por quadro, frenagem válida e reset em `src/player/vehicle_controller.gd`; arming em `src/collision/collision_system.gd::_processar_colisao`; suíte nova `tests/unit/collision_accel_lockout_test.gd` (7 casos) per FR-035, FR-036, SC-013
- [X] T054 [P] Atualização documental dos ajustes 1–4: clarificações, FR-063/FR-064, SC-006/SC-028/SC-029, caso de borda e FR-019/FR-023 em `specs/004-traffic-and-decoration/spec.md`; clarificações, FR-036, SC-013 e parâmetros em `specs/005-collision-drift-system/spec.md`; contrato `contracts/consumed_apis.md` §3 (v1.1), `data-model.md` §5, `plan.md`, `quickstart.md` (ambas as specs) e contagens em `AGENTS.md`
- [X] T055 Ajuste 5 — travamento de velocidade entre categorias: faixas laterais reservadas por velocidade (`_slot_da_categoria`), corredor lateral = interseção das projeções laterais em `_lider_mais_proximo()` e piso de espaçamento size-aware (meias-alturas + `traffic_min_separation`) em `_espaco_min_centros()` em `src/traffic/traffic_manager.gd`; invariante SC-006 atualizado em `tests/unit/test_memory_stability.gd` e suíte nova `tests/unit/test_traffic_speed_ordering.gd` (2 casos) per FR-019, FR-065, SC-006, SC-030 (SPEC-004)
- [X] T056 [P] Atualização documental do ajuste 5: clarificações, FR-065, SC-030 e caso de borda em `specs/004-traffic-and-decoration/spec.md`; clarificação de redirecionamento em `specs/005-collision-drift-system/spec.md`; tabela de ajustes e contagens em `plan.md`, `quickstart.md` (ambas as specs), checklist da SPEC-004 e `AGENTS.md`
- [X] T057 Ajuste 6 — retorno do NPC à faixa após a ultrapassagem: `npc_overtake_return_duration` em `src/config/game_config.gd`; fases IDA/RETORNO com `x_origem` em `src/collision/npc_overtake_state.gd`; retorno clampado nos limites vigentes + encerramento ao reocupar a origem em `src/traffic/traffic_vehicle.gd::_aplicar_overtake` (captura do `x_origem` em `apply_overtake_offset`); `tests/unit/collision_overtake_test.gd` atualizado para ida+retorno e +2 casos (`test_overtake_returns_to_original_lane`, `test_overtake_clamped_out_still_returns_to_lane`) per FR-019, FR-021, SC-014
- [X] T058 [P] Atualização documental do ajuste 6: clarificações (bug de velocidades + sinal da regra mantido), FR-019/FR-021/FR-035, SC-014, caso de borda e entidade Key em `specs/005-collision-drift-system/spec.md`; contrato `contracts/consumed_apis.md` §4 (v1.2), `data-model.md` §4/§5, `plan.md`, `quickstart.md`, checklist da SPEC-005 e contagens em `AGENTS.md`
