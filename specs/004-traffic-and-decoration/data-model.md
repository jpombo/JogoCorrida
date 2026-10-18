# Phase 1 — Modelo de Dados

**Feature**: Sistema de Trânsito e Decoração dos Ambientes
**Branch**: `004-traffic-and-decoration` | **Date**: 2026-10-02

Derivado de `spec.md` (FR-001 a FR-062, SC-001 a SC-027) e das decisões de [research.md](./research.md).

---

## Constantes de conversão

| Constante | Valor | Origem |
|---|---|---|
| `GameConfig.KMH_TO_SPEED_UNIT` | `0.8` | R2: 100 unidades = 125 km/h |
| `GameConfig.max_speed` | `100.0` (= 125 km/h) | SPEC-001, inalterado |

Nenhum outro arquivo de configuração do SPEC-001 é alterado.

---

## 1. `TrafficData` — Resource de categoria de veículo

Representa uma categoria de veículo de trânsito. Fonte: FR-001, FR-011, FR-012, tabela de categorias da spec.

| Campo | Tipo | Valor / Origem | Descrição |
|---|---|---|---|
| `id` | `String` | `caminhao`, `esporte`, `passeio`, `utilitario` | Identificador da categoria |
| `display_name` | `String` | `Caminhão`, `Esporte`, `Passeio`, `Utilitário` | Nome para exibição em PT-BR |
| `assets_path` | `String` | `res://assets/npcs/<id>/` | Pasta exclusiva de assets da categoria (FR-012) |
| `assets` | `Array[String]` | ver tabela abaixo | Arquivos da categoria, sem extensão |
| `max_speed_kmh` | `float` | 90 / 120 / 100 / 90 | Velocidade máxima em km/h |
| `max_speed` | `float` | `max_speed_kmh * 0.8` | Velocidade máxima em unidades do jogo (R2) |
| `frequency` | `float` | configurável por ambiente | Frequência relativa de spawn (FR-010, FR-023) |
| `size` | `Vector2` | medida da textura | Dimensão real, para posicionamento e área ocupada |

### Conteúdo das pastas por categoria

| Categoria | Pasta | Assets | Dimensão | `max_speed` |
|---|---|---|---|---|
| `caminhao` | `assets/npcs/caminhao/` | `caminhao_madeireiro` | 32x128 | 72.0 |
| `esporte` | `assets/npcs/esporte/` | `carro-amarelo`, `carro-laranja`, `carro-verde` | 32x64 | 96.0 |
| `passeio` | `assets/npcs/passeio/` | `carro_01`, `carro_02`, `carro_04`, `carro_07`, `carro_09`, `carro_10` | 32x64 | 80.0 |
| `utilitario` | `assets/npcs/utilitario/` | `Carro-prata`, `carro_03`, `carro_05`, `carro_06`, `carro_08`, `carro_11`, `carro_12` | 32x64 | 72.0 |

**Validações**:
- `max_speed` de toda categoria deve ser **menor** que `GameConfig.max_speed` (FR-008). Margem mínima atual: `esporte` 96.0 vs 100.0.
- `assets` deve ser não vazia; categoria sem asset é removida do sorteio (FR-023, caso de borda de biblioteca vazia).
- `frequency` deve ser `>= 0.0`; categorias com `frequency == 0.0` nunca são sorteadas, mas permanecem configuráveis.

---

## 2. `TrafficVehicle` — Sprite2D de veículo

Instância visual e de estado de um veículo em cena.

| Campo | Tipo | Padrão | Descrição |
|---|---|---|---|
| `category` | `TrafficData` | `null` | Categoria à qual pertence (FR-002) |
| `lane_position` | `float` | `0.0` | Posição horizontal na estrada, em pixels |
| `state` | `enum {ACTIVE, INACTIVE}` | `INACTIVE` | Ciclo de vida (FR-003) |
| `previous_right_boundary` | `float` | `0.0` | Limite direito no quadro anterior, para a interpolação de R8 |
| `reposition_lerp` | `float` | `0.0` | Progresso `0.0..1.0` do reposicionamento em andamento |

