# Research — Menu de Configurações Aprimorado e Menu Principal Dinâmico (SPEC-012)

Fase 0 do `/speckit.plan`. Todos os `NEEDS CLARIFICATION` do Technical Context estão resolvidos abaixo. As verificações de código citadas foram feitas sobre o estado real do repositório (branch `012-settings-and-menu-demo`, inspeção de 2026-10-18).

## R1 — Persistência: reutilizar o `SaveManager` com caminho próprio `user://preferencias.json`

**Decision**: As preferências (áudio + resolução) são um **arquivo separado** `user://preferencias.json`, gravado/carregado pelo **próprio `SaveManager`** já existente (`src/save/save_manager.gd`), instanciado com o caminho novo: `SaveManager.new(GameConfig.preferencias_arquivo)`. O `SaveManager` **não recebe nenhuma mudança** — o construtor já aceita caminho injetável (hoje usado pelos testes). O domínio (defaults, validação, recuperação) vive no novo `PreferencesManager` (`src/config/preferences_manager.gd`, `RefCounted`), que segura uma instância do `SaveManager` como o `GameplayManager` faz hoje. Esquema v1: `{"versao": 1, "audio": true, "resolucao": [640, 480]}`.

**Rationale**: É exatamente a Clarificação Q1 da spec (arquivo próprio, mesmo mecanismo) e o FR-010 ("sem segunda solução paralela"): zero código de I/O novo — escrita atômica (tmp + rename com checagem de erro) e carregamento tolerante (`{}` em ausente/inválido, nunca grava no carregar) já vêm de graça e estão cobertos pela suíte legada `save_manager_test.gd`. Separar de `progresso.json` isola domínios (preferências de máquina × progresso do jogador): falha ao salvar configuração não pode tocar recordes, e um eventual reset de progresso não perde preferências. Validação campo a campo no `PreferencesManager` permite recuperação **parcial** (ex.: resolução inválida, áudio válido → só a resolução volta ao padrão).

**Alternatives considered**: *Ampliar `progresso.json`* — rejeitado (Q1 opção B; mistura domínios e acopla preferências a gravações de encerramento de corrida); *`ConfigFile` nativo (INI)* — rejeitado (segunda solução de persistência paralela ao `SaveManager`, formato com tipagem fraca; a constituição favorece mudanças mínimas sobre infraestrutura nova); *salvar direto no `GameplayManager`* — rejeitado (I/O espalhado no orquestrador, sem domínio testável).

## R2 — Áudio geral: mute do bus Master via `AudioManager.set_geral_ativo()`

**Decision**: `AudioManager` ganha `set_geral_ativo(ativo: bool)` / `geral_ativo() -> bool`, que aplicam `AudioServer.set_bus_mute(0, not ativo)` no **bus Master** (índice 0). Aplicação **imediata** (chamada direta, sem `_process`), central (cobre efeitos atuais e futuros — RF-001) e persistida por R1. No `_ready` do `GameplayManager`, após `configurar(cfg)`, aplica-se a preferência carregada. Reativar o áudio restaura a audibilidade sem recriar nada: as vozes/pools do SPEC-010 continuam em seus estados (`playing`), o mute apenas as silencia.

**Rationale**: O mute no bus é o mecanismo nativo da engine exatamente para "todos os sons de uma vez" — nenhuma fonte é tocada individualmente (RF-001: "evitar alterar individualmente cada fonte") e qualquer som novo adicionado ao sistema centralizado no futuro nasce já coberto. O `AudioManager` já é o dono centralizado de áudio (SPEC-010) e não tem `_process` (invariante preservado). Verificação de inspeção: hoje **não existe** nenhum uso de `AudioServer`/mute em `src/` — o gate é genuinamente novo e pequeno (2 métodos).

**Alternatives considered**: *Parar todas as vozes ao desativar* — rejeitado (perde o estado dos loops de motor, exige reimplementar retomada por fonte, efeitos e gates; múltiplos call sites); *Volume por fonte/efeito* — rejeitado (não é centralizado, viola RF-001 para sons futuros); *Desabilitar chamadas em cada ponto de reprodução* — rejeitado (tocaria cada call site do SPEC-010, acoplamento amplo); *Autoload de áudio* — rejeitado (autoloads novos fora do padrão do projeto).

