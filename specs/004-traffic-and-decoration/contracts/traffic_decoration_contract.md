# Contrato: TrafficManager e DecorationManager

**Feature**: Sistema de Trânsito e Decoração dos Ambientes
**Branch**: `004-traffic-and-decoration` | **Data**: 2026-10-02

Este documento define as interfaces públicas expostas pelos dois novos sistemas e o contrato que eles **consomem** dos sistemas existentes. Detalhes de campos em [data-model.md](../data-model.md); decisões técnicas em [research.md](../research.md).

Convenção: `void` indica ausência de retorno relevante. Todos os métodos são seguros para chamar com pools vazios.

---

## 1. Contrato consumido — `Road` (SPEC-002, sem alterações)

Os dois sistemas consomem a API existente de `src/road/road.gd`. **`Road` não é modificado** por este spec (FR-022, FR-052).

| Método / propriedade | Tipo | Uso | Garantia |
|---|---|---|---|
| `get_boundaries_for_player_y(y)` | `Dictionary` `{left, right}` | Largura válida da área trafegável na altura `y`, já interpolada durante transições | Devolve `right - left` entre 144.0 (2 vias) e 176.0 (4 vias); para `y` fora de qualquer segmento, devolve os limites padrão |
| `scroll_speed` | `float` | Velocidade de deslocamento da estrada, atualizada a cada quadro | É a referência de 100% (FR-058) |
| `get_left_boundary()` | `float` | Limite esquerdo global | Somente para diagnóstico |
| `get_right_boundary()` | `float` | Limite direito global | Somente para diagnóstico |

**Contrato de largura**: a única fonte de verdade sobre onde a estrada está, em qualquer altura, é `get_boundaries_for_player_y`. Nenhum sistema replica a interpolação de 144→176.

---

## 2. Contrato consumido — `EnvironmentManager` (SPEC-003, sem alterações)

| Método | Tipo | Uso | Garantia |
|---|---|---|---|
| `get_current_environment()` | `EnvironmentData` | Obter o ambiente vigente | Devolve `null` apenas antes de `set_environment` |
| `EnvironmentData.id` | `String` | Chave da biblioteca de decoração | Sempre uma chave presente em `GameConfig.ENVIRONMENTS` |

---

## 3. Contrato consumido — `PlayerVehicle` (SPEC-001, sem alterações)

| Método | Tipo | Uso | Garantia |
|---|---|---|---|
| `get_speed()` | `float` | Alimenta `Road.update_scroll_speed`, que por sua vez alimenta `scroll_speed` | `0.0` quando parado; `<= GameConfig.max_speed` |

`TrafficManager` e `DecorationManager` **não** acessam `PlayerVehicle` diretamente. Ambos consomem apenas `Road.scroll_speed` (R9), o que satisfaz FR-027.

---

## 4. `TrafficManager` — interface pública

Instanciado como `class_name TrafficManager extends Node2D`.

### Propriedades

| Propriedade | Tipo | Leitura | Escrita | Descrição |
|---|---|---|---|---|
| `pool_size` | `int` | leitura | — | Tamanho atual do conjunto reutilizável |
| `active_count` | `int` | leitura | — | Veículos ativos, para verificação de limite |
| `active_vehicles` | `Array[TrafficVehicle]` | leitura | — | Cópia defensiva dos veículos ativos |

### Métodos

| Assinatura | Descrição | Pré-condição | Pós-condição |
|---|---|---|---|
| `setup(categories: Dictionary) -> void` | Recebe as categorias de `GameConfig` | — | `categories` indexado por `id` |
| `update(delta: float, road: Road) -> void` | Atualiza spawn, movimento, repositionamento e reciclagem | Called uma vez por quadro, antes de `PlayerVehicle` | Todos os veículos ativos dentro da área trafegável |
| `set_enabled(enabled: bool) -> void` | Habilita ou desabilita o spawn (FR-024) | — | Com `false`, nenhum veículo novo é criado; existentes seguem movimento normal |
| `get_vehicles_data() -> Array[Dictionary]` | Snapshot `{id, position, occupied_area}` de cada veículo ativo | — | Consumption do SPEC-005 (FR-025) |
| `clear() -> void` | Desativa e esvazia todos os veículos | — | `active_count == 0`; objetos permanecem no pool para reuso |

### Invariantes garantidos

