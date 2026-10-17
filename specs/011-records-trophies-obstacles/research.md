# Research — Recordes, Persistência, Troféus, Pontuação e Obstáculos (SPEC-011)

Fase 0 do `/speckit.plan`. Todos os `NEEDS CLARIFICATION` do Technical Context estão resolvidos abaixo. Onde o veredito dependia de números, a sonda foi feita sobre o código real de `game_config.gd` e dos sistemas de referência (galões, trânsito, progressão, dificuldade) nesta mesma máquina.

## R1 — Persistência: JSON em `user://` com escrita atômica

**Decision**: O `SaveManager` grava e carrega **um único arquivo** `user://progresso.json` via `FileAccess` + `JSON.stringify/parse_string`. A gravação é **atômica por construção**: escreve em `user://progresso.json.tmp` e, só se a escrita fechar sem erro, remove o arquivo antigo e renomeia o temporário via `DirAccess.rename_absolute()`; qualquer falha no meio deixa o arquivo válido anterior intacto (edge case "falha de gravação"). O carregamento é tolerante: arquivo ausente, JSON inválido ou `parse_string` nulo ⇒ retorna `{}` (vazio) **sem tocar no arquivo** — o `ProgressManager` aplica defaults em memória e nunca regrava defaults por cima de dados só porque o parse falhou.

**Rationale**: O projeto não tem nenhum mecanismo de persistência (Assumption da spec) e a engine não oferece melhor opção nativa sem dependência: `ConfigFile` é INI (chaves aninhadas viram strings com escapes, histórico de resultados fica ilegível), `Resource.save` escreve texto-binário da engine e `user://` já é a localização canônica de dados do usuário no Godot (FR-022). O rename no mesmo diretório do `user://` é atomicamente seguro no filesystem do usuário; escrever direto no arquivo final não seria (crash no meio truncaria dados válidos). O versionamento do esquema fica no próprio JSON (`"versao": 1`) — schema completo no `data-model.md`.

**Alternatives considered**: *ConfigFile/INI* — rejeitado (histórico e dicionários por modo ficam com escape de chaves, perda de tipagem numérica na carga); *Resource .tres/.res* — rejeitado (depende de importação da engine, caminho em `res://` é read-only em build exportada); *SQLite via plugin* — rejeitado (dependência externa para 1 arquivo de ~10 campos escalares + histórico curto; violaria a disciplina de dependências); *dois arquivos (recordes + histórico)* — rejeitado (mais falhas parciais para manter coerência, sem benefício).

## R2 — Arquitetura: `SaveManager` (I/O) × `ProgressManager` (domínio)

**Decision**: Dois `RefCounted` novos, ambos sem filhos e sem árvore:

- **`src/save/save_manager.gd`** — só I/O: `carregar() -> Dictionary` e `gravar(dados: Dictionary) -> bool`, com `caminho: String` injetável no construtor (padrão `user://progresso.json`; testes apontam para `user://_gdunit_progresso_test.json` e removem no teardown). Zero conhecimento de domínio (não sabe o que é "recorde").
- **`src/game/progress_manager.gd`** — só domínio: recordes, histórico, acumulados, troféus/ciclos, desbloqueio derivado, `calcular_pontuacao()`, `processar_vitoria()`, `processar_derrota()`, `dados_para_salvar()` e `carregar_de(dados)`. Zero I/O e zero nós — o orquestrador faz a ponte: `progresso.carregar_de(save.carregar())` no `_ready`, `save.gravar(progresso.dados_para_salvar())` no encerramento.

**Rationale**: É a mesma separação que a constituição §I/§III já impõe aos demais domínios (combustível não grava, áudio não decide estado) e permite testar cada metade isoladamente: fórmula/recordes/ciclos 100% puros (matemática determinística, SC-001…SC-005) e I/O com arquivo real temporário (SC-010) sem árvore de cena. O orquestrador (único que conhece o momento de cada evento) é o dono do "quando" — igual ao wiring de áudio da SPEC-010 (R4 daquele research): nada de componente novo conectando-se sozinho a sinais.

**Alternatives considered**: *SaveManager que também faz domínio* — rejeitado (mistura I/O com regras de recorde/ciclo; testar a fórmula exigiria arquivo); *autoload `ProgressStore`* — rejeitado (autoloads novos não são introdução desta spec; os únicos são `GameConfig`/`GameState`); *ProgressManager conectado direto em `GameState.state_changed`* — rejeitado (dependência nova e ordem de conexão como fator oculto; o `GameplayManager` já é o dono do ramo de encerramento e do `_ready`).