## R3 — Resolução: viewport base fixo 640 × 480 + tamanho de janela via `DisplayServer`; janela não redimensionável

**Decision**: O **viewport base nunca muda** (`viewport_width/height = 640 × 480` em `project.godot`). A preferência de resolução controla apenas o **tamanho da janela**: `DisplayServer.window_set_size(Vector2i(640,480))` ou `(1024,768)`, com recentralização (`window_set_position` calculado do `screen_size` atual). O `stretch/mode="viewport"` já declarado + aspecto `keep` (default da engine, não declarado ⇒ `keep`) escala o canvas 4:3 para a janela: 1,0× em 640 × 480 e 1,6× em 1024 × 768, **sem distorção** e com o **mesmo layout de interface** (o canvas é sempre 640 × 480) — logo a legibilidade e a acessibilidade dos controles (SC-008, FR-006) são idênticas por construção nas duas resoluções. Tamanho fixo: `project.godot` ganha `window/size/resizable=false` (declarativo). Aplicação na inicialização (`_ready`, antes do primeiro menu) e a cada troca na UI. `aplicar_resolucao()` é protegida em headless (`DisplayServer.get_name() == "headless"` ⇒ no-op) para a suíte **e na janela embutida do editor** (`Engine.is_embedded_in_editor()` ⇒ no-op silencioso — o motor rejeita resize com `Embedded window can't be resized`; a preferência é persistida e vale em janela standalone/exportada; limitação constatada e anotada no aceite T024, 2026-10-18).

**Rationale**: Com `stretch=viewport`, mudar só a janela é a alavanca mínima que satisfaz RF-002/FR-005/FR-006 sem tocar em estado de jogo: sprites pixel art mantêm escala inteira por preset de filtro `nearest` (já em `project.godot`), nenhum elemento é reposicionado (o layout é do canvas fixo) e não há "terceiro estado" de tamanho livre que foge aos critérios de aceitação (Clarificação Q2). Janela não redimensionável evita escalonamento arbitrário e mantém a preferência como única fonte de tamanho.

**Alternatives considered**: *Trocar `viewport_width/height` conforme a preferência* — rejeitado (mudaria o layout canônico do jogo: todos os posicionamentos fixos da UI, limites da pista e hitboxes estariam calibrados para 640 × 480; re-render/reposicionamento arriscado e desnecessário); *janela livremente redimensionável* — rejeitado (Q2 opção B; cria estados de tela não testados e escalonamento não inteiro em qualquer largura); *`content_scale_factor`/escala de canvas* — rejeitado (segundo mecanismo de escala paralelo ao `stretch` já configurado).

## R4 — Tela de configurações: novo painel no `UIManager` + linha "Configurações" no menu; sem estado novo no `GameState`

**Decision**: `UIManager` ganha `_painel_configuracoes` construído em `_construir_paineis()` (mesmo padrão dos painéis existentes) com: linha `Áudio: Ligado/Desativado`, linha `Resolução: 640 × 480 / 1024 × 768` (alternância com `ui_left`/`ui_right` ou `ui_accept`), linha `Voltar ao menu` (reusa `ui_strings.back_to_menu`). O `_painel_menu` ganha a **4ª linha** "Configurações" (índice 3), com o `_destaque_menu` reposicionado; navegação segue o padrão `ui_up`/`ui_down` + `wrapi` + `_marcar_opcoes`. `ui_cancel` no painel de configurações volta ao menu principal. Estados de tela resolvidos **dentro do `UIManager`** (quem controla qual painel está visível) — o `GameState` permanece em `MENU` e **nenhum estado novo é adicionado** (RF-009 cobre "outras telas" via sinal de visibilidade, R6).

**Rationale**: A inspeção confirmou que **não existe hoje nenhuma tela de configurações** (sem painel, string ou teste de settings) — a spec exige *ampliar a estrutura atual*, e o caminho de menor mudança é um painel no mesmo padrão dos quatro já existentes. Não adicionar estado ao `GameState` mantém intactos os seis estados exigidos pela constituição, evita rever todos os `match` de estado espalhados (UI, áudio, orquestrador) e respeita "não modificar sistemas além do necessário": quem decide a visibilidade das telas do menu já é o `UIManager` (`_aplicar_estado`).