**Propriedades derivadas**:
- `speed` → `category.max_speed`, constante enquanto `state == ACTIVE` (velocidade é característica da categoria, FR-011)
- `occupied_area` → `Rect2` centrada em `position`, com `category.size` (FR-025, R10)

**Métodos**:

| Método | Retorno | Descrição |
|---|---|---|
| `activate(category, lane_position, y)` | `void` | Atribui categoria, marca `ACTIVE`, posiciona fora da área visível |
| `deactivate()` | `void` | Marca `INACTIVE`, oculta, devolve ao pool (FR-015, FR-016) |
| `update_scroll(delta, road_speed, bounds)` | `void` | Move pela velocidade relativa e reposiciona por `lerpf` se a faixa estreitou (FR-007, FR-021) |
| `get_occupied_area()` | `Rect2` | Área ocupada, para o SPEC-005 (FR-025, FR-026) |

**Transições de estado**:

```text
         activate()                    deactivate()
INACTIVE ──────────> ACTIVE ──────────────────────────> INACTIVE
   ^                    │
   └────────────────────┘
        devolução ao pool pelo TrafficManager
```

Apenas duas transições existem nesta versão (FR-003): não há estados de colisão, dano ou destruição.

**Validações**:
- Um veículo `ACTIVE` deve estar sempre dentro de `{left, right}` da largura vigente na sua altura (FR-009, SC-001, SC-007).
- `deactivate()` deve ser chamado apenas quando o veículo está **completamente** fora da área visível por qualquer borda (FR-015, FR-016).

---

## 3. `TrafficManager` — Controlador do trânsito

| Campo | Tipo | Padrão | Descrição |
|---|---|---|---|
| `categories` | `Dictionary[String, TrafficData]` | de `GameConfig` | Mapeamento centralizado id → categoria (FR-012, R4) |
| `pool` | `Array[TrafficVehicle]` | `[]` | Conjunto reutilizável, próprio e independente (FR-017) |
| `active_vehicles` | `Array[TrafficVehicle]` | `[]` | Veículos visíveis, para contagem e verificação de espaçamento |
| `last_category_by_side` | `Array` | `[]` | Último índice sorteado, por lado da faixa, para continuidade |

**Parâmetros** (todos em `GameConfig`, FR-023):

| Parâmetro | Padrão | Propósito |
|---|---|---|
| `traffic_enabled` | `true` | Habilitação do trânsito (FR-024) |
| `traffic_max_vehicles` | `12` | Limite de veículos ativos (FR-005) |
| `traffic_spawn_distance` | `260.0` px | Distância acima do topo para criar (FR-013) |
| `traffic_spawn_interval` | `1.2` s | Intervalo entre spawns (FR-004) |
| `traffic_min_spacing` | `70.0` px | Espaçamento longitudinal mínimo (FR-019) |
| `traffic_frequency_<categoria>` | ver abaixo | Frequência por categoria (FR-010) |

Frequências iniciais: `caminhao` 0.15, `utilitario` 0.25, `passeio` 0.35, `esporte` 0.25. Somam 1.0; a validação exige que a soma das frequências seja `> 0.0` e que nenhuma exceda a soma das demais.

**Validações**:
- `pool.size()` pode crescer sob demanda quando não há objeto disponível (FR-018); nunca recusar criação.
- `active_vehicles.size()` **nunca** excede `traffic_max_vehicles` (FR-005, SC-005).
- Com `traffic_enabled == false`, nenhum veículo novo é criado e os existentes seguem seu curso (FR-024).
- Todo veículo criado nasce com `y <= -category.size.y`, nunca dentro da área visível (FR-013, SC-002).

---

## 4. `DecorationData` — Resource de elemento decorativo

Representa um elemento de biblioteca de um ambiente. Fonte: FR-029, tabela de bibliotecas da spec, e R3.

