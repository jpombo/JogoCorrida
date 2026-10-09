# Contract: Validação de Spawn (FR-028–FR-031)

**Feature**: SPEC-006 | **Versão**: 1.0 (2026-10-07)

Interface entre o gerenciador de trânsito (geração) e o sistema de colisão NPC×NPC (regra da janela). O `TrafficManager` continua dono de spawn, movimento e reciclagem; consulta o validador **somente** para decidir aceitar, reposicionar ou adiar o nascimento.

## Chamada

```
NpcCollisionSystem.validar_spawn(
    categoria: TrafficData,   # veículo pretendido (hitbox/velocidade da categoria)
    x: float,                 # posição lateral pretendida (centro)
    y: float,                 # posição vertical pretendida (acima da área visível)
    bounds: Dictionary        # limites da pista NA ALTURA de criação {left, right}
) -> Dictionary
```

## Retorno

| Chave | Tipo | Significado |
|-------|------|-------------|
| `aceito` | bool | o nascimento em `(x, y)` não cria conflito indesejado |
| `x` | float | posição lateral a usar (pode ser a testada ou uma candidata aceita) |
| `y` | float | posição vertical a usar |
| `adiar` | bool | nenhuma posição/faixa livre neste quadro → manter candidato pendente |

## Regras avaliadas (nesta ordem)

1. **Conflito imediato**: sobreposição com NPC ativo (folga `traffic_min_separation` + hitbox) → recusar a posição. Nenhum NPC nasce sobreposto (FR-031, SC-010).
2. **Distância de segurança**: distância longitudinal até qualquer ativo na mesma trajetória < `npc_spawn_safety_distance` → recusar (FR-028).
3. **Futuro pela janela** (mesma regra da R1): `ttc <= janela` com um ativo → a situação **colidiria dentro da área ativa**, recusar a posição (FR-030). Encontro que só ocorreria **após o descarte** de um dos dois → **aceitar** (não é colisão ativa; SC-010).
4. **Sem opção no quadro**: após esgotar a posição pretendida e as faixas alternativas do `_sortear_faixa_separada` → `{"aceito": false, "adiar": true}`.

## Comportamento do TrafficManager (fluxo do chamador)

```
_tentar_spawn(road):
    ...validações existentes (separação, ordenação, espaçamento)...
    resultado = validador.validar_spawn(categoria, lane, y, bounds)
    if resultado.adiar:
        guarda o candidato em _spawn_pendente (categoria + cronômetro NÃO zerado)
        return                       # nascimento NÃO é perdido (FR-029)
    if not resultado.aceito:
        tenta próxima candidata / próxima faixa (recusa, não adia ainda)
        se esgotou → adia como acima
    activate + append + vehicle_spawned
    # pendente: revalidado a cada quadro em update(), com posições atualizadas
```

## Garantias

- A reposição abaixo de `traffic_min_visible` (FR-063 do SPEC-004) segue intacta: o adiamento é por quadro, nunca até o próximo intervalo (Clarificação Q3, SC-010).
- O limite máximo de ativos (`traffic_max_vehicles` / teto por dificuldade) continua verificado **antes** desta validação (FR-042, SC-011).
- Conflito pós-descarte não bloqueia nascimento (FR-030, SC-010).
- Nenhuma informação de colisão é "resolvida" aqui — a validação só decide o nascimento; o contato real continua sendo do `NpcCollisionSystem` por quadro.
