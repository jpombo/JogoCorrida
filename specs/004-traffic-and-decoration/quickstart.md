# Quickstart — Validação do Sistema de Trânsito e Decoração

**Feature**: Sistema de Trânsito e Decoração dos Ambientes
**Branch**: `004-traffic-and-decoration` | **Date**: 2026-10-02

Guia de validação executável. Cada cenário corresponde a um requisito da spec e pode ser conferido manualmente no jogo ou automatizado em `tests/unit/`. Campos e assinaturas em [data-model.md](./data-model.md); interfaces em [contracts/traffic_decoration_contract.md](./contracts/traffic_decoration_contract.md).

Este guia **não** contém o código de implementação — as tarefas correspondentes ficam em `tasks.md`, gerado por `/speckit.tasks`.

---

## Pré-requisitos

| Item | Valor | Origem |
|---|---|---|
| Engine | Godot 4.7 | `project.godot` |
| Viewport | 640x480, stretch `viewport` | `project.godot` |
| Filtro de textura | `nearest` (global) | `project.godot`, `default_texture_filter=0` |
| Cena principal | `res://src/game/gameplay.tscn` | `project.godot` |
| Autoloads | `GameConfig`, `GameState` | `project.godot` |
| Testes | GdUnit4, em `tests/unit/` | `addons/gdUnit4/` |

**Assets verificados antes de começar** (R1): 17 veículos em `assets/npcs/{caminhao,esporte,passeio,utilitario}/`, e 17 arquivos de decoração em `assets/decoracao/{planice,deserto,floresta,gelo}/`.

> ✅ **Assets de decoração REFEITOS E VALIDADOS (atualização de 2026-10-03).** Os 17 PNGs foram
> reexportados fora do jogo com proporções derivadas da **base de tile 32x32** e filtro `NEAREST`,
> e estão na resolução final. Os originais seguem em `assets/decoracao/_originais/` (18 arquivos,
> incluindo `gelo_casa02`, que saiu da biblioteca `ICE`).
>
> `tools/resize_decoration_assets.py` virou **validador somente leitura**: não reescreve mais
> nenhum arquivo e confere nomes contra `GameConfig.DECORATION_LIBRARIES`, alturas da SC-027,
> proporção frente ao backup e presença de `.import`.
>
> **Validação da entrega (2026-10-03) — resultado: positivo, com avisos.**
>
> | Verificação | Resultado |
> |---|---|
> | Assets declarados existentes | **17 de 17**; nenhum PNG fora da biblioteca |
> | Altura como % da área visível | **3% a 33%** (16 px a 160 px), dentro da faixa de 3% a 35% da SC-027 |
> | Eixo múltiplo de 32 px | **13 de 17** — as árvores ficam em 49 px e `gelo_boneco` em 24x18 |
> | Proporção frente ao original | 4 ajustes admitidos no encaixe da grade: `planice_milho` 30,4%, `deserto_cactus` 23,4%, `planice_casa01` 21,7%, `planice_arvore01` 7,9% |
> | `.import` dos 17 PNGs | **gerados** (17 de 17) — `*.import` é ignorado pelo git, então abra o editor Godot uma vez em cada máquina nova antes dos testes headless |
>
> Conferência asset a asset (dimensões, tiles e desvio) sai na própria execução do validador.
>
> **Comparação visual com `_originais/` (T003, 2026-10-04) — resultado: aprovado.** Os 5 assets
> de maior desvio de proporção (`planice_milho` 30,4%, `deserto_cactus` 23,4%, `planice_casa01`
> 21,7%, `floresta_serra`, `gelo_casa01`) foram colocados lado a lado com o original reamostrado
> por NEAREST na mesma caixa: formas, contornos e paleta correspondem, as bordas permanecem
> duras (sem halo de interpolação) e os pixels continuam legíveis na escala de entrega. A
> reexportação externa introduz microajustes de aresta em alpha sub-255 em relação à amostra
> NEAREST pura, sem efeito visível na escala 1.0 (FR-047, SC-020).

