# Tasks: Menu de Configurações Aprimorado e Menu Principal Dinâmico

**Input**: Design documents from `/specs/012-settings-and-menu-demo/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Incluídos — exigidos pela Clarificação Q3 da spec (ciclo de ambientes, validação/recuperação de preferências e limite/reciclagem de NPCs cobertos por suíte automatizada) e pela constituição §Testes (cobertura de lógica determinística de spawn/reciclagem/seleção). Os Testes manuais A–I da spec §6 ficam no quickstart.

**Organization**: Tarefas agrupadas por user story (US1 P1 → US2 P2 → US3 P3 → US4 P4), permitindo implementação e validação independentes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Paralelizável (arquivos diferentes, sem dependências entre si)
- **[Story]**: US1…US4 conforme `spec.md`

## Path Conventions

Projeto único Godot: `src/` e `tests/unit/` na raiz; cena única `src/game/gameplay.tscn`; configuração em `src/config/game_config.gd` (autoload); orquestração em `src/game/gameplay_manager.gd`.

---

## Phase 1: Setup (Infraestrutura Compartilhada)

**Purpose**: Parâmetros centralizados e strings que todas as stories usam (FR-022, research R8)

- [X] T001 Estender `src/config/game_config.gd` com o bloco `## Preferências e Demonstração (SPEC-012)`: chaves `preferencias_arquivo`, `preferencias_padrao_audio`, `preferencias_resolucoes`, `preferencias_resolucao_padrao`, `demo_duracao_ambiente`, `demo_fade_escurecer`, `demo_fade_clarear`, `demo_npc_max`, `demo_npc_intervalo`, `demo_velocidade`, `demo_ui_scrim_alpha` (valores-padrão do research R8) + 8 chaves novas em `ui_strings` (`settings`, `settings_title`, `audio_label`, `audio_on`, `audio_off`, `resolution_label`, `resolution_640`, `resolution_1024`)

---

## Phase 2: Foundational (Pré-requisitos Bloqueantes)

**Purpose**: Domínio de preferências com validação/recuperação — base de US1 e US2

**⚠️ CRITICAL**: Nenhuma story pode começar antes desta fase

- [X] T002 [P] Criar suíte `tests/unit/preferences_manager_test.gd` (GdUnit4, padrão `extends GdUnitTestSuite` + caminho temporário injetado no construtor, limpeza em `before/after_test`): round-trip gravação/carga, arquivo ausente ⇒ defaults sem gravação, JSON corrompido ⇒ defaults, `versao` desconhecida ⇒ todos os defaults, campo inválido individual (resolucao fora do conjunto / audio não-bool) ⇒ recuperação parcial preservando o campo válido, `definir_resolucao` inválido ⇒ no-op total (RED — implementar contra `contracts/preferences_manager_api.md` §1–2)
- [X] T003 Implementar `src/config/preferences_manager.gd` (`class_name PreferencesManager extends RefCounted`): campos `audio_ativo`/`resolucao` com defaults do `GameConfig`, `_init(caminho = GameConfig.preferencias_arquivo)` criando o `SaveManager` par, `carregar()` com validação campo a campo (nunca grava), `salvar()`, `definir_audio_ativo`/`definir_resolucao` (mutam + gravam; inválido ⇒ no-op), `dados_para_salvar()` no esquema v1 (data-model §2, research R1) — verde no T002

**Checkpoint**: Fundação pronta — US1 e US2 podem começar (em paralelo entre si)

---

## Phase 3: User Story 1 — Desligar e religar todo o áudio pelas configurações (Priority: P1) 🎯 MVP

**Goal**: Opção de áudio ligado/desligado no novo painel de configurações, mute central imediato de todos os sons, preferência persistida e restaurada na inicialização (RF-001, FR-001…FR-003, FR-007…FR-010)

**Independent Test**: Abrir Configurações a partir do menu, alternar `Áudio` → nenhum som audível em menu/corrida e sons voltam ao reativar; reiniciar o jogo → preferência restaurada (quickstart §3.1)

### Tests for US1

- [X] T004 [P] [US1] Criar suíte `tests/unit/audio_settings_test.gd`: `AudioManager.set_geral_ativo(false)` ⇒ bus Master (`AudioServer.bus_get_name(0)`/mute) mudo; `true` ⇒ restaurado; chamadas repetidas idempotentes; `geral_ativo()` reflete o último estado (RED; seguro em headless — dummy driver)

### Implementation for US1

