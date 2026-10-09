# Specification Quality Checklist: Sistema de Colisão entre NPCs

**Purpose**: Validar completude e qualidade da especificação antes de prosseguir para planejamento
**Created**: 2026-10-07
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Todos os 16 itens passam na 1ª validação; 0 marcadores `[NEEDS CLARIFICATION]`. As decisões não especificadas pelo texto-fonte foram resolvidas por premissas documentadas na seção **Assumptions** (escopo das consequências de colisão da constituição, escopo da detecção atribuída a componente dedicado, corredores reservados por velocidade, reutilização das áreas físicas e do teto de NPCs do SPEC-004, convenção de intensidade da SPEC-005), sem bloquear o planejamento.
- Estrutura: 9 histórias de usuário priorizadas (P1: US1–US5 e US9; P2: US6–US8), 45 requisitos funcionais (FR-001 a FR-045, em 8 grupos temáticos), 19 critérios de sucesso (SC-001 a SC-019), 7 entidades-chave, 13 casos de borda e 16 premissas.
- **Cobertura dos 26 testes obrigatórios do texto-fonte**: mapeados 1 a 1 nas Acceptance Scenarios das nove histórias (US2 = testes 1–4; US1 = 5; US3 = 6; US4 = 7, 8, 9, 25, 26; US5 = 10–14; US7 = 15–18; US8 = 20–23; US9 = 19, 24; US6 = estado e evento). O mapeamento está registrado na seção Assumptions.
- **Cobertura das 28 regras de gameplay do texto-fonte**: todas repercutem em FRs — 1/2/7 → FR-007; 3/4 → FR-003/FR-004; 5 → FR-005/FR-030; 6/7 → SC-001; 8/9 → FR-014; 10 → FR-016; 11/12 → FR-019; 13 → FR-018/SC-006; 14/15/16 → FR-024/FR-025; 17 → FR-026; 18 → FR-023; 19 → FR-017/SC-014; 20 → FR-042; 21/22/23/24 → FR-032 a FR-034; 25 → FR-009; 26 → FR-037/FR-038; 27 → FR-040; 28 → FR-028 a FR-031.
- **Dependência da constituição resolvida na spec**: §Comportamento de Colisão (redução de velocidade e combustível) interpretado como escopo do veículo do jogador — justificado porque NPCs não têm combustível e a constituição proíbe alteração permanente da velocidade do NPC; §Trânsito interpretado como detecção por componente dedicado, mantendo os veículos apenas expondo identificação, posição e área ocupada (contrato do SPEC-004). Ambas as leituras estão registradas em Assumptions para conferência no `/speckit.analyze`.
- **Fora de escopo** registrado com base na lista explícita do texto-fonte, incluindo a exclusão da colisão jogador×NPC (SPEC-005), combustível, destruição, física realista, IA e pontuação.
- Os termos "hitbox/área física", "evento", "drift", "cadeia", "janela de atividade" e os nomes de parâmetros (`npc_*`) vêm do texto-fonte e denotam **o quê** (conceitos de gameplay e ajuste), não **como**: nenhum idioma, framework, arquivo, classe ou API é citado no corpo dos requisitos; os nomes de parâmetros são declarados como "nomes de referência, adaptáveis à convenção do projeto", mesma convenção adotada pela SPEC-005.