```bash
# Contagem de assets de decoração — esperado 17
find assets/decoracao -name '*.png' -not -path '*_originais*' | wc -l

# Originais preservados — esperado 18
find assets/decoracao/_originais -name '*.png' | wc -l

# Contagem de veículos — esperado 17
find assets/npcs -name '*.png' -not -name '*.import' | wc -l

# Validação completa: nomes, alturas (SC-027), proporção, .import e percentuais — esperado "OK: 17 assets"
python3 tools/resize_decoration_assets.py
```

---

## Parte 1 — Verificação do mapeamento de velocidade

Confirma que 1 km/h = 0.8 unidades e que nenhuma categoria atinge a velocidade do jogador (FR-008, FR-011, I4).

| Categoria | km/h | Esperado em unidades | Limite |
|---|---|---|---|
| `caminhao` | 90 | 72.0 | < 100.0 |
| `utilitario` | 90 | 72.0 | < 100.0 |
| `passeio` | 100 | 80.0 | < 100.0 |
| `esporte` | 120 | 96.0 | < 100.0 |
| Jogador | 125 | 100.0 | referência |

**Teste automatizado** (`tests/unit/test_traffic_categories.gd`):

| Verificação | Critério de sucesso | Requisito |
|---|---|---|
| Conversão | `max_speed == max_speed_kmh * 0.8` para as 4 categorias | R2 |
| Limite | `max_speed < GameConfig.max_speed` para as 4 | I4, FR-008 |
| Assets | Toda entrada tem `assets` não vazio e todos os arquivos existem | FR-012 |
| Dimensões | `size` corresponde à textura real da categoria | FR-025, R10 |
| Frequências | Somam `> 0.0`; nenhuma frequência isolada excede a soma das demais | FR-010 |

---

## Parte 2 — Cenários manuais no jogo

Iniciar com `F5` no editor Godot, ou `godot --path . ` pela linha de comando. A cena inicia em `MENU`; pressionar `Enter` para `READY` e, após 1 segundo, `PLAYING`.

### V1 — Trânsito não invade a área trafegável (I2, FR-009, SC-001)

1. Deixar o trânsito habilitado e acelerar até a velocidade máxima.
2. Observar as 4 vias durante toda a condução.

**Esperado**: nenhum veículo aparece sobre a grama, ao lado da estrada, nem sobre a faixa de transição. Zero ocorrências em 2 minutos de condução contínua.

### V2 — Todo veículo nasce fora da tela (I3, FR-013, SC-002)

1. Acelerar até o máximo e observar o topo da tela continuamente.

**Esperado**: nenhum veículo aparece de forma abrupta dentro da área visível. Todos entram por cima.

### V3 — Jogador ultrapassa todos os veículos (FR-007, SC-003)

1. Acelerar até `max_speed` e manter.

**Esperado**: todos os veículos descem em direção à parte inferior e saem pela borda inferior. Nenhum permanece parado na tela.

> Nota: `esporte` a 96.0 contra o jogador a 100.0 tem margem de 4%. A ultrapassagem desse veículo é visivelmente mais lenta — comportamento esperado, registrado no caso de borda "Margem estreita entre `esporte` e o jogador".

### V4 — Com velocidade reduzida, os veículos sobem (FR-016, SC-003)

1. Acelerar até encher a tela de veículos.
2. Soltar o acelerador e deixar a velocidade cair a zero.

**Esperado**: os veículos visíveis sobem em direção ao topo e desaparecem por essa borda. Com o jogador parado, nenhum veículo novo nasce.

### V5 — As 4 categorias são identificáveis (FR-001, US2, SC-004)

1. Conduzir e observar o tráfego.

**Esperado**: `caminhao` visivelmente maior (32x128) que os demais (32x64); `esporte`, `passeio` e `utilitario` distinguíveis entre si. As proporções seguem a configuração: `caminhao` 0.15, `passeio` 0.35, `esporte` 0.25, `utilitario` 0.25.

