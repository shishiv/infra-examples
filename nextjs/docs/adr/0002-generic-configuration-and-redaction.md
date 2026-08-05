# ADR-0002: configuração genérica e redaction

- Status: Accepted
- Date: 2026-08-05

## Contexto

Um exemplo de frontend pode parecer pronto para produção quando conserva URL,
identidade visual, provider ou credencial do app de origem.

## Decisão

Usar localhost e domínios reservados nos defaults. Valores que variam ficam no
`.env.example`; `NEXT_PUBLIC_*` é tratado como público e valores server-only
ficam fora do bundle. Rewrites de analytics e providers são opt-in e só são
criados quando a origem passa pela validação de URL.

## Consequências

- O recorte é útil para revisão sem acesso a serviço externo.
- Configurar um deploy real continua exigindo revisão de origem permitida,
  segredo, legal copy e dados.
- Um placeholder não transforma uma configuração em credencial segura.
