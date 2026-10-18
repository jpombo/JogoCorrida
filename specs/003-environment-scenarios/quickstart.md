# Quickstart: Validação do Sistema de Ambientes e Cenários

**Feature**: SPEC-003 — Environment Scenarios
**Date**: 2026-09-23

## Pré-requisitos

- Godot Engine 4.7 instalado
- Projeto JogoCorrida aberto no Godot
- Branch `003-environment-scenarios` ativa
- Assets de background presentes em `assets/background/` com resolução **640x480** (nativa da viewport)

## Cenário 1 — Background PLAINS (Padrão)

**Objetivo**: Verificar que o ambiente padrão é PLAINS com background de grama.

**Passos**:
1. Abrir `src/game/gameplay.tscn` no Godot
2. Iniciar o jogo (F5 ou Play)
3. Verificar que o background exibe textura de grama cobrindo toda a tela
4. Verificar que a estrada está visível sobre o background
5. Verificar que o veículo do jogador está visível sobre a estrada

**Resultado esperado**: Tela com background de grama, estrada ao centro, veículo visível. Sem espaços vazios ou bordas.

---

## Cenário 2 — Troca de Ambiente

**Objetivo**: Verificar que a troca de ambiente por configuração funciona.

**Passos**:
1. No Godot, acessar `GameConfig` no Inspector (autoload)
2. Alterar `current_environment_id` para `"DESERT"`
3. Reiniciar o jogo (F5)
4. Verificar que o background exibe textura de areia
5. Repetir para `"FOREST"` (floresta) e `"ICE"` (gelo)

**Resultado esperado**: Cada valor de `current_environment_id` carrega o background correspondente.

---

## Cenário 3 — Scroll do Background

**Objetivo**: Verificar que o background se move em sincronia com a estrada.

**Passos**:
1. Iniciar o jogo com ambiente PLAINS
2. Acelerar o veículo (tecla W ou Setinha para cima)
3. Observar que o background se move para baixo (mesma direção que a estrada)
4. Verificar que a velocidade visual do background é menor que a da estrada (multiplicador < 1)
5. Frear o veículo (tecla S ou Setinha para baixo)
6. Verificar que a velocidade do background diminui proporcionalmente
7. Parar o veículo completamente
8. Verificar que o background para de se mover

**Resultado esperado**: Background sincronizado com a estrada, mais lento, para quando o jogador para.

---

## Cenário 4 — Repetição Seamless

**Objetivo**: Verificar que a textura repete sem bordas visíveis.

**Passos**:
1. Iniciar o jogo com ambiente PLAINS
2. Acelerar e manter velocidade constante
3. Observar a junção entre repetições da textura
4. Verificar que não há linhas, bordas ou cortes visíveis
5. Repetir para os 4 ambientes

**Resultado esperado**: Transições invisíveis entre repetições da textura em todos os ambientes.

---

## Cenário 4.1 — Resolução e Nitidez do Background (Ajuste)

**Objetivo**: Verificar que o background é exibido em resolução nativa 640x480, sem desfoque.

**Passos**:
1. Iniciar o jogo com ambiente PLAINS
2. Observar a nitidez da textura de grama em toda a tela
3. Verificar que não há desfoque, suavização ou escala visível
4. Repetir para os 4 ambientes

**Resultado esperado**: Background nítido em todos os ambientes (assets 640x480 renderizados em escala 1:1 com filtro NEAREST).

---

## Cenário 5 — Regressão da Estrada

**Objetivo**: Verificar que as funcionalidades do SPEC-002 continuam funcionando.

**Passos**:
1. Iniciar o jogo com ambiente DESERT
2. Acelerar e verificar scrolling da estrada
3. Mover veículo para esquerda e direita
4. Verificar limites da estrada (não sair da pista)
5. Aguardar transição de 2 para 4 vias
6. Verificar que a expansão ocorre normalmente sobre o background
7. Aguardar redução de volta para 2 vias
8. Verificar que a redução ocorre normalmente

**Resultado esperado**: Todas as funcionalidades da estrada funcionam sobre qualquer background.

---

## Cenário 6 — Fallback de Asset

**Objetivo**: Verificar comportamento com asset inexistente.

**Passos**:
1. No `GameConfig`, alterar o `texture_path` de PLAINS para um caminho inexistente (ex: `"res://assets/background/NAOEXISTE.png"`)
2. Iniciar o jogo
3. Verificar no console do Godot que há mensagem de warning
4. Verificar que o jogo continua jogável (fallback para textura padrão)

**Resultado esperado**: Warning no console + jogo continua funcionando com textura de fallback.

---

## Cenário 7 — Dificuldade por Ambiente

**Objetivo**: Verificar que cada ambiente fornece sua dificuldade base.

**Passos**:
1. No Godot, acessar o console (print)
2. Para cada ambiente, chamar `EnvironmentManager.get_difficulty()`
3. Verificar: PLAINS=1, DESERT=2, FOREST=3, ICE=4

**Resultado esperado**: Valores de dificuldade corretos para cada ambiente.

---

## Comandos de Validação Automatizada (GdUnit4)

```gdscript
# Executar todos os testes existentes (regressão)
# No Godot: Scene > Run GdUnit Tests

# Testes esperados para SPEC-003 (adicionar em tests/unit/):
# - test_environment_data_creation
# - test_environment_manager_set_valid_id
# - test_environment_manager_set_invalid_id_fallback
# - test_environment_difficulty_values
# - test_background_controller_texture_loading
# - test_background_controller_scroll_sync
# - test_background_controller_scroll_stop_at_zero
```