### V6 — Decoração nos dois lados, fora da estrada (D2, FR-033, SC-021)

1. Conduzir em qualquer ambiente e observar as laterais.

**Esperado**: elementos decorativos em ambos os lados, em pelo menos 2 profundidades, com no mínimo 3 elementos visíveis por lado. Zero elementos sobre a área trafegável ou dentro da margem de segurança de 24 px.

### V7 — Cada ambiente exibe apenas sua biblioteca (D1, FR-053, SC-008)

1. Alterar `GameConfig.current_environment_id` para `PLAINS`, `DESERT`, `FOREST` e `ICE`, um de cada vez.

**Esperado**: em cada ambiente, apenas os elementos da biblioteca correspondente. Zero elementos de outro ambiente em tela, mesmo após alternar várias vezes (sem acúmulo do ambiente anterior).

### V8 — Repetição de árvores até 10 (D6, D7, D8, FR-036, SC-014)

1. Ativar `FOREST` e conduzir por cerca de 2 minutos, observando cada lado separadamente.
2. Repetir com `ICE` (`gelo_arvore`) e `PLAINS` (`planice_arvore01`).

**Esperado**:
- Elementos **não** repetíveis (casas, lago, serra, boneco, silo, duna, cactus, feno, milho) **nunca** aparecem duas vezes seguidas no mesmo lado.
- Elementos `repeatable` (na configuração atual, os 6 assets `arvore`) podem aparecer até **10 vezes seguidas no mesmo lado**, e ao atingir 10 o sistema volta a evitar a repetição.
- Os dois lados contam **independentemente**: 6 árvores de um lado e 6 do outro não estoura o limite.

### V9 — Decoração acompanha a estrada (FR-039, FR-040, SC-012)

1. Acelerar e depois frear até parar completamente.

**Esperado**: a decoração se desloca junto com a estrada, sem cortes ou saltos. Com o jogador **completamente parado por 60 segundos**, nenhum elemento se desloca, nenhum nasce e nenhum desaparece — os elementos já visíveis ficam congelados.

### V10 — Estrito ciclo de reciclagem (D4, FR-043, SC-010, SC-015)

1. Conduzir por 10 minutos contínuos, accelerate e freando.

**Esperado**: nenhum acúmulo de objetos. Elementos que saem por qualquer borda desaparecem da cena (não são apenas ocultados) e novos elementos ocupam o lugar. A quantidade de elementos ativos e de veículos permanece limitada.

### V11 — Trânsito correto durante as transições de largura (I2, FR-020, SC-007, SC-023)

1. Percorrer a sequência de teste configurada em `GameConfig.test_track_sequence`: 2 vias → expansão → 4 vias → redução → 2 vias.

**Esperado**: nenhum veículo aparece ou desaparece da área visível por causa da mudança de largura. Veículos cuja faixa deixa de existir são reposicionados **continuamente**, sem salto. Ao final, 100% permanecem dentro da área trafegável.

### V12 — Decoração sobrevive ao estreitamento (D2, FR-051, SC-011)

1. Percorrer a mesma sequência, observando as laterais durante a redução de 4 para 2 vias.

**Esperado**: os elementos que estão na área que deixa de ser trafegável são empurrados **continuamente** para fora da nova área, mantendo a margem de segurança. Nenhum elemento fica sobre a estrada e nenhum desaparece de forma abrupta.

### V13 — Paro completo dos sistemas (FR-024, FR-056, SC-016)

1. Em modo editor, definir `traffic_enabled = false`; em seguida `decoration_enabled = false`.

**Esperado**: com `traffic_enabled = false`, nenhum veículo novo nasce e os existentes seguem seu curso até sair. Com `decoration_enabled = false`, os elementos existentes deixam de ser exibidos. Estrada e jogador continuam funcionando. **Nenhuma alteração de código** foi feita.

### V14 — Troca de ambiente em tempo de execução (D1, FR-031, US6)

