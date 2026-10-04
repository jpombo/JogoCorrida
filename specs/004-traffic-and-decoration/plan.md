# Implementation Plan: Sistema de Trânsito e Decoração dos Ambientes

**Branch**: `004-traffic-and-decoration` | **Date**: 2026-10-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-traffic-and-decoration/spec.md`

## Summary

Implementar dois sistemas de gameplay visual independentes econfiguráveis sobre a base já existente (SPEC-001 a SPEC-003):

- **Sistema de Trânsito**: veículos de 4 categorias (`caminhao` 90 km/h, `esporte` 120 km/h, `passeio` 100 km/h, `utilitario` 90 km/h), posicionados apenas em faixas válidas da estrada, com deslocamento aparente determinado pela diferença de velocidade em relação ao jogador (125 km/h), recycle por pool de objetos e reposicionamento contínuo durante as transições de 2 para 4 vias.
- **Sistema de Decoração**: biblioteca lateral por ambiente (Planície 5, Deserto 5, Floresta 4, Gelo 3 elementos = 17 no total), distribuída em múltiplas profundidades nos dois lados da estrada, inteiramente fora da área trafegável, com deslocamento derivado da velocidade da estrada e recycle por pool próprio.

Ambos usam pools de objetos reutilizáveis, são inteiramente configuráveis por `GameConfig`, não implementam colisões e não alteram a geometria da estrada.

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.7)

**Primary Dependencies**: Godot Engine 4.7 (rendering: `gl_compatibility`, viewport 640x480, stretch mode `viewport`, texture filter `nearest`)

**Storage**: N/A (configuração em autoload `GameConfig`, sem persistência externa)

**Testing**: GdUnit4 addon (já instalado em `addons/gdUnit4/`), testes em `tests/unit/`

**Target Platform**: Desktop (Linux, Windows, macOS) via Godot export templates

**Project Type**: 2D arcade racing game (pixel art, top-down perspective)

**Performance Goals**: 60 FPS como meta, 30 FPS como piso aceitável, sem quedas recorrentes, com trânsito e decoração ativos simultaneamente nos 4 ambientes (FR-060, SC-024)

**Constraints**:
- Preservar pixel art: sem interpolação, filtro `nearest` obrigatório (FR-047)
- Viewport 640x480; estrada de 144 px (2 vias) a 176 px (4 vias), centralizada com `left_boundary = 248`
- Ordem visual obrigatória: Background → Decoração → Estrada → Trânsito → Jogador → Interface (FR-048)
- Assets de decoração reescalonados com filtro nearest e exibidos em escala 1.0 (FR-046)
- Reuso de objetos obrigatório; sem alocação por quadro (FR-017, FR-044, FR-060)

**Scale/Scope**: 4 categorias de veículo (17 assets), 4 bibliotecas de decoração (17 assets: PLAINS 5, DESERT 5, FOREST 4, ICE 3), 2 pools de objetos reusáveis, ~8-user-stories, nenhuma colisão

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Status | Verificação |
|-----------|--------|-------------|
| I. Controles Simples, Gameplay Profundo | ✅ PASS | Nenhum controle novo; os 4 controles do jogador permanecem idênticos (US8) |
| II. Prioridade da Experiência do Jogador | ✅ PASS | prioridade na ordem: jogabilidade > simplicidade > manutenção > testabilidade > performance > visual |
| III. Arquitetura Modular | ✅ PASS | `TrafficManager`/`TrafficVehicle` e `DecorationManager`/`DecorationElement` com responsabilidades separadas; FR-054 exige independência entre os dois; FR-022 e FR-052 impedem alteração da geometria da estrada |
| IV. Design Orientado a Configuração | ✅ PASS | todos os parâmetros em `GameConfig` (FR-023, FR-056); sem magic numbers |
| V. Autoridade da Constituição e Proteção de Escopo | ✅ PASS | Colisões, dano, drift, combustível, vitória, dificuldade e IA explicitamente fora de escopo (FR-062). **Conforme desde a constitution v2.0.0**, que reescreve o MUST de colisão de trânsito: o veículo MUST fornecer identificação, posição e área ocupada, e a detecção/resolução de colisão é atribuída ao SPEC-005 (R10). FR-026 e FR-049 em conformidade direta. |
| VI. Suporte Multilíngue e Língua da Documentação | ✅ PASS | Constitution v2.0.0: pt-BR é a língua de autoria e padrão; en-US entra por spec dedicada de localização e **nenhuma feature pode ser bloqueada por essa dívida**. Os 4 `display_name` novos estão externalizados em `GameConfig` (sem literais em script), atendendo ao SHOULD de textos externalizados. Toda a documentação do feature está em pt-BR. |
| Câmera e Apresentação | ✅ PASS | pixel art preservado; ordem de renderização conforme FR-048. Ver R1 para a interpretação de "consistent pixel scale" |
| Independência de Assets | ✅ PASS | FR-012: lógica não depende do nome físico dos arquivos. Constitution v2.0.0: classificação de asset MUST ser dado de configuração — FR-036/SC-014 reescritas e R3 implementa `repeatable: bool` |
| Performance | ✅ PASS | pools reusáveis; sem criação por quadro; meta 60 FPS com piso 30 FPS |
| Testes | ✅ PASS | Constitution v2.0.0 tornou MUST a cobertura de spawn, reciclagem, seleção e posicionamento — 9 suítes em `tests/unit/` |
| Qualidade de Código | ✅ PASS | responsabilidade única por script; sem duplicação de lógica |

**Resultado: Todos os gates PASS contra a constitution v2.0.0 (ratificada 2026-09-18, emendada 2026-10-02). Sem violações a justificar. Os gates ⚠️ registrados antes da emenda foram reavaliados após a ratificação.**

### Gate resolvido antes da pesquisa

A verificação das dimensões reais dos 18 assets de decoração (Phase 0, R1) mostrou que **11 deles não são divisíveis por nenhum fator inteiro maior que 1**, o que tornava inaplicável o requisito de "fator inteiro" registrado na 4ª rodada de `/speckit.clarify`. O gate foi bloqueado, o usuário aprovou a correção, e FR-046, FR-047, SC-027, o caso de borda e a premissa passaram a exigir **reescalonamento com filtro de vizinho mais próximo, exibido em escala 1.0**. Detalhes em [research.md](./research.md) (R1) e na nota correspondente de `checklists/requirements.md`.

## Project Structure

### Documentation (this feature)

```text
specs/004-traffic-and-decoration/
├── spec.md              # Especificação da feature
├── plan.md              # Este arquivo
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── traffic_decoration_contract.md
├── checklists/
│   └── requirements.md  # Quality checklist
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
src/
├── config/
│   └── game_config.gd            # Adicionar: TRAFFIC_CATEGORIES, DECORATION_LIBRARIES e todos os parâmetros
├── game/
│   ├── gameplay.tscn             # Adicionar: DecorationLayer (após BackgroundLayer), TrafficLayer (após Road)
│   └── gameplay_manager.gd       # Adicionar: refs às camadas, ordem de atualização, troca de ambiente
├── traffic/
│   ├── traffic_data.gd           # NOVO: Resource de dados da categoria (id, pasta, v_max, frequência)
│   ├── traffic_vehicle.gd        # NOVO: Sprite2D de veículo (categoria, faixa, estado, área ocupada)
│   └── traffic_manager.gd        # NOVO: spawn, seleção de categoria, posicionamento, pool, reciclagem
├── decoration/
│   ├── decoration_data.gd        # NOVO: Resource de elemento (asset, lado, profundidade, repetível)
│   ├── decoration_element.gd     # NOVO: Sprite2D decorativo (posição lateral, profundidade, reciclagem)
│   └── decoration_manager.gd     # NOVO: ambiente → biblioteca, distribuição, deslocamento, pool
├── environment/                  # Sem alterações (EnvironmentManager já expõe o ambiente atual)
├── player/                       # Sem alterações
└── road/                         # Sem alterações (só leitura de limites e scroll_speed)