1. **I1** — `active_count <= traffic_max_vehicles`, sempre (FR-005, SC-005).
2. **I2** — Todo veículo `ACTIVE` tem `position.y` dentro de `[left, right]` da largura vigente na sua altura (FR-009, SC-001).
3. **I3** — Todo veículo nasce com `y <= -size.y`, fora da área visível (FR-013, SC-002).
4. **I4** — `category.max_speed < GameConfig.max_speed` para toda categoria ativa (FR-008).
5. **I5** — Todo veículo é `deactivate()`d, e não apenas ocultado, ao sair completamente da área visível (FR-015, FR-016, FR-043 análogo).
6. **I6** — O pool cresce sob demanda em vez de recusar criação (FR-018, SC-025).
7. **I7** — `TrafficManager` não escreve em nenhuma propriedade de `Road` (FR-022).

### Sinalização

| Signal | Assinatura | Quando |
|---|---|---|
| `vehicle_spawned` | `(vehicle: TrafficVehicle)` | Após `activate()` bem-sucedido |
| `vehicle_recycled` | `(vehicle: TrafficVehicle)` | Após `deactivate()` |

Ambos emitidos **apenas** em `ACTIVE` → `INACTIVE` e criação, nunca por quadro — para não gerar custo de sinal em partidas longas.

---

## 5. `DecorationManager` — interface pública

Instanciado como `class_name DecorationManager extends Node2D`.

### Propriedades

| Propriedade | Tipo | Leitura | Escrita | Descrição |
|---|---|---|---|---|
| `pool_size` | `int` | leitura | — | Tamanho do conjunto reutilizável de decoração |
| `active_count` | `int` | leitura | — | Elementos ativos |
| `current_environment_id` | `String` | leitura | via `set_environment()` | Ambiente vigente |

### Métodos

| Assinatura | Descrição | Pré-condição | Pós-condição |
|---|---|---|---|
| `setup(libraries: Dictionary) -> void` | Recebe as bibliotecas de `GameConfig` | — | `libraries` indexado por id de ambiente |
| `set_environment(id: String) -> void` | Troca a biblioteca em uso (FR-031, US6) | `id` presente em `libraries`, ou ausente | Elementos do ambiente anterior são desativados; nenhum da biblioteca antiga permanece em tela (SC-008) |
| `update(delta: float, road: Road) -> void` | Atualiza deslocamento, reposicionamento e reciclagem | Chamado uma vez por quadro, antes de `Road` no pipeline de dados | Nenhum elemento sobre a área trafegável |
| `set_enabled(enabled: bool) -> void` | Habilita ou desabilita a decoração | — | Com `false`, elementos existentes deixam de ser exibidos |
| `get_repeat_state(side: int) -> int` | Sequência atual de repetição do lado indicado | — | Nunca maior que `decoration_tree_repeat_limit` |
| `clear() -> void` | Desativa e esvazia todos os elementos | — | `active_count == 0` |

### Invariantes garantidos

1. **D1** — Todo elemento ativo pertence à biblioteca do ambiente vigente (FR-053, SC-008).
2. **D2** — Todo elemento ativo está fora de `[left, right]` acrescido de `decoration_safety_margin`, em qualquer altura (FR-033, SC-021).
3. **D3** — Todo elemento nasce com `y <= 0` **e** já fora da área trafegável (FR-041, FR-042).
4. **D4** — Elementos são removidos por qualquer borda ao ficarem completamente invisíveis, com `deactivate()` (FR-043, SC-010).
5. **D5** — Com velocidade do jogador `0.0`, nenhum elemento se desloca, nasce ou morre (FR-040, FR-041, SC-022).
6. **D6** — Um mesmo elemento não repetível não aparece duas vezes consecutivas no mesmo lado, enquanto houver alternativa (FR-036, SC-014).
7. **D7** — Um elemento repetível não ultrapassa `decoration_tree_repeat_limit` ocorrências consecutivas no mesmo lado (FR-036, SC-014).
8. **D8** — Os elementos do mesmo lado, somando todas as profundidades, compartilham o contador de repetição (4ª rodada do clarify).
9. **D9** — `DecorationManager` não escreve em nenhuma propriedade de `Road` nem de `EnvironmentManager` (FR-052).
10. **D10** — Os dois pools são independentes: reciclar um nunca afeta o outro (FR-044, FR-054).