- [X] T005 [P] [US1] Estender `src/audio/audio_manager.gd` com `set_geral_ativo(ativo: bool)` / `geral_ativo() -> bool` aplicando `AudioServer.set_bus_mute(0, not ativo)` (research R2; sem `_process`, sem tocar pools/vozes) — verde no T004
- [X] T006 [US1] Criar suíte `tests/unit/settings_menu_test.gd`: navegação menu → Configurações (linha nova), alternância de áudio emite `settings_audio_alterado` com o valor esperado, `ui_cancel`/`Voltar ao menu` fecha e emite `close_settings`, painel reflete o `PreferencesManager` passado no `setup` (RED antes de T007)
- [X] T007 [US1] Estender `src/ui/ui_manager.gd`: sinais novos `open_settings`, `close_settings`, `settings_audio_alterado(ativo: bool)`; `setup(p_track, p_state, p_preferencias = null)` com 3º parâmetro **opcional** (R9); construir `_painel_configuracoes` em `_construir_paineis()` com linhas `Áudio` (alterna Ligado/Desativado via `ui_accept`/`ui_left`/`ui_right`) e `Voltar ao menu` (`ui_accept`/`ui_cancel` ⇒ `close_settings`); adicionar a 4ª linha `Configurações` ao `_painel_menu` (índice 2, "Iniciar corrida" passa a 3) ajustando `_posicionar_destaque_menu`, `_marcar_opcoes` e `_process_menu` no padrão existente; exibir estado inicial a partir das preferências ou defaults do `GameConfig` (contracts `settings_menu_commands.md` §1–4); **adaptar `tests/unit/difficulty_menu_selector_test.gd` à nova estrutura de 4 linhas** — `wrapi(0,4)`, novas coordenadas do `_destaque_menu` e `start_race` no índice 3 (o teste legado assere hoje o menu de 3 linhas; esta é a única alteração intencional em teste legado) — verde no T006
- [X] T008 [US1] Estender `src/game/gameplay_manager.gd`: campos `preferencias`/`menu_demo` (nulos com guards `if campo:`); no `_ready()`: `preferencias = PreferencesManager.new()` → `carregar()` → `audio_manager.set_geral_ativo(preferencias.audio_ativo)` após criar o `AudioManager`; conectar os 3 sinais novos da UI — `settings_audio_alterado` ⇒ `preferencias.definir_audio_ativo` + `audio_manager.set_geral_ativo` (guard `if audio_manager:`/`if preferencias:`) — e `open_settings`/`close_settings` com no-op temporário até US4 (guard `if menu_demo:`)

**Checkpoint**: US1 funcional e testável de forma independente (áudio ligado/desligado + persistência)

---

## Phase 4: User Story 2 — Escolher a resolução da janela nas configurações (Priority: P2)

**Goal**: Alternância 640 × 480 / 1024 × 768 aplicada imediatamente em janela fixa, persistida e restaurada na inicialização (RF-002, FR-004…FR-009)

**Independent Test**: Alternar resolução nas configurações → janela muda na hora, centralizada e não redimensionável; menu/corrida íntegros nas duas; reiniciar → resolução salva (quickstart §3.2–3.3)

### Tests for US2

- [X] T009 [P] [US2] Estender `tests/unit/settings_menu_test.gd` com casos de resolução: alternância emite `settings_resolucao_alterada` somente com valores de `GameConfig.preferencias_resolucoes`, linha de resolução reflete a preferência carregada, trocar resolução não emite sinais de corrida (RED antes de T010)

### Implementation for US2

- [X] T010 [US2] Estender `src/ui/ui_manager.gd` com a linha `Resolução` no `_painel_configuracoes` (índice 1), alternando entre `GameConfig.preferencias_resolucoes` e emitindo `settings_resolucao_alterada(res)`; rótulos via `ui_strings.resolution_640/1024` (contracts `settings_menu_commands.md` §3) — verde no T009
- [X] T011 [US2] Estender `src/game/gameplay_manager.gd` com `_aplicar_resolucao(res: Vector2i)` (guarda `DisplayServer.get_name() == "headless"` ⇒ no-op; `window_set_size` + recentralização — research R3), aplicação no `_ready()` após `preferencias.carregar()` e no handler de `settings_resolucao_alterada` junto de `preferencias.definir_resolucao`
- [X] T012 [P] [US2] Ajustar `project.godot`: `window/size/resizable=false` (janela fixa, Clarificação Q2/research R3) — arquivo único, sem conflito com T007/T011