**Alternatives considered**: *Novo estado `SETTINGS` no `GameState`* — rejeitado (toca o máquina de estados compartilhada — matches em `UIManager._aplicar_estado`, `GameplayManager._on_state_changed`, gate do áudio — para ganho zero sobre a separação de painéis; risco de regressão nos 478 testes); *menu de configurações como Cena separada* — rejeitado (o projeto tem uma única cena; telas são painéis em código por convenção consolidada); *opções embutidas nas linhas do menu principal* — rejeitado (polui o menu de 3 linhas aprovado na SPEC-009 e não deixa espaço para 2 controles + feedback).

## R5 — Demonstração: componente dedicado `MenuDemo` (Node2D) reutilizando `Road`, `BackgroundController`, `DecorationManager` e `TrafficVehicle`

**Decision**: Novo `src/menu/menu_demo.gd` (`class_name MenuDemo extends Node2D`), **criado em código** pelo `GameplayManager` no `_ready` (padrão dos demais componentes; `gameplay.tscn` intocado), adicionado como **último filho do mundo** (desenha acima do cenário de gameplay já escondido/estático, e **abaixo** do `UiLayer` em `CanvasLayer` — a UI nunca é coberta). Em `iniciar()` ele cria/reusa **instâncias próprias** dos componentes visuais existentes:

- `Road.new()` — mesma estrada de 2 vias (limites 248/392 de `GameConfig`), `update_scroll_speed(demo_velocidade)`, `reset()` a cada início;
- `BackgroundController.new()` — fundo 640 × 480 rolando (`update_scroll(demo_velocidade × background_multiplier, delta)`), textura por ambiente;
- `DecorationManager.new()` — decoração lateral reutilizando as bibliotecas `DECORATION_LIBRARIES`/`DECORATION_PATHS` do `GameConfig` (`setup` + `set_environment` + `update(delta, road)`), mesma API pública verificada;
- pool **fixa** de até `demo_npc_max = 4` `TrafficVehicle` (instâncias de script, como o trânsito real — não existe cena `.tscn` de NPC), ativadas via `activate(category, x, y)` com categorias de `TRAFFIC_CATEGORIES`, movidas **manualmente** por `y += demo_velocidade × delta` (velocidade fixa, **sem** passar por `fator_dificuldade` — FR-017) e recicladas ao cruzar a borda inferior;
- um `ColorRect` de *fade* (preto, alpha 0) no canvas de mundo — abaixo do `UiLayer`, então o *fade* nunca esconde título/opções (RF-010).

O ciclo de ambientes percorre `GameConfig.environment_sequence` (`PLAINS → DESERT → FOREST → ICE`) com índice local `% 4`; a cada troca: `BackgroundController.set_texture(env.texture_path)` + `DecorationManager.set_environment(id)`. **`GameConfig.current_environment_id` nunca é escrito pela demo** (só o orquestrador de corrida o altera) — sem efeitos na propagação de ambiente do gameplay (`_propagar_ambiente` compara por quadro e dispararia em falso).

**Rationale**: Reusa os três componentes visuais e o veículo NPC **como classes** (zero duplicação de código de estrada/scroll/decoração/sprites — RF-008), mas com **instâncias próprias** porque (a) o ciclo de vida da demo é independente do da corrida (RF-008/RF-009: iniciar/pausar/encerrar/reiniciar sem tocar nos nós de gameplay escondidos no menu), (b) o `TrafficManager` real é acoplado à dificuldade (velocidade × `fator_dificuldade`, teto por ambiente/fator, validador NPC×NPC, forwards para o `AudioManager` — um spawn real tocaria som de motor **violando a demo silenciosa**), e (c) isolar em um módulo novo mantém o `GameplayManager` orquestrando só o momento (`iniciar/pausar/retomar/encerrar`), no padrão das demais specs. A demo dirigir seu próprio `_process` elimina qualquer acoplamento com `_processar_playing`.

**Alternatives considered**: *Reusar os nós de gameplay (road/background/decoration_layer) mostrando-os no menu* — rejeitado (exporia/esconderia nós compartilhados a cada transição de estado, misturaria reset de corrida com reset de demo e criaria corridas de visibilidade entre `_show_menu`/`_show_ready`; maior risco de regressão no fluxo já estabilizado da SPEC-008); *Reusar o `TrafficManager` com fator 1* — rejeitado (acoplado à dificuldade, ao validador NPC×NPC e aos forwards de áudio — R5 acima; ~200 linhas de regras de gameplay desnecessárias para 2–4 NPCs visuais); *Demo dentro do `UIManager`* — rejeitado (misturaria UI com mundo visual, violando a responsabilidade única do `UIManager` — constituição §III); *Cena `.tscn` dedicada da demo* — rejeitado (quebra a convenção do projeto: uma única cena, telas/componentes em código).