| Campo | Tipo | Valor / Origem | Descrição |
|---|---|---|---|
| `asset` | `String` | nome do arquivo sem extensão | Asset do elemento |
| `texture_path` | `String` | `res://assets/decoracao/<ambiente>/<asset>.png` | Caminho do asset reescalonado (R1) |
| `repeatable` | `bool` | `true` para os 6 assets `arvore` da biblioteca; `false` para os demais | Autoriza repetição consecutiva até 10 (FR-036). Valor de configuração escrito na authoring da biblioteca, **nunca deduzido do nome do arquivo em tempo de execução** (constitution v2.0.0 §Independência de Assets, R3). A string `arvore` é apenas a origem do valor nas tabelas de biblioteca abaixo, não um critério de runtime. |
| `weight` | `float` | percentual de apresentação do elemento, em pontos percentuais (a biblioteca soma 100) | **Meta** declarada em configuração: o que o validador confere e o que se espera observar em partidas longas (FR-036, FR-037) |
| `peso_sorteio` | `float` | derivado de `weight` em runtime por `DecorationManager._compensar_pesos` | Peso efetivo do sorteio entre os candidatos elegíveis. Neutraliza o viés de D6 e D7 para que a frequência observada chegue perto de `weight`; não é configurável. `weight` não é alterado |
| `size` | `Vector2` | medida após reescalonamento | Dimensão real, usada no posicionamento (FR-046) |

### Bibliotecas por ambiente

| Ambiente | Pasta | Assets (tamanho, percentual de apresentação) | Repetíveis |
|---|---|---|---|
| `PLAINS` | `assets/decoracao/planice/` | `planice_arvore01` 49x48 **80%**, `planice_casa01` 96x80 **5%**, `planice_feno01` 32x32 **7%**, `planice_milho` 98x64 **6%**, `planice_silo01` 64x64 **2%** | `planice_arvore01` |
| `DESERT` | `assets/decoracao/deserto/` | `deserto_arvore01` 49x45 **36,5%**, `deserto_arvore02` 49x49 **36,5%**, `deserto_cactus` 32x16 **20%**, `deserto_duna` 32x32 **5%**, `deserto_casa` 96x66 **2%** | `deserto_arvore01`, `deserto_arvore02` |
| `FOREST` | `assets/decoracao/floresta/` | `floresta_arvore01` 49x49 **48%**, `floresta_arvore02` 49x49 **48%**, `floresta_lago` 64x57 **3%**, `floresta_serra` 96x76 **1%** | `floresta_arvore01`, `floresta_arvore02` |
| `ICE` | `assets/decoracao/gelo/` | `gelo_arvore` 49x49 **96%**, `gelo_boneco` 24x18 **3%**, `gelo_casa01` 160x160 **1%** | `gelo_arvore` |

As dimensões são as medidas dos PNGs entregues; os percentuais são os `weight` da configuração (FR-036, FR-037), conferidos por `tools/resize_decoration_assets.py`, que falha se uma biblioteca não somar 100. O percentual de "árvore" de Deserto (73%) e Floresta (96%) é dividido igualmente entre os dois assets de árvore de cada ambiente (atualização de 2026-10-03: base de tile 32x32).

`weight` é a meta; `peso_sorteio` é o peso efetivo que o sorteio usa, derivado dele no `setup` para neutralizar o viés de D6 (não repetir imediatamente) e D7 (limite de 10 seguidas). Mudar `weight` na configuração basta: o peso compensado acompanha, sem tocar em código. Simulação de conferência (500 mil nascimentos por ambiente, sem violação de D6) com os pesos compensados:

| Ambiente | Frequência prevista vs `weight` |
|---|---|
| `PLAINS` | maior desvio de 0,4 p.p. (árvore 79,6% contra 80%) |
| `DESERT` | maior desvio de 0,1 p.p. |
| `FOREST` | maior desvio de 0,1 p.p. |
| `ICE` | árvore ~90,3% (teto de ~90,9% imposto por D7 para 96% declarados); boneco ~7,3% e casa ~2,4%, porque o excedente da árvore se reparte entre eles |