**Checkpoint**: US1 + US2 funcionais — Parte A da spec completa

---

## Phase 5: User Story 3 — Demonstração de corrida com os quatro ambientes no menu principal (Priority: P3)

**Goal**: Menu principal com fundo animado — estrada rolando, fundo e decoração do ambiente, ciclo Planície → Deserto → Floresta → Gelo → Planície com fade suave e título/opções legíveis (RF-004…RF-006, RF-010, FR-011…FR-015, FR-020)

**Independent Test**: Abrir o menu → demo inicia sozinha em Planície e cicla os 4 ambientes com transição suave; iniciar corrida durante fade → demo encerra sem tela escura (quickstart §4.1–4.2)

### Tests for US3

- [X] T013 [P] [US3] Criar suíte `tests/unit/menu_demo_test.gd` (instancia `MenuDemo.new()` + add_child; avanço de tempo via chamadas diretas de `_process(delta)`): ordem do ciclo `PLAINS→DESERT→FOREST→ICE→PLAINS` (`ambiente_atual()`), duração respeitando `demo_duracao_ambiente` (config temporário), `GameConfig.current_environment_id` **inalterado** após ciclos (isolamento), `encerrar()` ⇒ `esta_ativo()==false` e alpha do fade 0 (RED — implementar contra `contracts/menu_demo_lifecycle.md`)

### Implementation for US3

- [X] T014 [US3] Criar `src/menu/menu_demo.gd` (`class_name MenuDemo extends Node2D`): estados `PARADA/EXECUTANDO/PAUSADA` com API `iniciar/pausar/retomar/encerrar/esta_ativo/ambiente_atual` (data-model §3, contracts `menu_demo_lifecycle.md` §1–2); `iniciar()` sempre reinicia em `PLAINS`; criação das instâncias próprias `Road.new()` (`reset()` + `update_scroll_speed(demo_velocidade)`) e `BackgroundController.new()` (`reset()` + `set_texture(ENVIRONMENTS[id].texture_path)` + `update_scroll(demo_velocidade × background_multiplier, delta)`); troca de ambiente por índice local `% environment_sequence.size()` a cada `demo_duracao_ambiente` — verde nos casos de ciclo/isolamento do T013
- [X] T015 [US3] Em `src/menu/menu_demo.gd`: fade com `_fade_rect` (`ColorRect` preto tela cheia no canvas de mundo, alpha 0) e um `Tween` por transição — `alpha 0→1` (`demo_fade_escurecer`) ⇒ callback de troca de ambiente ⇒ `alpha 1→0` (`demo_fade_clarear`); `pausar()`/`encerrar()` matam o tween e forçam alpha 0 (SC-005, research R7); cobrir na suíte o caso "encerrar durante transição ⇒ alpha 0"
- [X] T016 [US3] Em `src/menu/menu_demo.gd`: instância própria de `DecorationManager.new()` com `setup(DECORATION_LIBRARIES)` + `set_environment(id)` na troca + `update(delta, road)` no `_process` (research R5; sinais do decoration **não** conectados — demo não emite eventos de gameplay)
- [X] T017 [P] [US3] Estender `src/ui/ui_manager.gd` com `_fundo_menu` (`ColorRect` tela cheia, alpha `GameConfig.demo_ui_scrim_alpha`, primeiro filho do root da UI, atrás dos textos e acima da demo) visível apenas nas telas do menu/configurações (contracts `settings_menu_commands.md` §5, RF-010)
- [X] T018 [US3] Estender `src/game/gameplay_manager.gd`: criar `menu_demo = MenuDemo.new()` + `add_child` no `_ready()` (último filho de mundo, antes do `_show_menu()` final); `menu_demo.iniciar()` em `_show_menu()`; `menu_demo.encerrar()` em `_show_ready/_show_playing/_show_paused/_show_victory/_show_game_over` (todos sob `if menu_demo:`)

**Checkpoint**: US3 funcional — menu com demonstração ciclando os 4 ambientes e fade

---

## Phase 6: User Story 4 — Demonstração isolada do gameplay e com ciclo de vida alinhado à navegação (Priority: P4)

**Goal**: 2–4 NPCs da demo com velocidade fixa independente da dificuldade, reciclagem limpa, pausa/retomada ao abrir/fechar configurações, zero efeitos em combustível/pontuação/recordes/troféus (RF-007…RF-009, RF-011, FR-016…FR-019)

