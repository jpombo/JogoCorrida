# Contract: APIs consumidas pelo Sistema de Colisão

**Feature**: SPEC-005 | **Versão**: 1.2 (2026-10-05 — ajuste 6: retorno do NPC à faixa)

Interfaces **já existentes** que o `CollisionSystem` consome; nenhuma é modificada por esta feature (somente leitura). Documentadas aqui como base de testes de contrato.

## 1. TrafficVehicle → área ocupada (SPEC-004, FR-025)

```
TrafficVehicle.get_occupied_area() -> Rect2
```

- Retorna a área física do NPC centrada em sua posição, derivada de `category.size`.
- O sistema de colisão aplica sobre ela o ajuste de hitbox configurável por categoria (FR-007) — o ajuste é responsabilidade do SPEC-005, sem alterar o método.
- `TrafficVehicle.get_speed() -> float` fornece a velocidade da categoria para a velocidade relativa (FR-024).
- Identidade do par no cooldown: `get_instance_id()` do nó (R5).

## 2. Estrada → limites trafegáveis vigentes (SPEC-002)

```
Road¦TrackManager → limites esquerdo/direito válidos por altura (no quadro corrente)
```

- Mesma fonte já usada por `VehicleController.update_boundaries(left, right)` e pelos `bounds` de `TrafficVehicle.update_scroll`.
- Obrigatoriamente consultada por quadro para o drift do jogador e o deslocamento do NPC (FR-022); nunca uma largura fixa memorizada (FR-023).

## 3. VehicleController → ganchos de controle reduzido e aceleração (aditivo, SPEC-001)

```
VehicleController.control_factor: float = 1.0          # multiplicador da resposta lateral
VehicleController.aceleracao_bloqueada: float = 0.0    # janela (s) em que a aceleração é desconsiderada
```

- `control_factor`: novo, mas inerte por padrão: sem colisão, permanece 1.0 e o comportamento é idêntico ao SPEC-001 (FR-034, SC-010). `DriftState` escreve neste campo durante `drift`/`recuperação`; nenhum outro sistema o toca.
- `aceleracao_bloqueada` (ajuste 4, FR-036): escrito pelo `CollisionSystem` em toda colisão válida com a duração `collision_accel_lockout_time`; decrementado por quadro pelo próprio controller. Enquanto > 0, a ação `accelerate` é desconsiderada (prevalece a desaceleração natural); a ação `brake` continua válida. Inerte em 0.0: sem colisão, caminho de código idêntico ao SPEC-001. `reset()` zera o campo.
- Velocidade: reduzida via API pública existente, sempre ≥ 0 e nunca parada instantânea (FR-009, FR-010).

## 4. TrafficVehicle → deslocamento de ultrapassagem (aditivo, tipo 1-3)

```
TrafficVehicle.apply_overtake_offset(direcao: int, magnitude: float, duracao: float) -> void
```

- Aditivo: só é chamado pelo `CollisionSystem` na colisão 1-3; sem chamada, comportamento idêntico ao SPEC-004.
- Não altera velocidade da categoria nem o estado do pool (FR-017, FR-033).
- Clamp interno pelos `bounds` já recebidos em `update_scroll` (FR-020).
- Retorno (ajuste 6, FR-021): a chamada captura o x atual como faixa de origem; após a ida (`npc_overtake_duration`) o veículo retorna a esse x dentro de `npc_overtake_return_duration` (leitura interna de `GameConfig`, assinatura inalterada) e só então o estado fica inativo — sem deslocamento lateral permanente (SC-014).