## R3 — Detecção em alta velocidade: AABB por quadro é suficiente (sonda numérica)

**Decision**: A ativação de obstáculo usa o **mesmo AABB por quadro** dos galões (overlap do retângulo do obstáculo com o hitbox do jogador, `player_hitbox_size` de `game_config.gd`), **sem detecção varrida (swept)**. Verificação numérica: `max_speed = 100` un/s, `scroll_multiplier = 1.0` ⇒ Desafio (`velocidade = 4,0×`, ciclo insignificante) rola a **400 px/s ≈ 6,7 px/quadro a 60 fps** (≈ 13,3 px a 30 fps); a menor altura de obstáculo é **27 px** (`cascalho.png`) ⇒ a sobreposição dura **≥ 4 quadros a 60 fps e ≥ 2 quadros a 30 fps** — muito acima da janela mínima de 1 quadro. O SC-009 é coberto por **sonda automatizada** (100 encontros por obstáculo em Desafio, contando ativações — `obstacle_effects_test.gd`), exatamente no espírito da sonda `test_traffic_corridor_probe.gd` da SPEC-006. O teste de detecção roda **antes** da atualização de posição do obstáculo no mesmo quadro (mesma ordem dos galões), garantindo que o último quadro de sobreposição sempre conte.

**Rationale**: O número vem do config real e mostra uma folga de 4×; uma sweep-box nova introduziria um segundo mecanismo de colisão no projeto para ganho medido zero em 60/30 fps. O risco residual só existe abaixo de ~15 fps, faixa fora da meta de 60 fps da constituição — e o quickstart §5 define o gatilho de calibração caso o aceite manual observe atravessamento (aí o ajuste é de hitbox de obstáculo, não de arquitetura). A consistência com o mecanismo de coleta dos galões preserva o "aparência visual = área de ativação" com um único tipo de geometria.

**Alternatives considered**: *Swept AABB posição anterior→atual* — rejeitado (complexidade nova sem problema medido; a folga é 4×); *aumentar hitbox do obstáculo "por garantia"* — rejeitado (quebraria o SC-008 "aparência visual coincidente com a área de ativação" e a validação de limites da pista); *raio de ativação por distância* — rejeitado (mecanismo paralelo ao dos galões, difícil de calibrar contra a aparência).

## R4 — Acumulador de perda por colisão vive no `FuelSystem`

**Decision**: `FuelSystem` ganha `perda_colisao_corrida: float = 0.0` e `get_perda_colisao_corrida() -> float`. `on_player_collision(impulso)` soma a **perda real descontada** (`_atual - novo_atual` após o clamp, já com o multiplicador da dificuldade aplicado) e o `reset()` zera o acumulador junto com o tanque. `GameplayManager` lê o valor no ramo de vitória — não calcula nada.

**Rationale**: A penalidade é calculada uma única vez, dentro de `on_player_collision`, já com `dificuldade.fator_penalidade_colisao()`, clamp no zero e penalidade zero em ambientes calibrados (planície/deserto) — o acumulador só **espelha o delta real**, o que satisfaz FR-007 ("mesma perda não contabilizada mais de uma vez" e "consumo normal não penalizado") por construção: consumo normal nem passa por `on_player_collision`. Duplicar a fórmula no orquestrador criaria a segunda fonte de dados que o FR-001 proíbe. Zero de perda (planície/deserto) soma 0,0 — edge case sem erro de cálculo.

**Alternatives considered**: *Contar eventos de colisão e multiplicar depois* — rejeitado (ignora clamp do tanque e o fator por ambiente: o valor final já descontado é o único correto); *acumulador no `CollisionSystem`* — rejeitado (não conhece o tanque, duplicaria a aritmética); *reconstruir do histórico de sinais no encerramento* — rejeitado (estado transiente, exigiria retenção por corrida em mais de um lugar).

## R5 — Efeitos temporizados no `VehicleController` (padrão `aceleracao_bloqueada`)