**Independent Test**: 5 min de menu com contagem de NPCs sempre 2–4; 20 alternâncias menu⇄corrida sem acúmulo; Configurações pausa e retoma a demo sem reiniciar o ciclo; estado persistente do jogador inalterado (quickstart §4.3–4.4)

### Tests for US4

- [X] T019 [P] [US4] Estender `tests/unit/menu_demo_test.gd`: NPCs ≤ `demo_npc_max` após vários `update`; NPC que cruza a borda inferior é reciclado (`npc_ativos()` diminui); `iniciar()→encerrar()→iniciar()` nunca acumula (contagem volta ao inicial); `pausar()` congela posição dos NPCs e `retomar()` retoma; velocidade dos NPCs idêntica com `DifficultyManager` em modos diferentes (FR-017); **isolamento de dados**: após ≥2 ciclos completos de ambiente com a demo ativa, um `ProgressManager` sintético (snapshot inicial) e um `FuelSystem` sintético (carga inicial) permanecem com `dados_para_salvar()`/estado **idênticos** (guarda de regressão contra wiring futuro indevido — SC-009 automatizada)

### Implementation for US4

- [X] T020 [US4] Em `src/menu/menu_demo.gd`: pool fixa de até `demo_npc_max` `TrafficVehicle` criada em `iniciar()`; reposição a cada `demo_npc_intervalo` sorteando categoria de `TRAFFIC_CATEGORIES`, X dentro dos limites da pista com separação ≥ `traffic_min_separation` de outros ativos (tentativas limitadas); movimento `y += demo_velocidade × delta` (sem `fator_dificuldade`); reciclagem (`deactivate`) ao cruzar a borda inferior; **sem** conexão com `AudioManager` (menu silencioso) — verde no T019
- [X] T021 [US4] Estender `src/game/gameplay_manager.gd`: handlers dos sinais `open_settings` ⇒ `menu_demo.pausar()` e `close_settings` ⇒ `menu_demo.retomar()` (substituindo os no-ops do T008; guards `if menu_demo:`)
- [X] T022 [P] [US4] Estender `tests/unit/settings_menu_test.gd` com o fluxo de navegação: abrir Configurações com um `MenuDemo` real (ou stub) ⇒ pausado; fechar ⇒ retomado; iniciar corrida durante pausa ⇒ `encerrar()` sem resíduos (SC-005/SC-007)

**Checkpoint**: Todas as stories funcionais e independentes

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Regressão, aceite manual e calibração

- [X] T023 Rodar a suíte completa `GODOT_BIN=<godot> bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit` — exigir **exit 101** com os casos legados intactos, **salvo as adaptações intencionais de `difficulty_menu_selector_test.gd` previstas no T007** (menu de 4 linhas), + suítes novas verdes; investigar qualquer regressão fora desse escopo antes de seguir
- [X] T024 Executar o aceite manual do `quickstart.md` §3–§4 (Testes A–I da spec) e registrar o resultado (sucesso/achados) nesta seção ao final da implementação
  - **Registro — 2026-10-18 (1ª rodada do usuário)**: Testes A–I executados; **2 achados**, ambos corrigidos nesta data e aguardando revalidação:
    1. **Road invisível na demo** (Teste D/step 13 — sem o asset `estrada_2_vias.png`): causa — `_ensure_estrutura` criava `Road` ANTES do `BackgroundController`, e o fundo (tela cheia) cobria o asfalto; o `gameplay.tscn` usa Background → Decoration → Road. Correção: ordem dos filhos da demo espelhando o `gameplay.tscn`; regressão automatizada `menu_demo_test.gd` test_13 (verificada RED com a ordem antiga).
    2. **`Embedded window can't be resized`** (Teste B/step 6): limitação da janela embutida do editor (Godot 4.4+); corrigido com guard `Engine.is_embedded_in_editor()` em `_aplicar_resolucao` (no-op silencioso — a preferência é persistida e vale em janela standalone/exportada); nota adicionada no quickstart §3.2.
  - **Revalidação — 2026-10-18 (2ª rodada do usuário)**: os 2 itens corrigidos foram revalidados com **sucesso** ("os problemas foram resolvidos"); nenhum achado novo. **T024 concluído.**
  - §4/§5 (calibração): o usuário **não** apontou problemas de balanceamento/visual (scrim, velocidades, intervalos) — nenhum valor de calibração ajustado.