1. Com a decoração exibida, trocar `current_environment_id` durante a condução.

**Esperado**: as laterais passam a exibir apenas a biblioteca nova, sem resíduo da anterior.

### V15 — Zero regressão das specs anteriores (US8, SC-017)

1. Com trânsito e decoração ativos, repetir os testes de SPEC-001, SPEC-002 e SPEC-003 nos 4 ambientes.

**Esperado**: aceleração, frenagem, movimento lateral, deslocamento da estrada, transições 2↔4 vias e os 4 cenários de fundo funcionam exatamente como antes. Zero elementos de decoração ou veículos atrapalham a contenção do jogador nos limites da estrada.

### V16 — Continuidade de composição entre camadas (FR-058, FR-059, SC-012, SC-013)

1. Com `background_multiplier = 0.6`, `decoration_speed_multiplier = 1.0`, trânsito e decoração ativos, percorrer a sequência completa de 2 → 4 → 2 vias.

**Esperado**: nenhuma borda, corte ou salto visível entre cenário de fundo, decoração e estrada em nenhum dos quatro ambientes, ao acelerar, ao frear e durante a transição de redução. Nenhum elemento decorativo aparece sobre a área trafegável.

---

### V17 — Percentuais de apresentação (D6, D7, FR-036, FR-037)

1. Para cada ambiente, conduzir por cerca de 10 minutos e anotar quantas vezes cada elemento passa pelas laterais.

**Esperado** — frequência observada próxima do percentual declarado. O peso interno é compensado no `setup` para neutralizar D6 e D7, então a leitura deve ficar em ±1 ponto percentual no geral, com tolerância de ±5 pontos:

| Ambiente | Árvores | Demais elementos |
|---|---|---|
| `PLAINS` | 80% (`planice_arvore01`) | `planice_casa01` 5%, `planice_feno01` 7%, `planice_milho` 6%, `planice_silo01` 2% |
| `DESERT` | 73% (36,5% + 36,5%) | `deserto_cactus` 20%, `deserto_duna` 5%, `deserto_casa` 2% |
| `FOREST` | 96% (48% + 48%) | `floresta_lago` 3%, `floresta_serra` 1% |
| `ICE` | ~90% (`gelo_arvore`) | `gelo_boneco` ~7%, `gelo_casa01` ~2% |

Ressalvas que deslocam a leitura, sem invalidá-la: um elemento não repetível nunca sai duas vezes seguidas (D6) e a árvore para em 10 seguidas (D7) — a compensação interna corrige o efeito médio dessas regras, mas em `ICE` há o teto de cerca de 90,9% (10 em cada 11 nascimentos no máximo) para a árvore declarada com 96%; o excedente aparece em `gelo_boneco` e `gelo_casa01` acima do declarado, o que é esperado. A conferitura estática dos percentuais (soma 100 por ambiente) sai no `python3 tools/resize_decoration_assets.py`.

## Parte 3 — Verificações automatizadas

### Executar a suíte

```bash
# Via de linha de comando do GdUnit4
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit
```

### Cenários por arquivo de teste

| Arquivo | Verifica | Requisitos |
|---|---|---|
| `test_traffic_categories.gd` | Parte 1 completa; limite de velocidade; assets existentes | FR-001, FR-008, FR-011, FR-012 |
| `test_traffic_manager.gd` | I1 a I7 com `Road` dublê; spawn suprimido com `scroll_speed == 0.0` | FR-005, FR-009, FR-013, FR-018, FR-019, FR-022, FR-024, SC-022 |
| `test_decoration_libraries.gd` | 4 bibliotecas com 3 a 5 assets; `repeatable` correto por asset | FR-029, FR-036 |
| `test_decoration_manager.gd` | D1 a D10 com `Road` dublê; ≥3 elementos e ≥2 profundidades por lado; continuidade de composição | FR-033, FR-036, FR-040, FR-041, FR-043, FR-051, FR-053, FR-058, FR-059, SC-009, SC-012, SC-013 |
| `test_decoration_config.gd` | Invariantes de espaçamento, multiplicador e margem | FR-046, FR-056 |
| `test_no_collision.gd` | Ausência de corpo de física, sinal de contato e resolução de colisão | FR-026, FR-049, SC-018 |
| `test_spec004_regression.gd` | SPEC-001/002/003 com ambos os sistemas ativos | SC-017 |
| `test_performance_traffic_decoration.gd` | 60 FPS meta / 30 FPS piso em 10 min, 4 ambientes | FR-060, SC-024 |
| `test_memory_stability.gd` | Sem crescimento indefinido em 10 min | SC-010, SC-015 |