tests/
└── unit/
    ├── test_traffic_manager.gd              # NOVO
    ├── test_traffic_categories.gd           # NOVO
    ├── test_decoration_manager.gd           # NOVO
    ├── test_decoration_libraries.gd         # NOVO
    ├── test_decoration_config.gd            # NOVO — invariantes de configuração (T040)
    ├── test_spec004_regression.gd           # NOVO — regressão SPEC-001/002/003 (T044)
    ├── test_no_collision.gd                 # NOVO — ausência de colisão (T047)
    ├── test_performance_traffic_decoration.gd  # NOVO — 60/30 FPS (T048)
    └── test_memory_stability.gd             # NOVO — 10 min sem crescimento (T049)

assets/
├── decoracao/{planice,deserto,floresta,gelo}/  # 17 PNGs — base de tile 32x32, resolução final (2026-10-03)
├── decoracao/_originais/                     # Backup dos 18 PNGs originais
└── npcs/{caminhao,esporte,passeio,utilitario}/  # 1+3+6+7 PNGs

tools/
└── resize_decoration_assets.py               # Validador somente leitura da entrega (antes: reescalonador nearest)
```

**Structure Decision**: Adotada a estrutura existente do projeto. Módulos novos em `src/traffic/` e `src/decoration/`, seguindo o padrão de `src/environment/` (um `Resource` de dados + um manager + um controller visual por sistema). Nenhum arquivo existente é reestruturado. A inserção no scene tree respeita FR-048: `Gameplay → BackgroundLayer → DecorationLayer → Road → TrafficLayer → PlayerVehicle`.

### Exceção de escopo justificada (T060): `class_name` em `Road` e `PlayerVehicle`

`src/road/road.gd` e `src/player/player_vehicle.gd` receberam **uma linha cada** — `class_name Road` e `class_name PlayerVehicle`, na primeira linha. Nenhum comportamento, método ou propriedade dos dois sistemas foi alterado (verificável por `git diff`).

**Por que é necessária**: o contrato §4/§5 assina `update(delta: float, road: Road)` e o GDScript recusa em **tempo de execução** qualquer objeto que não seja `Road`. A única forma de os testes unitários (contrato §9) passarem um dublê mínimo — que anula `_ready`, o pool de segmentos e o scroll próprio — é `class FakeRoad: extends Road`, e `extends Road` exige o `class_name`. A alternativa válida (tipar o parâmetro como `Node`/`Object` e checar a superfície com `has_method`) enfraqueceria o contrato público para acomodar o teste, invertendo a prioridade da constitution v2.0.0 §II (testabilidade antes de polimento, nunca antes da clareza da implementação).

**Por que é aceitável**: `class_name` é declaração de tipo, não comportamento. SPEC-002 continua dono da estrada e SPEC-001 do jogador; o diff sobre os dois specs concluídos permanece aditivo e de uma linha. O caso fica registrado aqui para que a T053 possa confirmar que, **fora essas duas linhas declaradas**, `src/road/`, `src/player/`, `src/environment/` e `src/game/game_state.gd` estão sem modificações.

## Re-avaliação do Constitution Check (após Phase 1)

| Princípio | Status | Verificação pós-design |
|---|---|---|
| III. Arquitetura Modular | ✅ PASS | `traffic_data/traffic_vehicle/traffic_manager` e `decoration_data/decoration_element/decoration_manager` — 6 scripts, responsabilidade única cada, seguindo o padrão de `src/environment/`. `Road` não recebe nenhuma linha nova (contrato consome 3 métodos existentes) |
| IV. Design Orientado a Configuração | ✅ PASS | Nenhum valor de ajuste no código: 10 parâmetros de trânsito (6 grupos, com frequência expandida por categoria) e 10 de decoração em `GameConfig`, conforme tabela de [data-model.md](./data-model.md) |
| Independência de Assets | ✅ PASS | R3 elimina a comparação de string em runtime; R4 substitui `DirAccess` por listas de configuração. `Road` e `PlayerVehicle` intocados |
| Performance | ✅ PASS | Pools próprios em ambos os sistemas; nenhum `new` dentro de `_process`; propagação por lista ordenada sem alocação (R9) |
| Testes | ✅ PASS | Contrato aceita `Road` dublê com 2 membros; 17 invariantes (I1–I7, D1–D10) verificáveis sem montar a cena |
| Proteção de Escopo | ✅ PASS | Nenhuma alteração em SPEC-001/002/003; `max_speed` preservado em 100.0 (R2). Constitution v2.0.0 §Trânsito: veículos MUST NOT detectar nem resolver colisões até o SPEC-005 |

**Resultado: gates mantidos PASS após o design. Complexity Tracking continua não aplicável.**

## Complexity Tracking

Sem violações de constituição — seção não aplicável.