- [X] T025 Se o §4 do quickstart apontar problema visual/desempenho, calibrar `demo_velocidade`, `demo_npc_intervalo`, `demo_duracao_ambiente`, fades ou `demo_ui_scrim_alpha` (tabela quickstart §5) e registrar os valores ajustados em `tasks.md` — **não acionado** (1ª rodada do aceite: nenhum problema de calibração; os 2 achados do T024 eram funcionais e corrigidos no código)
- [X] T026 Revisão final: guards `if campo:` em todos os campos novos do `gameplay_manager.gd`; zero números mágicos (tudo no `GameConfig`); literais de usuário só em `ui_strings`; docstrings/comentários em pt-BR; `gameplay.tscn` intocado; atualizar o bloco "Estado atual" do `AGENTS.md` com o status da SPEC-012; diff focado

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências — começa imediatamente
- **Foundational (Phase 2)**: depende do T001 (defaults/validos no `GameConfig`) — **bloqueia US1 e US2**
- **US1 (Phase 3)**: depende do Foundational; **MVP**
- **US2 (Phase 4)**: depende do Foundational; integra com US1 (painel/sinais compartilhados) mas é testável de forma independente
- **US3 (Phase 5)**: independente de US1/US2 no domínio (só usa `game_config.gd`); o wiring no `gameplay_manager.gd`/`ui_manager.gd` compartilha arquivos com US1/US2 — executar **depois** de US1/US2 para evitar conflito de edição
- **US4 (Phase 6)**: depende de US3 (estende `menu_demo.gd` e os sinais de navegação)
- **Polish (Phase 7)**: depende de todas as stories desejadas

### User Story Dependencies

- **US1 (P1)**: após Foundational — sem dependências das demais stories
- **US2 (P2)**: após Foundational — integra com US1 via painel/sinais já criados no T007
- **US3 (P3)**: pode ser desenvolvida em paralelo conceitual com US1/US2 (arquivos próprios `menu_demo.gd`), mas o wiring orquestrado espera US1/US2 consolidados
- **US4 (P4)**: após US3

### Within Each User Story

- Suítes novas (marcadas [P]) são escritas **antes** da implementação correspondente (RED → GREEN)
- Componentes (`menu_demo.gd` partes) seguem ordem: estrutura/ciclo → fade → decoração → NPCs
- Integração no orquestrador sempre por último na story

### Parallel Opportunities

- T002 (suíte de preferências) e T001 (GameConfig) — arquivos distintos, mas T002 depende das chaves do T001 na hora de rodar; ideal sequencial curto T001 → T002
- T004 (suíte de áudio) ∥ T005 (AudioManager) — escrita paralela; T005 fecha o RED do T004
- T009 ∥ T010-T011; T012 é isolado em `project.godot` (paralelizável com qualquer task de US2)
- T013 ∥ T014; T017 é isolado no `ui_manager.gd` (paralelizável com T014–T016, que vivem em `menu_demo.gd`)
- T019 ∥ T020; T022 é isolado na suíte de UI

---

## Parallel Example: User Story 3

```bash
# Suíte RED e implementação estrutural em paralelo (arquivos distintos):
Task: "tests/unit/menu_demo_test.gd — ciclo/ isolamento/ encerrar (T013)"
Task: "src/menu/menu_demo.gd — estados + Road/Background + ciclo (T014)"
# Depois, em sequência curta dentro do mesmo arquivo:
Task: "fade Tween (T015)" → "DecorationManager (T016)"
# Paralelo com a story (arquivo de UI):
Task: "src/ui/ui_manager.gd — véu _fundo_menu (T017)"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 (T001) + Phase 2 (T002–T003) → fundação
2. Phase 3 (T004–T008) → **validar manualmente** o Teste A do quickstart §3.1
3. **PARAR e VALIDAR**: áudio ligado/desligado funcional e persistido

### Incremental Delivery

1. Setup + Foundational → preferências testadas
2. US1 → MVP (Teste A)
3. US2 → Parte A completa (Testes B–C)
4. US3 → demonstração visível com ciclo + fade (Testes D–E)
5. US4 → NPCs/Isolamento/ciclo de vida (Testes F–H)
6. Polish → suíte completa + Teste I + calibração (exit 101)

### Notas

- Cada story fecha um incremento verificável sem regressar as anteriores; commits por task ou grupo lógico (constituição §Disciplina de Git)
- Os 478 testes legados seguem intactos (garantia R12), **salvo a única adaptação intencional de `difficulty_menu_selector_test.gd` prevista no T007** (menu passa de 3 para 4 linhas); qualquer outro ajuste é regressão a investigar em T023