> **Ajustado no aceite T032 (2026-10-17)**: a poça **saiu** do `VehicleController` — decisão original abaixo manteve só o cascalho. A poça agora é um **desvio lateral de meio carro** aplicado pelo `ObstacleManager` (campo do jogador: `player.position.x ± poca_desvio_lateral`, lado pela posição do impacto, clamp nos limites da pista); ela fica com estado `ATINGIDO` (inerte) e permanece na pista até ser reciclada na base (saiu da tela). Sem tick, sem duração, sem congelamento a preocupar, sem renovação — o estado do veículo não muda. O cascalho preserva integralmente a decisão abaixo (renovação por sobrescrita + tick em `_process` + clamp de teto por quadro).

**Decision (original, vigente para o cascalho)**: `VehicleController` ganha efeitos mutuamente independentes, ambos com **renovação por sobrescrita** (colisão repetida redefine `tempo` e `fator` — nunca soma, FR-016) e **tick em `_process`** (que já é parado por `set_process(false)` em MENU/PAUSED/VICTORY/GAME_OVER — congelamento na pausa é por construção, FR-016/edge case "pausa"):

- **Poça (aderência)** — *(removido no aceite T032)* `aplicar_efeito_poca(...)`: campos `efeito_aderencia_*` com rampa de recuperação, multiplicando os três termos laterais junto a `control_factor`. Substituído pelo desvio instantâneo descrito no aviso acima.
- **Cascalho (velocidade)** — `aplicar_efeito_cascalho(duracao: float, fator_velocidade: float, fator_aderencia: float)`: campos `efeito_velocidade_tempo`, `efeito_velocidade_fator`, `efeito_aderencia_cascalho`. Enquanto ativo, o **teto efetivo** da velocidade vira `max_speed × dificuldade.fator_velocidade_total() × fator_efeito` e o `speed` é limitado a esse teto **a cada quadro** (`_apply_vertical_physics`) — a redução é imediata e perceptível; ao expirar, o teto normal volta e o jogador volta a acelerar até o máximo do modo. O `fator_aderencia` do cascalho (estabilidade opcional do FR-015) é o único campo de aderência restante, com padrão de config **1,0 = desligado** (item Deferred da spec; só calibração decide ligar).

**Rationale**: É literalmente o desenho já aprovado de `aceleracao_bloqueada`/`control_factor` (estado escalar + tick no `_process` + reset em `reset()`), o que entrega o congelamento na pausa, a renovação e o retorno automático sem nenhum `Timer` ou nó novo. O clamp por quadro do cascalho funciona em qualquer fator de dificuldade (FR-025) sem tocar nos multiplicadores da SPEC-009 — apenas o teto já calculado é rebaixado. O desvio da poça em `ObstacleManager` (ajuste T032) não precisa de nenhum dos mecanismos acima: é uma mutação instantânea de posição com clamp, com a inércia (estado `ATINGIDO`) garantindo um único desvio por passada — e como não há estado temporal, não há o que congelar na pausa.

**Alternatives considered**: *Usar/derivar `control_factor` do DriftState* — rejeitado (o `control_factor` é domínio exclusivo da deriva de colisão da SPEC-005 — reutilizá-lo faria a poça zerar a deriva de colisão e vice-versa, violando a Assumption "efeitos são independentes"); *nó `Timer` na cena por obstáculo* — rejeitado (churn de nós, congelamento manual por estado, árvore obrigatória nos testes); *contar tempo no `ObstacleManager`* — rejeitado (o efeito pertence ao veículo, sobrevive ao reciclo do obstáculo no pool e deve congelar junto com o processamento do jogador, não com o dele); *suavizar o clamp do cascalho com aceleração negativa* — rejeitado (mais um estado, resposta lenta demais para "redução perceptível"; o clamp é determinístico e testável campo a campo).

## R6 — Geração de obstáculos: espelho do `FuelCanManager`

**Decision**: `ObstacleManager extends Node` com pool de `Obstacle` (Sprite2D + retângulo de ativação derivado do config — poca 48×35, cascalho 48×27), `update(delta, road, snapshot_npc, track_manager, player)` chamado pelo `GameplayManager` como **novo passo imediatamente após os galões** (passo 3.5 do ramo PLAYING), e spawn por **distância integrada** exatamente como os galões: `distancia_desde_spawn` avança com a rolagem; no cruzar de `obstaculo_intervalo_km` (0,5 km × 1,0 — frequência **constante entre modos**, só o desbloqueio difere) sorteia tipo (pesos `obstaculo_peso_poca`/`obstaculo_peso_cascalho`, padrão 50/50) e tenta posicionar. Validações, todas configuráveis e no espírito das do galão:

1. dentro de `road_left_boundary`/`road_right_boundary` com margem de largura do sprite;
2. fora da faixa de `obstaculo_start_offset_km` (0,15) até `track_total_distance − obstaculo_finish_offset_km` (0,25);
3. `obstaculo_min_spacing` (120 px) de qualquer outro obstáculo ativo;
4. `obstaculo_npc_spacing` (24 px) do eixo Y de qualquer NPC do snapshot;
5. distância do eixo Y do jogador no momento do spawn.

Falha em qualquer validação ⇒ o spawn é **reagendado** (+0,1 km na próxima tentativa) — nunca gerado inválido (edge case "descartado/reagendado"). O gate `definir_disponivel(bool)` (FR-018/FR-019) desliga o spawn por corrida inteira quando o modo é Relaxante sem troféus — o `GameplayManager` o define no `_reset_corrida` a partir de `progresso.obstaculos_disponiveis(modo)`. A detecção de ativação é AABB por quadro (R3): **cascalho** ⇒ `player.controller.aplicar_efeito_cascalho(...)` + reciclagem imediata; **poça** (ajuste T032) ⇒ desvio lateral de meio carro por posição do impacto + estado `ATINGIDO` (inerte, permanece na pista até a reciclagem na base). Reset de corrida = devolve tudo ao pool, zera a distância integrada (como `items_layer.reset()`), preservando o gate de disponibilidade. NPCs continuam sem interagir (RF-005), combustível intocado (FR-014/FR-015).

**Rationale**: Seguir o galão linha a linha maximiza a reutilização arquitetural (FR-027), mantém a validação testável sem árvore (todas as funções são puras sobre coordenadas) e resolve por construção sobreposição entre obstáculos (pool limitado + spacing), com NPCs (snapshot) e com a passagem livre (margens + largura 48 px em pista de 144 px — o obstáculo nunca cobre a pista toda, FR-017). A frequência constante entre modos é uma decisão consciente: a spec só liga disponibilidade à dificuldade (FR-018), não frequência; escalar densidade por modo poderia ameaçar o SC-007 ("0 obstáculos antes do 1º troféu") com números novos sem necessidade — se o aceite manual pedir mais/menos obstáculos no Desafio, o quickstart §5 trata como calibração de um único número.

**Alternatives considered**: *Gerar via `EnvironmentManager`/decoração* — rejeitado (decoração é sem colisão por contrato da SPEC-004; misturaria colisão na biblioteca de sprites); *spawn por tempo* — rejeitado (depende de fps, quebra a relação com a distância percorrida que os galões já usam); *nó obstáculo por corrida com `queue_free`* — rejeitado (churn de nós por corrida, exatamente o que o pool evita); *bloqueio por tipo (poça vs cascalho) separado* — rejeitado (a spec desbloqueia os dois juntos, estado único).

## R7 — Fluxo de encerramento: ordem canônica e gravação única

**Decision**: Em `_avaliar_transicoes()`:

- **Vitória** (após `marcar_concluido()` e captura do `ambiente = progresso.ambiente_atual()` **antes** de avançar): `var snapshot = progresso.processar_vitoria(modo, ambiente, distancia, perda_colisao)` — dentro do `processar_vitoria`, **nesta ordem**: (1) marcar ambiente no ciclo do modo (concede troféu se completou os 4, zera ciclo e incrementa total); (2) `pontuacao = calcular_pontuacao(distancia, trofeus_apos_marcar, perda)`; (3) atualizar recorde se `pontuacao > recorde`; (4) `acumulada += pontuacao`; (5) anexar resultado ao histórico (trim no teto); (6) devolver snapshot. Depois, no orquestrador: `save.gravar(progresso.dados_para_salvar())` **uma única vez** — e só então `race_won.emit()` / `game_state.victory()` / UI recebe o snapshot.
- **Derrota**: `progresso.processar_derrota(modo)` (zerar ciclo do modo, total preservado), `save.gravar(...)` uma única vez, então `race_lost.emit()` / `game_state.game_over()` / UI recebe snapshot **sem** `pontuacao` de corrida (FR-003/FR-023).