## R6 — Integração de ciclo de vida: sinais novos da UI + ramos `_show_*` do orquestrador

**Decision**: Wiring no `GameplayManager`:

| Momento | Ação |
|---|---|
| `_ready()` | criar `PreferencesManager` (carregar + aplicar áudio/resolução), criar `MenuDemo`, conectar sinais novos da UI |
| `_show_menu()` | `menu_demo.iniciar()` |
| `_show_ready/_show_playing/_show_paused/_show_victory/_show_game_over` | `menu_demo.encerrar()` (idempotente) |
| sinal `open_settings` (UI) | `menu_demo.pausar()` |
| sinal `close_settings` (UI) | `menu_demo.retomar()` |
| sinais `settings_audio_alterado(bool)` / `settings_resolucao_alterada(Vector2i)` | atualizar `PreferencesManager` + `salvar()` + aplicar (`audio_manager.set_geral_ativo`, `aplicar_resolucao`) |

`encerrar()` mata o `Tween` de fade ativo e força alpha 0 (edge case "transição interrompida"); `iniciar()` sempre começa em `PLAINS` com alpha 0 e NPCs reciclados (RF-009 "reinicia de maneira consistente"; SC-007 sem acúmulo). Nenhum campo novo do orquestrador fica sem guard `if …:` (padrão R12/specs anteriores) para preservar os testes sintéticos que instanciam `GameplayManager` sem a cena completa.

**Rationale**: O orquestrador é o único que conhece as transições de estado (constituição §Estado de Jogo) — a demo não escuta `GameState` diretamente, exatamente como os demais sistemas (áudio, combustível) são comandados. A separação pausar/retomar (configurações) de encerrar (corrida/outra tela) preserva a demo atrás do painel de configurações sem reiniciar o ciclo a cada ida/volta (RF-009: "retoma quando o menu principal voltar a ser exibido").

**Alternatives considered**: *Demo conectada direto em `GameState.state_changed`* — rejeitado (dependência nova de ordem de conexão e duplicação do papel de orquestrador); *pausar a demo via `get_tree().paused`* — rejeitado (pausaria a UI e o jogo inteiro, quebrando a navegação do menu); *reiniciar a demo em vez de pausar ao abrir configurações* — rejeitado (corte visível e perda do ciclo, contra o "retoma quando volta").

## R7 — *Fade*: um `Tween` por transição sobre um `ColorRect` preto no canvas de mundo

**Decision**: `MenuDemo` mantém `_fade_rect: ColorRect` (tela cheia 640 × 480, preto, `modulate.a = 0`, escondido fora das transições). Transição = um `Tween` encadeado: `alpha 0 → 1` em `demo_fade_escurecer` (0,75 s) → `tween_callback` troca fundo/decoração → `alpha 1 → 0` em `demo_fade_clarear` (0,75 s) → `alpha = 0` + esconder. `encerrar()`/`pausar()` fazem `kill()` do tween e força `modulate.a = 0` (SC-005: nunca tela escura após interrupção). A interface não é bloqueada porque o `ColorRect` fica no canvas de mundo (abaixo do `CanvasLayer` da UI) e o `Tween` não pausa processamento de input.

**Rationale**: `Tween` é o mecanismo nativo de animação simples da engine (RF-006: "recursos visuais já disponíveis"), sem nó `AnimationPlayer` novo e sem estados extras; a troca no midpoint do tween garante que **nunca** dois ambientes fiquem visíveis ao mesmo tempo (a troca ocorre com alpha = 1, tela opaca). O `ColorRect` no canvas de mundo preserva RF-010 (fade não cobre controles) por ordem de desenho de `CanvasLayer`.