### Sinalização

| Signal | Assinatura | Quando |
|---|---|---|
| `environment_changed` | `(new_id: String, old_id: String)` | Após `set_environment()` |
| `element_recycled` | `(element: DecorationElement)` | Após `deactivate()` |
| `library_empty` | `(environment_id: String)` | Quando a biblioteca do ambiente não tem nenhum asset utilizável |

---

## 6. `TrafficVehicle` — interface pública

| Assinatura | Descrição | Quem consome |
|---|---|---|
| `activate(category, lane_position, y) -> void` | Ativa e posiciona fora da área visível | `TrafficManager` |
| `deactivate() -> void` | Desativa para reuso | `TrafficManager` |
| `get_occupied_area() -> Rect2` | Área ocupada, derivada da dimensão real da textura | **SPEC-005** (FR-025) |
| `get_category_id() -> String` | Identificador da categoria | SPEC-005, UI futura |
| `is_active() -> bool` | Estado atual | `TrafficManager` |

`get_occupied_area()` é exposto mas **nenhum sistema deste spec o consome**: FR-026 e FR-062 proíbem colisão nesta versão. O dado existe para o SPEC-005.

---

## 7. `DecorationElement` — interface pública

| Assinatura | Descrição | Quem consome |
|---|---|---|
| `activate(data, side, depth_index, y) -> void` | Ativa e posiciona fora da área visível e da estrada | `DecorationManager` |
| `deactivate() -> void` | Desativa para reuso | `DecorationManager` |
| `get_side() -> int` | `LEFT` ou `RIGHT` | `DecorationManager` |
| `get_depth_index() -> int` | Profundidade atribuída | `DecorationManager` |

Nenhuma área de colisão é exposta: FR-049 exclui decoração de qualquer colisão, inclusive entre decorações.

---

## 8. Contrato de composição da cena

`gameplay_manager.gd` orquestra; nenhum sistema se registra sozinho.

```gdscript
# Ordem de nós em gameplay.tscn — garante renderização (FR-048)
Gameplay
├── BackgroundLayer      # SPEC-003
├── DecorationLayer      # NOVO — antes da estrada
├── Road                 # SPEC-002
├── TrafficLayer         # NOVO — depois da estrada, antes do jogador
└── PlayerVehicle        # SPEC-001

# Ordem de atualização em gameplay_manager._process (FR-055)
1. road.update_scroll_speed(player_vehicle.get_speed())
2. road._process(delta)                          # atualiza scroll_speed
3. decoration_layer.update(delta, road)
4. traffic_layer.update(delta, road)
```

O passo 3 deve ocorrer **antes** do passo 4 para que a decoração reposicionada não seja confundida com veículos na verificação visual de espaçamento, e ambos após o passo 2 para que usem o `scroll_speed` do quadro corrente.

---

## 9. Compatibilidade com testes

GdUnit4 opera sem `Road` real nos testes unitários. Todo método público acima aceita um **`Road` real ou um dublê** que implemente `get_boundaries_for_player_y()` e `scroll_speed`. Isso permite testar I1 a I7 e D1 a D10 sem montar a cena completa, e é o que os testes em `tests/unit/` devem usar.

A lista completa de cenários de validação está em [quickstart.md](../quickstart.md).

### Utilitárias sem task neste ciclo

Quatro assinaturas listadas acima não têm task associada em `tasks.md`. Nenhuma é requisito, invariante ou critério de sucesso — foram mantidas no contrato porque descrevem superfície pública útil, não porque esta versão as precise:

| Assinatura | Seção | Motivo da ausência de task |
|---|---|---|
| `TrafficManager.clear()` | 4 | Convenção de teardown; nenhum requisito a invoca. Se o SPEC-005 precisar, será criada com ele |
| `DecorationManager.clear()` | 5 | Idem |
| `DecorationManager.get_repeat_state(side)` | 5 | Getters de inspeção para D6/D7, que são garantidos pelo contador interno e já asseridos em `tests/unit/test_decoration_manager.gd` |
| `Road.get_left_boundary()` / `get_right_boundary()` | 1 | Já implementados em `src/road/road.gd`; reaproveitados apenas para diagnóstico |

O contrato registra a intenção de superfície pública. `tasks.md` é a autoridade sobre o que esta versão implementa — quando os dois divergirem, as tasks prevalecem.