**Rationale**: A ordem interna é literalmente o FR-006/FR-008 + edge case "troféu e recorde na mesma corrida": os troféus são contados **depois** de marcar o ambiente da própria corrida (a pontuação inclui o troféu recém-conquistado) e **antes** do recorde, que por sua vez é anterior à gravação; o `race_won.emit()` segue **depois** do save porque os observadores (UI) devem mostrar valores já persistidos (SC-010: "reiniciar restaura o que a tela mostrou"). Uma gravação por corrida (FR-023/SC-011) fica garantida porque o único ponto de save é o ramo de encerramento, e `_avaliar_transicoes` já roda com latch `esta_concluido()` + `change_state` no-op — o caminho "volta ao menu logo após encerramento" não passa de novo por ali (edge case "não reaplicado"). O `ambiente_atual()` precisa ser lido antes de `registra_vitoria()` porque o `RaceProgression` avança o índice no `registra_vitoria()` — captura explícita, sem fonte duplicada.

**Alternatives considered**: *Gravar no `state_changed` de VICTORY* — rejeitado (o save passaria a ser efeito colateral de um sinal consumido por vários observadores; a ordem "antes do emit" ficaria implícita na ordem de conexão); *gravar a cada troféu/recorde separadamente* — rejeitado (mais de uma escrita por corrida, viola FR-023/SC-011); *processar_vitoria antes de `marcar_concluido`* — rejeitado (a distância só é conhecida com o latch; e o snapshot mostrado na tela ficaria um passo atrás do estado interno).

## R8 — UI: painel de progresso no menu e nos encerramentos

**Decision**: `UIManager` mantém os quatro painéis existentes e ganha, **dentro** do painel do menu e dos painéis de vitória/Fim de Jogo (nunca durante a corrida — FR-023), um bloco de progresso construído em código como o resto da UI:

- 2 `Label` de texto (`_rotulo_recorde`, `_rotulo_trofeus`) + 1 `Label` de estado dos obstáculos (`_rotulo_obstaculos`) — todas as strings vindas de chaves novas de `GameConfig.ui_strings` (`record_label`, `accumulated_label`, `trophy_format` "troféus — Próximo: %d/4 ambientes", `obstacles_available`, `obstacles_locked`, `victory_score` para "Pontuação: %.1f"; `score_label` removida no T042);
- 1 `TextureRect` 32×32 (`_icone_trofeu`) com textura carregada **uma única vez** no `_ready` a partir de `GameConfig.trofeu_assets[modo]` (FR-013: associação modo→asset centralizada; filtro NEAREST igual ao resto);
- método `atualizar_painel_progresso(dados: Dictionary)` consumindo o snapshot do contrato (`contracts/ui_progress_display.md`), chamado pelo `GameplayManager` em `_show_menu`, no fim do branch de vitória e no fim do branch de derrota; `atualizar_modo(rotulo)` passa a repassar também o id do modo (o `TextureSelector` de troféu troca junto com a linha "Modo" — US2 AS7).

**Rationale**: Painéis são construídos em código (padrão `FuelHud` já adotado pela própria `UIManager`, FR-041 da SPEC-008) e o layout aproveita o espaço livre: no menu, abaixo da linha "Iniciar corrida" (y ≈ 330–400); nos encerramentos, abaixo das opções (y ≈ 240–400) — tudo dentro dos 640×480 sem sobreposição (SC-012/US4 AS9). O `TextureRect` de 32 px atende SC-006 com desvio 0 px e reaproveita o filtro de textura já definido. Exibir via snapshot-dicionário (e não por injeção de 5 parâmetros) mantém o contrato de UI estável quando a spec futura acrescentar linhas — mesma estratégia de payload dos sinais de colisão.

**Alternatives considered**: *Cena `.tscn` nova para o painel* — rejeitado (a UI inteira do jogo já é construída em código; introduzir cena agora criaria um segundo padrão); *HUD durante a corrida* — rejeitado (decisão Q3/A da spec: nada novo em PLAYING); *UI conectada direto no `ProgressManager`* — rejeitado (a UI é observadora pura por contrato — comandos só via sinais e dados via snapshot; dependência nova de domínio); *label única com tudo embutido* — rejeitado (o ícone 32 px é exigido por SC-006 e a troca por modo precisa de textura própria).

## R9 — Momentos de gravação e carga