### Testes de borda obrigatórios

| Cenário | Comportamento esperado | Origem |
|---|---|---|
| `traffic_max_vehicles` muito baixo | Criação sob demanda até o limite; nunca recusada; nunca acima do limite | FR-018, SC-025 |
| Biblioteca de decoração vazia | Lateral sem elementos, jogo jogável, aviso emitido, trânsito intacto | Caso de borda |
| Biblioteca com um único elemento | Elemento se repete; repetição **não** é falha | Caso de borda |
| Espaço longitudinal insuficiente | Nenhum objeto nasce naquele quadro; sem sobreposição longitudinal | FR-019, caso de borda |
| Largura lateral insuficiente para as profundidades | Usa apenas as profundidades que cabem, sem invadir a estrada | FR-051, caso de borda |
| Elemento maior que a profundidade | Vai para a profundidade mais distante que o comporte | Caso de borda |
| Velocidade do jogador `0.0` | Nenhum deslocamento, nenhuma criação e nenhuma remoção na decoração; nenhum veículo novo de trânsito | FR-040, SC-022 |
| Dublê de `Road` sem `get_boundaries_for_player_y` | Teste falha com mensagem clara, não com erro de runtime | Compatibilidade de teste |

### Dublês de teste

`Road` é substituído por um dublê que implementa apenas:

```gdscript
# Contrato mínimo esperado pelos dois managers (não é o código de produção)
func get_boundaries_for_player_y(_y: float) -> Dictionary
var scroll_speed: float
```

Um dublê com `get_boundaries_for_player_y()` devolvendo largura 144.0 simula 2 vias; devolvendo 176.0 simula 4 vias; devolvendo valores interpolados de 144.0 a 176.0 simula a transição.

---

## Parte 4 — Critérios de aceite finais

| Critério | Como verificar |
|---|---|
| SC-001 a SC-008 | V1, V2, V3, V4, V5, V7 + testes automatizados |
| SC-009 a SC-016 | V6, V9, V10, V11, V13 + testes automatizados |
| SC-017 a SC-027 | V15, V8, V12 + testes automatizados |
| SC-024 (60 FPS, piso 30) | Monitorar com `Engine.get_frames_per_second()` durante 10 minutos de condução contínua com ambos os sistemas ativos nos 4 ambientes |
| SC-027 (escala e proporção) | `python3 tools/resize_decoration_assets.py`: nomes conferem, alturas entre 3% e 35% da viewport |

---

## Parte 5 — Registro de execução dos cenários V1 a V17 (T051)

**Execução**: 2026-10-04, Godot 4.7.2 + GdUnit4 headless — 13 suítes, **112 casos, 0 erros, 0 falhas** (exit 101, esperado pelo runner). Cenários de olhar puramente visual foram cobertos pelo equivalente automatizado citado e pela inspeção dos assets (T003).

