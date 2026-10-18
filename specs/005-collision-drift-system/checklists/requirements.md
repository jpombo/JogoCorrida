# Specification Quality Checklist: Sistema de Colisão e Drift

**Purpose**: Validar completude e qualidade da especificação antes de prosseguir para planejamento
**Created**: 2026-10-04
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

- Todos os 16 itens passam na 1ª validação; 0 marcadores `[NEEDS CLARIFICATION]`. As decisões não especificadas pelo texto-fonte foram resolvidas por premissas documentadas na seção **Assumptions** (direção na margem neutra, sobreposição além do cooldown, padrões de ajuste, hitboxes iniciais), sem bloquear o planejamento.
- Estrutura: 8 histórias de usuário priorizadas (P1: US1–US4 e US8; P2: US5–US7), 36 requisitos funcionais (FR-001 a FR-036), 13 critérios de sucesso (SC-001 a SC-013), 5 entidades-chave e 11 casos de borda.
- **Dependência da constituição resolvida**: a emenda v2.0.0 (§Trânsito) atribuiu a detecção e a resolução de colisão a este spec e reescreveu o MUST do trânsito para "fornecer identificação, posição e área ocupada" — contrato já implementado pelo SPEC-004 (`TrafficVehicle.get_occupied_area()`), que esta spec consome (ver Assumptions). Os itens anteriormente marcados "Not implementable pre-v2.0.0" deixam de ser bloqueio.
- **Fora de escopo** registrado com base na lista explícita do texto-fonte, incluindo a proibição de redução de velocidade do NPC em qualquer tipo de colisão (não apenas na 1-3) e a inexistência de colisão NPC×NPC e com decoração.
- Os termos "hitbox", "evento", "drift" e os nomes de parâmetros de ajuste vêm do texto-fonte e denotam **o quê** (conceitos de gameplay), não **como** (nenhuma tecnologia, framework ou estrutura de código é citada).
- **Revalidação pós-ajuste 4 (2026-10-05)**: os 16 itens seguem passando após a adição de FR-036/SC-013 (janela de aceleração pós-colisão), do novo caso de borda "Colisão com o jogador acelerando" e da sessão de clarificações "ajustes pós-implementação" — requisitos testáveis, SC mensurável (100%), parâmetro na lista de FR-035, sem marcadores de ambiguidade e sem vazamento de detalhes de implementação. Os ajustes 1–3 e 5 são de domínio do trânsito e constam da spec/checklist da SPEC-004.
- **Revalidação pós-ajuste 6 (2026-10-05)**: os 16 itens seguem passando após o reforço de FR-019/FR-021 (duração do retorno configurável, retorno literal à faixa de origem), a adição de SC-014 (retorno mensurável com tolerância de 0,1 px), a emenda do caso de borda "NPC deslocado colado à borda da pista durante a ultrapassagem" (ida travada ainda retorna à origem) e a nova sessão de clarificações — SC mensurável (100%), parâmetro na lista de FR-035, sem ambiguidade e sem vazamento de implementação.