**Decision**: Exatamente **dois momentos de gravação**: fim do ramo de vitória e fim do ramo de derrota (ambos após o `processar_*`, uma escrita cada — R7). **Carga uma única vez**, no `_ready()` do `GameplayManager` (`save_manager.carregar()` → `progress_manager.carregar_de(...)`), antes do primeiro `_aplicar_estado()` da UI. Troca de modo, seleção de veículo e reset de corrida **não gravam** (não alteram dados persistíveis). A UI recebe o snapshot corrente em `_show_menu` — inclusive no arranque do jogo e após "Voltar ao menu".

**Rationale**: Todo dado persistível nasce de um encerramento de corrida (resultado, troféus, ciclo, acumulada, desbloqueio); gravar em outros pontos só adicionaria escritas sem mudar o conteúdo (FR-023 "persistência em momentos consistentes"). Carga no `_ready` espelha a configuração do áudio (`configurar()` uma vez) e garante que o primeiro menu já mostre recordes restaurados (SC-010).

**Alternatives considered**: *Auto-save periódico* — rejeitado (nada muda entre corridas; timer de I/O é churn de disco por sessão); *gravar ao sair (`NOTIFICATION_WM_CLOSE_REQUEST`)* — rejeitado (não cobre crash e o evento já tem o save do encerramento; perda real seria zero); *gravar na troca de modo* — rejeitado (a troca não altera dados).

## R10 — Chaves de modo: as mesmas da SPEC-009

**Decision**: Todos os dicionários por modo (recordes, troféus, ciclos, acumuladas) usam **exatamente as chaves** de `GameConfig.difficulty_modes` — `"relaxing"`, `"normal"`, `"challenge"` — obtidas do orquestrador via `dificuldade.get_modo()`. Modo desconhecido em dados carregados é **ignorado com aviso** e os três canônicos são sempre materializados com defaults (`carregar_de` completa faltantes); a UI recebe o rótulo legível já resolvido (`DifficultyManager`/`ui_strings.mode_*`).

**Rationale**: Fonte única de identidade de modo (FR-001: "sem criar fontes duplicadas"); o `DifficultyManager` já valida e normaliza ids, então o domínio de progressão nunca vira segunda autoridade sobre "qual modo existe". Materializar os três na carga elimina `.get(chave, 0)` espalhado na UI (SC-005: independência com defaults garantidos).

**Alternatives considered**: *Usar o rótulo legível ("Relaxante") como chave* — rejeitado (tradução/UI como chave de persistência é frágil); *id numérico novo por modo* — rejeitado (terceira representação do mesmo conceito);*dicionário indexado por inteiro* — rejeitado (ordem implícita, reintroduz a ambiguidade que a SPEC-009 já resolveu).

## R11 — Assets e caminhos centralizados

**Decision**: `GameConfig` ganha `trofeu_assets: Dictionary` (`"relaxing" → "res://assets/trofeus/trofeu-relaxante.png"`, etc.), `obstaculo_poca_path` e `obstaculo_cascalho_path` (verificados na inspeção: `assets/obstaculos/poca.png` 48×35 e `cascalho.png` 48×27) + `obstaculo_tamanho_poca/cascalho` (Vector2, derivadas dos reais). Carregamento por `ResourceLoader.exists()` + `load()` **uma única vez** — no `_ready` da UI (ícones) e no `_ready` do `ObstacleManager` (sprites do pool); arquivo ausente ⇒ componente segue funcional sem visual (mesma política segura do áudio, SC-008 da SPEC-010). Os `*.import` existem nesta máquina (gerados pelo editor; regra do AGENTS.md para máquinas novas).

**Rationale**: FR-013/FR-026 exigem associação centralizada e zero números/caminhos mágicos; `ResourceLoader.exists` antes do `load` evita erro de console quando um asset futuro for removido (SC-012: "sem erros de console nem referências inválidas"). As dimensões ficam em config porque a área de ativação deve acompanhar o sprite se o asset mudar (SC-008 "aparência = ativação").

**Alternatives considered**: *Paths embutidos nos scripts* — rejeitado (violam FR-026 e a disciplina §IV); *carregar por preload* — rejeitado (quebra o teste sem asset e joga erro no import em máquinas sem `*.import`; `load` tardio com guarda é o padrão do áudio); *derivar tamanho por `Texture2D.get_size()`* — rejeitado como fonte única (mantém-se como verificação opcional; config é a fonte canônica para os testes headless sem textura).