**Validações**:
- `texture_path` deve existir; asset ausente remove o elemento da biblioteca e gera aviso, e a lateral fica sem aquele elemento sem quebrar o jogo (caso de borda "Biblioteca de decoração vazia ou asset ausente").
- Biblioteca com um único elemento: o elemento se repete em sequência, e a repetição não é falha (caso de borda correspondente).

---

## 5. `DecorationElement` — Sprite2D decorativo

| Campo | Tipo | Padrão | Descrição |
|---|---|---|---|
| `data` | `DecorationData` | `null` | Elemento da biblioteca ao qual pertence |
| `side` | `enum {LEFT, RIGHT}` | `LEFT` | Lado da estrada (FR-032) |
| `depth_index` | `int` | `0` | Profundidade, da mais próxima à mais distante (FR-034) |
| `active` | `bool` | `false` | Participa do deslocamento e do recycle |

**Métodos**:

| Método | Retorno | Descrição |
|---|---|---|
| `activate(data, side, depth_index, y)` | `void` | Atribui elemento, marca ativo, posiciona fora da área visível já fora da estrada (FR-041, FR-042) |
| `deactivate()` | `void` | Marca inativo, oculta, devolve ao pool (FR-043) |
| `update_scroll(delta, road_speed, bounds)` | `void` | Move pela velocidade derivada e reposiciona lateralmente ao estreitar (FR-039, FR-051) |
| `is_fully_outside(view_rect)` | `bool` | Verdadeiro quando nenhum pixel está na área visível (FR-043) |
| `update_anchor()` | `void` | Reposiciona a âncora base-centro (R5) |

**Validações**:
- `x` deve estar sempre fora de `[left, right]` acrescido da margem de segurança (FR-033, SC-021).
- Elemento maior que a profundidade disponível é movido para a profundidade mais distante que o comporte (caso de borda correspondente).
- Com o jogador parado, `delta` efetivo é zero: nenhum elemento se desloca, nenhum nasce e nenhum morre (FR-040, FR-041, SC-022).

---

## 6. `DecorationManager` — Controlador da decoração

| Campo | Tipo | Padrão | Descrição |
|---|---|---|---|
| `libraries` | `Dictionary[String, Array[DecorationData]]` | de `GameConfig` | Mapeamento ambiente → biblioteca (FR-029, R4) |
| `current_environment_id` | `String` | de `EnvironmentManager` | Ambiente vigente (FR-028) |
| `pool` | `Array[DecorationElement]` | `[]` | Conjunto reutilizável próprio, independente do de trânsito (FR-044) |
| `active_elements` | `Array[DecorationElement]` | `[]` | Elementos visíveis |
| `last_repeat_by_side` | `Dictionary` | `{}` | Contadores de repetição por lado (FR-036) |

**Parâmetros** (todos em `GameConfig`, FR-056):

| Parâmetro | Padrão | Propósito |
|---|---|---|
| `decoration_enabled` | `true` | Habilitação da decoração |
| `decoration_density` | `1.0` | Programmador de distância média entre elementos (FR-037) |
| `decoration_speed_multiplier` | `0.85` | Velocidade relativa à estrada, estrada = 100% (FR-039, FR-058) |
| `decoration_spacing_min` | `90.0` px | Espaçamento longitudinal mínimo (FR-038) |
| `decoration_spacing_max` | `180.0` px | Espaçamento longitudinal máximo (FR-038) |
| `decoration_depth_count` | `3` | Profundidades por lado (FR-034) |
| `decoration_depth_spacing` | `52.0` px | Espaçamento entre profundidades (FR-034) |
| `decoration_scale` | `1.0` | Escala aplicada ao asset já reescalonado (FR-046) |
| `decoration_safety_margin` | `24.0` px | Margem em relação à borde da área trafegável (FR-033) |
| `decoration_tree_repeat_limit` | `10` | Limite de repetição consecutiva de assets marcados `repeatable` por lado (FR-036) |