| Cenário | Resultado | Evidência automatizada (suíte › caso) |
|---|---|---|
| V1 — trânsito nunca fora da área trafegável | ✅ | `test_traffic_manager` › `test_active_vehicles_inside_lane`, `test_spawn_validates_free_lane_at_its_height`, `test_sc023_no_blink_during_narrowing` |
| V2 — todo veículo nasce fora da tela | ✅ | `test_traffic_manager` › `test_spawn_above_visible_area` |
| V3 — ultrapassagem a toda velocidade | ✅ | `test_traffic_manager` › `test_sc003_...` (sinal do deslocamento = sinal de estrada−veículo até 100.0); margem estreita de `esporte` registrada na spec |
| V4 — com velocidade reduzida sobem; parado, nada nasce | ✅ | `test_traffic_manager` › `test_zero_scroll_only_suppresses_spawn` |
| V5 — 4 categorias identificáveis, proporção conforme configuração | ✅ | `test_traffic_categories` › dimensões medidas da textura (caminhão 32x128 vs demais 32x64), `test_observed_category_frequency_matches_declared` (T062) |
| V6 — dois lados, ≥3 elementos e ≥2 profundidades, fora da estrada | ✅ | `test_decoration_manager` › `test_minimum_elements_and_depths_per_side`, `test_sc026_...` (0 invasões em 10 min) |
| V7 — cada ambiente exibe só a própria biblioteca | ✅ | `test_decoration_manager` › casos de `set_environment` (T037) |
| V8 — árvores repetem até 10 por lado; demais nunca repetem | ✅ | `test_decoration_manager` › `test_repeat_rules_on_selection_sequence`, `test_ice_frequency_respects_repeat_ceiling` (T056) |
| V9 — decoração acompanha a estrada; parada total congela | ✅ | `test_decoration_manager` › `test_zero_scroll_freezes_everything` e caso de multiplicador (T031) |
| V10 — reciclagem estrita por qualquer borda, sem acúmulo | ✅ | `test_decoration_manager` › `test_recycles_by_any_border`; `test_memory_stability` › pools estagnados em 10 min (T049) |
| V11 — trânsito correto nas transições 2↔4 vias | ✅ | `test_traffic_manager` › T019 (3 casos) e `test_sc023_no_blink_during_narrowing` (T064) |
| V12 — decoração sobrevive ao estreitamento | ✅ | `test_decoration_manager` › reposicionamento contínuo por `lerpf` (T031/T035) e continuidade de composição (T036) |
| V13 — paro total por configuração, sem alterar código | ✅ | `test_traffic_manager` › `test_disabled_prevents_new_vehicles`; `test_decoration_config` › invariantes (T040); agrupamentos `traffic_tuning`/`decoration_tuning` (FR-061) |
| V14 — troca de ambiente em runtime | ✅ | `test_decoration_manager` › `set_environment` (T037); propagação automática por `gameplay_manager._propagar_ambiente` + detecção por quadro (T061) |
| V15 — zero regressão de SPEC-001/002/003 | ✅ | `test_spec004_regression` (7 casos) + as 3 suítes originais reprovadas na mesma execução (38 casos) |
| V16 — continuidade de composição entre camadas | ✅ | `test_decoration_manager` › caso de continuidade com `background_multiplier 0.6` / `decoration_speed_multiplier 1.0` (T036) |
| V17 — percentuais de apresentação observados | ✅ | `test_decoration_manager` › `test_observed_frequency_matches_declared` (±3 p.p.) e teto de ICE ~90,9% (T056) |

---

## Notas de diagnóstico

| Sintoma | Causa provável | Onde olhar |
|---|---|---|
| Veículo sobre a grama | `update()` não consultando `get_boundaries_for_player_y` | `traffic_manager.gd` |
| Elemento decorativo sobre a estrada | Margem de segurança não aplicada, ou reposicionamento não executado | `decoration_manager.gd` |
| Elemento aparecendo de repente | Nascimento abaixo de `y = 0` | `decoration_element.activate()` |
| Escada de objetos ao jogar 10 minutos | `deactivate()` não sendo chamado; apenas ocultando | Invariantes D4 e I5 |
| `esporte` nunca ultrapassado | Margem de 4% muito pequena para a percepção do jogador | Ver caso de borda "Margem estreita" e FR-008 |
| Biblioteca vazia em tela | Caminho do asset incorreto em `GameConfig` | `decoration_manager.setup()` |