## R12 — Testabilidade e regressão legada

**Decision**: Campos novos no `GameplayManager` (`progress_manager`, `save_manager`, `obstacles_layer`) iniciam `null` com **guards** `if x:` em todos os pontos de uso — os testes sintéticos legados que montam o manager sem `_ready()` seguem verdes sem nenhum ajuste (garantia R12 consolidada nas SPEC-009/010). As suítes novas se dividem em: **domínio puro** (`progress_manager_test`, `score_calculation_test` — sem árvore, sobre `ProgressManager` recém-criado), **I/O real** (`save_manager_test` — arquivo temporário em `user://`, removido no teardown), **orquestração** (`progress_flow_test` — manager sintético + mocks de track/fuel/progress, sem árvore) e **obstáculos** (`obstacle_manager_test` puro sobre coordenadas + `obstacle_effects_test` com `VehicleController` real, incluindo a sonda de 100 encontros em Desafio do SC-009).

**Rationale**: É exatamente o desenho de teste que manteve 414 casos legados verdes sem tocar neles nas duas últimas specs; o `caminho` injetável do `SaveManager` é o que permite testar persistência real sem sujar o save do usuário (SC-010 semáforo humano extra). A sonda de encontros fecha o único critério do SC-009 que não é assertável com 1–2 itens.

**Alternatives considered**: *Refatorar testes legados para os novos campos* — rejeitado (a garantia é justamente 0 ajustes); *testar save só manualmente* — rejeitado (a constituição §VIII exige cobertura da lógica de I/O tolerante a falhas); *testar obstáculos só na árvore real* — rejeitado (spawn/validação são geometria pura; árvore só custa tempo de teste).

## R13 — Sementes de calibração (balanceamento inicial)

**Decision**: Valores iniciais em `game_config.gd` (todos exportable/configuráveis, FR-026) — pontos de partida para o quickstart §5, não verdades:

| Parâmetro | Padrão | Racional |
|---|---|---|
| `score_peso_distancia` | `100` pts/km | corrida de referência (5,0 km) vale 500 pts — ordem de grandeza doméstica |
| `score_peso_trofeu` | `500` pts/troféu | 4 ambientes ≈ mais que uma corrida perfeita — motiva o ciclo |
| `score_peso_penalidade` | `10` pts/un de perda | tanque de referência ≈ 360 un; 3 colisões em Desafio (~45 un × 1,5) ≈ −675 pts — pune de verdade |
| `score_historico_max` | `50` entradas | teto de crescimento (§VII) |
| `poca_desvio_lateral` | `11` px | desvio de **meio carro** (largura 22 ÷ 2) no impacto — perceptível sem tirar o carro da faixa (ajuste T032) |
| `cascalho_velocidade_fator` | `0,6` | teto cai a 60% do modo — perceptível nos 3 modos |
| `cascalho_duracao` | `1,2` s | janela curta: atrapalha, não destrói |
| `cascalho_aderencia_fator` | `1,0` | estabilidade **desligada** por padrão (Deferred da spec) |
| `obstaculo_intervalo_km` | `0,5` | ~8 obstáculos por corrida de referência |
| `obstaculo_max_ativos` | `3` | pool pequena, O(3) por quadro |
| `obstaculo_min_spacing` | `120` px | mesmo número dos galões |
| `obstaculo_npc_spacing` | `24` px | mesmo número dos galões |
| `obstaculo_start_offset_km` / `_finish_offset_km` | `0,15` / `0,25` | mesmas margens dos galões |
| `obstaculo_peso_poca` / `_peso_cascalho` | `50` / `50` | simetria inicial |

**Rationale**: Todos os números vêm de alavancas já calibradas nas specs anteriores (offsets/spacing dos galões) ou de contas explícitas contra o config real (tanque ≈ 360 un, 5,0 km, penalidade Desafio ×1,5); deixá-los em config mantém o ajuste pós-aceite como tarefa de calibração, não de código (§IV).

**Alternatives considered**: *Fixar pesos "definitivos"* — rejeitado (a spec diz literalmente "a spec fixa as regras, não os números"); *escalar pesos por modo* — rejeitado (a fórmula do FR-004 é única; multiplicadores de dificuldade já existem e não se aplicam à pontuação sem pedido).
