# Research: Road Scrolling System

**Feature**: 002-road-scrolling-system
**Date**: 2026-09-18

## Research Tasks

### 1. Pool de Segmentos para Scrolling Vertical

**Decisão**: Pool simples de N segmentos pré-alocados, reutilizados quando saem da área visível.

**Racional**:
- Evita criação/destruição de objetos por frame (performance)
- Segue princípio de "reuse objects where practical" da constituição
- Complexidade menor que sistema de corte/merge de segmentos

**Alternativas consideradas**:
- Array dinâmico: Criaria e destruiria objetos, causando garbage collection
- Duas filas separadas: Complexidade desnecessária para o escopo atual

**Implementação**:
```text
Pool size = ceil(screen_height / segment_height) + 2 buffer
```

---

### 2. Dimensões dos Assets

**Decisão**: Obter dimensões reais dos assets via `get_texture().get_size()` no runtime.

**Racional**:
- FR-009: "Road segments MUST obtain real dimensions from assets (not hardcoded)"
- Permite substituir assets sem alterar código
- Alinha com princípio de Asset Independence

**Alternativas consideradas**:
- Hardcoding dimensões: Viola FR-009 e princípios de independência
- Usar constantes configuráveis: Mais flexível mas requer atualização manual

---

### 3. Alinhamento Horizontal de Segmentos

**Decisão**: Alinhar todos os segmentos pela borda esquerda da estrada.

**Racional**:
- Clarificação do usuário: "Alinhar todos os segmentos pela borda esquerda"
- Consistente com limites atuais (road_left_boundary = 100px)
- Expansão para 4 vias cresce para a direita (Asset Independente)

**Implementação**:
```text
segment.position.x = road_left_boundary
```

---

### 4. Cálculo de Velocidade de Scrolling

**Decisão**: `road_scroll_speed = player_speed × scroll_multiplier`

**Racional**:
- Relação linear direta e contínua
- scroll_multiplier configurável em GameConfig
- Segue Configuration-Driven Design

**Parâmetros**:
- `scroll_multiplier`: Fator de escala (valor inicial: 1.0, ajustável)
- `player_speed`: Velocidade atual do VehicleController

---

### 5. Reciclagem de Segmentos

**Decisão**: Quando segmento sai da área visível (y > screen_height + buffer), reposicionar acima da tela.

**Racional**:
- Cria loop contínuo sem gaps
- Buffer evita flickering nas bordas
- Alinha com US2 (Road Loop and Segments)

**Implementação**:
```text
if segment.position.y > screen_height + buffer:
    segment.position.y -= (pool_size × segment_height)
```

---

### 6. Fallback para Assets Ausentes

**Decisão**: Usar placeholder visual (quadrado cinza 32x32) e logar warning.

**Racional**:
- Clarificação do usuário: "Usar placeholder visual e logar erro, continuar jogo"
- Permite testes mesmo com assets faltantes
- Alinha com robustez e experiência do jogador

**Implementação**:
```text
if not ResourceLoader.exists(path):
    push_warning("Road asset not found: " + path)
    texture = placeholder_texture
```

---

### 7. Limites Dinâmicos da Estrada

**Decisão**: Atualizar limites imediatamente ao processar cada segmento com largura diferente.

**Racional**:
- Clarificação do usuário: "Atualizar limites imediatamente conforme cada segmento é processado"
- Mantém consistência entre visual e colisão
- Segmentos de expansão/redução alteram limites gradualmente

**Implementação**:
- Segmento reto 2 vias: limites atuais (100-540)
- Segmento expansão: limites expandidos (ex: 100-580)
- Segmento redução: limites reduzidos (ex: 100-500)

---

### 8. Renderização Pixel-Art

**Decisão**: Usar `texture_filter = Nearest` nos Sprite2D dos segmentos.

**Racional**:
- FR-010: "Road MUST maintain pixel-art rendering characteristics"
- Preserva características visuais do projeto
- Alinha com Camera and Presentation da constituição

**Alternativas consideradas**:
- Linear filtering: Causaria suavização indesejada
- CanvasItem default: Pode variar entre platforms

---

## Resumo das Decisões

| Decisão | Escolha | Complexidade |
|---------|---------|--------------|
| Armazenamento | Pool pré-alocado | Baixa |
| Dimensões | Runtime via texture | Baixa |
| Alinhamento | Borda esquerda | Baixa |
| Scrolling | speed × multiplier | Baixa |
| Reciclagem | Reposicionar acima | Baixa |
| Fallback | Placeholder + warning | Baixa |
| Limites | Atualização imediata | Média |
| Rendering | Nearest filter | Baixa |