**Alternatives considered**: *`AnimationPlayer`/`AnimationTree`* — rejeitado (nó + recurso novos para duas propriedades escalares); *fade em escurecer/clarear por `modulate` do próprio cenário* — rejeitado (escureceria cenário e NPCs em etapas separadas, com risco de duas camadas em alpha diferente no midpoint); *Timer + troca instantânea* — rejeitado (não entrega o escurecimento/clareamento gradual exigido por RF-006).

## R8 — Configuração centralizada: blocos `preferencias_*` e `demo_*` no `GameConfig` (FR-022)

**Decision**: Novo bloco `## Preferências e Demonstração (SPEC-012)` no `game_config.gd`:

| Chave | Padrão | Uso |
|---|---|---|
| `preferencias_arquivo` | `"user://preferencias.json"` | caminho do arquivo (R1) |
| `preferencias_padrao_audio` | `true` | default (RF-001.8) |
| `preferencias_resolucoes` | `[Vector2i(640,480), Vector2i(1024,768)]` | conjunto válido (FR-004) |
| `preferencias_resolucao_padrao` | `Vector2i(640,480)` | default = resolução atual do projeto (RF-002.6) |
| `demo_duracao_ambiente` | `10.0` | entre 8 e 12 s (RF-005.2) |
| `demo_fade_escurecer` / `demo_fade_clarear` | `0.75` / `0.75` | 0,5–1 s (RF-006) |
| `demo_npc_max` | `4` | pool/limite (RF-007) |
| `demo_npc_intervalo` | `0.8` | calibração (quickstart §5) |
| `demo_velocidade` | `300.0` | cruzeiro do Normal (100 × 3,0 — Assumptions da spec) |
| `demo_ui_scrim_alpha` | `0.3` | véu de legibilidade atrás dos textos (RF-010) |

Chaves novas em `ui_strings`: `settings`, `settings_title`, `audio_label`, `audio_on`, `audio_off`, `resolution_label`, `resolution_640`, `resolution_1024` (`back_to_menu` já existe e é reusado).

**Rationale**: FR-022 e §4.4 da spec exigem parâmetros centralizados sem números mágicos; o padrão do projeto é exatamente blocos por spec no `GameConfig` (§IV da constituição). `demo_velocidade = 300` deriva do modo Normal no teto (base 100 × fator 3,0 — recalibrado na SPEC-009), atendendo à Assumptions da spec ("velocidade de cruzeiro fixa do modo Normal"); `demo_npc_intervalo = 0.8` dá ~2–3 veículos visíveis com deslocamento a 300 px/s (percurso de 480 px ≈ 1,6 s ⇒ 2 visíveis em média, clamp no máximo 4) — SC-006 (2–4) — e entra como ponto de calibração do quickstart.

**Alternatives considered**: *Constantes nos scripts* — rejeitado (viola §IV/FR-022); *autoload/config externa separada* — rejeitado (novo mecanismo de config paralelo ao `GameConfig` já consolidado).

## R9 — Áudio/resolução na inicialização e isolamento de testes legados

**Decision**: No `_ready` do `GameplayManager`: `preferencias = PreferencesManager.new()` → `carregar()` → `aplicar_resolucao()` (guarda headless) → após criar o `AudioManager`, `audio_manager.set_geral_ativo(preferencias.audio_ativo)`. Todos os campos novos (`preferencias`, `menu_demo`, e os métodos de settings) ficam sob guards `if campo:` — os testes sintéticos existentes (`ui_screens_test`, `state_flow_test`, etc.) instanciam `UIManager`/`GameplayManager` sem esses campos e continuam verdes sem nenhum ajuste. `UIManager.setup()` ganha um **3º parâmetro opcional** (`p_preferencias = null`) — as assinaturas legadas de 2 argumentos continuam válidas em GDScript.

**Rationale**: É a mesma garantia R12 das specs anteriores: a suíte de 478 casos não pode precisar de ajuste. Parâmetro opcional + guards nulos são o mecanismo já provado no projeto (camadas SPEC-008 com `get_node_or_null`, `audio_manager`/`save_manager` guardados).

**Alternatives considered**: *Passar preferências via property/autoload* — rejeitado (autoload novo e estado global extra); *exigir setup de 3 argumentos* — rejeitado (quebraria os testes legados que chamam `setup(track, state)`.

---

*Verificação pós-design (Phase 1)*: nenhum gate da constituição violado — ver `plan.md` (Constitution Check re-check) e `Complexity Tracking` vazio.
