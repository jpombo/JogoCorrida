# Specification Quality Checklist: Sistema de Combustível

**Purpose**: Validar completude e qualidade da especificação antes de prosseguir para planejamento
**Created**: 2026-10-09
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

- Validação final: **16 de 16 itens aprovados; 0 marcadores `[NEEDS CLARIFICATION]`**. A única ambiguidade encontrada (FR-025 — o texto-fonte exige interface com "padrão já utilizado no projeto", mas o projeto não possui nenhuma interface: verificado em `src/`, sem UIManager nem indicadores em cena) foi apresentada ao usuário durante o comando e resolvida: **indicador visual mínimo** (barra + sinalização de baixo, sem sons/animações), registrada na seção Clarifications da spec e incorporada a FR-025, US4, SC-015 e Assumptions.
- Estrutura: 5 histórias de usuário priorizadas (P1: US1–US3; P2: US4–US5), 34 requisitos funcionais (FR-001 a FR-034, em 7 grupos temáticos), 17 critérios de sucesso (SC-001 a SC-017), 6 entidades-chave, 16 casos de borda e 14 premissas.
- **Cobertura dos 27 testes obrigatórios do texto-fonte**: **cobertos pelas** Acceptance Scenarios — os 27 testes do texto-fonte não correspondem 1 a 1 aos 31 cenários (US1 = testes 1–10 / 10 cenários; US2 = 16–25 / 10; US3 = 11–14 / 5 — AS5 garantido por T010 e pelo passo 8 do quickstart; US4 = 15, 26 / 4 — AS2/AS3/AS4 pelo teste 26; US5 = 27 / 2 — AS2 na calibração T018) e registrados na seção Assumptions, atendendo à exigência explícita de testes do texto-fonte para o plano de tarefas.
- **Cobertura das 28 regras de gameplay do texto-fonte**: todas mapeadas a FRs na premissa "Cobertura das 28 regras de gameplay" da seção Assumptions.
- **Cobertura dos critérios de aceitação do texto-fonte (seção 17)**: inicialização → FR-001 a FR-003/SC-001/SC-002; consumo → FR-004 a FR-010/SC-003 a SC-006; penalidades → FR-011 a FR-017/SC-008 a SC-012; limites → FR-010/FR-017/FR-020/SC-007; esgotamento → FR-018 a FR-021/SC-013; interface → FR-022 a FR-025/SC-014/SC-015; integração → FR-026 a FR-034/SC-016/SC-017.
- **Dependência da constituição resolvida na spec**: §Comportamento de Colisão ("consumir combustível adicional") interpretado como escopo do veículo do jogador, único com combustível, com penalidade pequena e configurável; §Configuração exige parâmetros centralizados (FR-026/FR-027) e §Veículo do Jogador apoia a mecânica de recursos limitados. Leitura registrada em Assumptions para conferência no `/speckit.analyze`.
- **Fora de escopo** registrado com base nas listas explícitas do texto-fonte (seções 3 e 19), incluindo vitória, Game Over, progressão, pontuação, reabastecimento e efeitos avançados — mais a ressalva de que a sinalização visual segue o escopo decidido no FR-025.
- Os termos "tanque", "consumo em repouso", "evento", "penalidade", "limiar" e os nomes de parâmetros (`fuel_*`, `collision_fuel_penalty`) vêm do texto-fonte e denotam **o quê** (conceitos de gameplay e ajuste), não **como**: nenhum idioma, framework, arquivo, classe ou API é citado no corpo dos requisitos; os nomes de parâmetros são declarados como "nomes de referência, adaptáveis à convenção do projeto", mesma convenção adotada pelas SPEC-005 e SPEC-006.