**Validações**:
- `decoration_spacing_min <= decoration_spacing_max`, e ambos `> 0.0`.
- `decoration_speed_multiplier >= 0.0`.
- Elementos de profundidades diferentes **podem** se sobrepor na direção lateral; o espaçamento longitudinal não se aplica à posição lateral (FR-038, SC-026).
- `active_elements.size()` permanece limitado e não cresce em partidas longas (FR-043, SC-010, SC-015).

---

## 7. Relações entre entidades

```text
EnvironmentManager (SPEC-003)
        │ current_environment_id
        ▼
DecorationManager ──libraries──► DecorationData (3 a 5 por ambiente)
        │                              │
        │ pool                         │ size (dimensão real)
        ▼                              ▼
DecorationElement ──────────────────────┘
  (side, depth_index)

Road (SPEC-002)
  ├─ get_boundaries_for_player_y(y) ──► TrafficManager    (leitura, FR-050)
  │                                   └─► DecorationManager (leitura, FR-050)
  └─ scroll_speed ────────────────────► ambos (velocidade derivada, FR-039)

GameConfig (autoload)
  ├─ TRAFFIC_CATEGORIES  ──► TrafficData (4 categorias)
  ├─ DECORATION_LIBRARIES ──► DecorationData
  └─ parâmetros de ambos os sistemas

TrafficManager ──pool──► TrafficVehicle (17 assets distribuídos em 4 categorias)
```

**Regras de independência** (FR-054, FR-022, FR-052):
- `TrafficManager` e `DecorationManager` **não** se referenciam.
- Nenhum dos dois altera `Road`, `PlayerVehicle` ou `EnvironmentManager`.
- Ambos consomem `Road` e `EnvironmentManager` **apenas leitura**.

---

## 8. Tabelas de parâmetros expostos ao SPEC-008 (FR-061)

| Sistema | Parâmetros expostos |
|---|---|
| Trânsito | `traffic_enabled`, `traffic_max_vehicles`, `traffic_spawn_distance`, `traffic_spawn_interval`, `traffic_min_spacing`, `traffic_frequency_<categoria>` |
| Decoração | `decoration_enabled`, `decoration_density`, `decoration_speed_multiplier`, `decoration_spacing_min`, `decoration_spacing_max`, `decoration_depth_count`, `decoration_depth_spacing`, `decoration_scale`, `decoration_safety_margin` |

As velocidades máximas por categoria são **dados de identificação**, não parâmetros de ajuste: alterá-las mudaria a identidade da categoria, e a dificuldade ajusta frequência, densidade e quantidade, não a identidade (FR-057).

### Agrupamentos de parâmetros — `traffic_tuning` e `decoration_tuning` (T042)

Além das chaves individuais das tabelas acima, `GameConfig` expõe dois agrupamentos nomeados que as reindexam. Eles existem para que o SPEC-008 leia um agrupamento em vez de percorrer chaves soltas ao montar os controles de dificuldade.

| Agrupamento | Tipo | Origem | Conteúdo |
|---|---|---|---|
| `traffic_tuning` | `Dictionary` | reagrupamento de `traffic_*` | `traffic_enabled`, `traffic_max_vehicles`, `traffic_spawn_distance`, `traffic_spawn_interval`, `traffic_min_spacing`, `traffic_frequency_<categoria>` |
| `decoration_tuning` | `Dictionary` | reagrupamento de `decoration_*` | `decoration_enabled`, `decoration_density`, `decoration_speed_multiplier`, `decoration_spacing_min`, `decoration_spacing_max`, `decoration_depth_count`, `decoration_depth_spacing`, `decoration_scale`, `decoration_safety_margin`, `decoration_tree_repeat_limit` |

Os dois agrupamentos são **somente leitura** nesta versão. A resolução da dificuldade é responsabilidade do SPEC-008; o SPEC-004 apenas expõe a estrutura. As chaves individuais permanecem válidas — os agrupamentos são uma projeção, não uma substituição, de modo que nenhum consumidor de SPEC-001, SPEC-002 ou SPEC-003 é alterado.