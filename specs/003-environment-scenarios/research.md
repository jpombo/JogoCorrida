# Research: Sistema de Ambientes e Cenários

**Feature**: SPEC-003 — Environment Scenarios
**Date**: 2026-09-23

## R-001: Mecanismo de Repetição Seamless Vertical

**Decision**: Utilizar dois Sprite2D alternando (double-buffering vertical) para simular scroll contínuo de textura seamless.

**Rationale**: O `Road` já utiliza um object pool de Sprite2D com reciclagem para scroll de segmentos. O mesmo padrão se aplica ao background: dois sprites empilhados verticalmente, onde o que sai pela parte inferior é reposicionado acima. Isso garante cobertura contínua sem buracos.

**Alternatives considered**:
- *Shader de repetição*: Mais elegante mas mais complexo; viola princípio de simplicidade (Constituição II). Requer shader customizado e pode ter compatibilidade com gl_compatibility.
- *TextureRepeat no material*: Godot suporta `REPEAT` no texture_filter, mas não resolve o scroll automático — ainda precisaria de lógica de movimento.
- *Sprite2D único com offset*: Causaria buraco na parte superior durante scroll — não cobre a tela inteira.

**Conclusion**: Dois Sprite2D com reciclagem é a abordagem mais simples, testada (Road já usa padrão similar), e compatível com pixel art.

---

## R-002: Integração com Sistema de Scroll Existente

**Decision**: `BackgroundController` recebe a velocidade de scroll do `GameplayManager` via sinal ou chamada direta, aplicando o `background_multiplier`.

**Rationale**: O `GameplayManager` já calcula `road_scroll_speed` baseado na velocidade do jogador (`vehicle_controller.get_current_speed()`). O background deve derivar sua velocidade dessa mesma fonte, não de uma cópia independente. Isso mantém a sincronização sem acoplamento direto entre Road e Background.

**Alternatives considered**:
- *Background lê velocidade diretamente do PlayerVehicle*: Acoplaria background ao player, violando separação de responsabilidades (Constituição III).
- *Background gerencia seu próprio scroll baseado em tempo*: Duplicaria lógica de cálculo de velocidade; conflitaria com estado de pausa.
- *Road emite sinal de scroll*: Road não deveria saber que background existe; violaria independência de sistemas.

**Conclusion**: GameplayManager como orquestrador central é o local correto — ele já gerencia a sincronização Road↔Player e pode estender para Background sem novos acoplamentos.

---

## R-003: Estrutura de Dados do Ambiente

**Decision**: Dicionário constante `ENVIRONMENTS` no `GameConfig`, com cada entrada sendo um Dictionary contendo `id`, `display_name`, `texture_path` e `difficulty`.

**Rationale**: Segue o princípio Configuration-Driven (Constituição IV). Dicionário centralizado é acessível globalmente via autoload, permite lookup por ID, e é trivialmente extensível para novos ambientes. Alinha com a decisão de clarificação (FR-009: dicionário centralizado).

**Alternatives considered**:
- *Resource do Godot (custom resource)*: Mais robusto mas introduz tipo customizado; desnecessário para dados estáticos simples.
- *JSON externo*: Adiciona I/O assíncrono e tratamento de erros de parse; sem benefício para dados que mudam raramente.
- *Array com busca por índice*: Menos legível que lookup por string ID.

**Conclusion**: Dicionário em GDScript é a forma mais direta e idiomática para configuração estática no Godot.

---

## R-004: Fallback para Asset Inexistente

**Decision**: Se a textura de background não for encontrada, carregar a textura de PLAINS como fallback e emitir `push_warning()` no console.

**Rationale**: Decisão de clarificação aceita pelo usuário. `push_warning()` é o mecanismo nativo do Godot para warnings. Fallback para PLAINS garante que o jogo permanece jogável (Constituição II: Player Experience Priority).

**Alternatives considered**:
- *Tela preta com erro*: Compromete experiência do jogador; viola Prioridade II.
- *Criar textura procedural*: Complexidade desnecessária; viola simplicidade.

**Conclusion**: Fallback + warning é padrão robusto para games; PLAINS como fallback é a escolha mais neutra (dificuldade 1, visual mais genérico).

---

## R-005: Ordem de Renderização no Scene Tree

**Decision**: Adicionar `BackgroundLayer` (Node2D) como primeiro filho de `Gameplay`, antes de `Road` e `PlayerVehicle`.

**Rationale**: No Godot, a ordem de renderização segue a ordem dos nós no scene tree (primeiro filho = desenhado primeiro = fica atrás). Inserir BackgroundLayer antes de Road garante que o background fique atrás da estrada, que fica atrás do jogador. Alinha com FR-011 e CA-07.

**Alternatives considered**:
- *Usar z-index*: Funciona mas é menos explícito; a ordem no tree já é suficiente e mais legível.
- *CanvasLayer separado*: Introduz camada de UI; desnecessário para background que deve scrollear junto com o mundo.

**Conclusion**: Node2D como primeiro filho é a abordagem mais simples e idiomática do Godot.

---

## R-006: Propriedades Configuráveis do Background

**Decision**: Adicionar ao `GameConfig` as seguintes propriedades: `background_multiplier` (float, padrão 0.6), `current_environment_id` (String, padrão "PLAINS").

**Rationale**: Segue Configuration-Driven (Constituição IV). `background_multiplier` controla a razão entre velocidade do background e da estrada (prepara para parallax futuro, FR-012). `current_environment_id` permite trocar ambiente por configuração (FR-009, CA-10).

**Alternatives considered**:
- *Variável global direta*: Viola Configuration-Driven; harder to test.
- *Configuração por scene*: Dificulta acesso global; fragmenta configuração.

**Conclusion**: Adicionar ao GameConfig existente mantém consistência com o padrão já adotado pelo projeto.

---

## R-007: Pixel Art e Filtro de Textura

**Decision**: Configurar os Sprite2D do background com `texture_filter = TEXTURE_FILTER_NEAREST` (já é o padrão global do projeto em project.godot: `default_texture_filter=0`). Durante a implementação, o filtro também é definido explicitamente por sprite para garantir robustez local.

**Rationale**: O projeto já configura filtro nearest-neighbor globalmente. A definição local reforça a preservação de pixel art (FR-015) mesmo que o padrão global seja alterado no futuro.

**Alternatives considered**:
- *Shador customizado*: Complexidade desnecessária.

**Conclusion**: Definir o filtro por sprite (além do global) é uma camada de robustez sem custo perceptível.

---

## R-008: Resolução Nativa dos Assets de Background (Ajuste)

**Decision**: Os quatro assets de background foram redimensionados para **640x480** (resolução idêntica à viewport) e o `BackgroundController` passou a renderizá-los em escala nativa (`scale = Vector2.ONE`), sem upscaling.

**Rationale**: Com assets de 32x32 havia necessidade de escalonar para cobrir 640x480, o que podia gerar borramento visual. Ao dimensionar os assets para 640x480, a textura cobre exatamente a tela sem escala fracionária, preservando a qualidade da pixel art (FR-015, SC-010). O pool de 2 sprites com reciclagem vertical (R-001) continua sendo usado apenas para o scroll vertical contínuo.

**Alternatives considered**:
- *Manter 32x32 com escala uniforme para 640*: Introduz escala fracionária e possível perda de nitidez; descartado após testes visuais.
- *Usar shader de repetição*: Complexidade desnecessária (mesma avaliação do R-001).

**Conclusion**: Assets na resolução da viewport (640x480) com reciclagem de 2 sprites é a abordagem mais simples e nítida. A lógica de tiling/escala para texturas pequenas foi removida do controlador.
