# infra-examples

Exemplos reais de infraestrutura, sanitizados e organizados **por ferramenta**, não por projeto.

A ideia é simples: quem chega aqui quer ver como uma coisa específica foi feita de verdade - não navegar pela história de um cliente. Então a pasta é a ferramenta, e dentro dela ficam os exemplos que a usam.

## Estrutura

| Pasta | O que demonstra |
| --- | --- |
| [`docker-swarm/`](docker-swarm/) | Stacks e manifestos de deploy em Swarm, com o que muda entre teste e produção |
| [`github-actions/`](github-actions/) | CI e CD: build, publicação de imagem, portões escalonados e release manual com portão |
| [`nextjs/`](nextjs/) | Build e empacotamento de app Next em contêiner, e o que costuma morder |
| [`drizzle/`](drizzle/) | Migrações e evolução de schema |
| [`playwright/`](playwright/) | E2E de verdade: o que vale testar, e por que suíte instável é pior que suíte ausente |
| [`bash-ops/`](bash-ops/) | Scripts operacionais - chaves de deploy, sandbox de E2E, bootstrap de runner |

## O que cada exemplo carrega

Não é código solto. Cada exemplo traz:

- **callgraph em Mermaid** - como as peças se chamam;
- **os porquês** - a decisão de arquitetura e a razão dela, não só o resultado;
- **os gotchas** - o que morde quem tentar repetir.

## Origem e limites

São exemplos **derivados** de infraestrutura real em operação, sanitizados: sem credencial, sem host interno, sem dado de cliente. O que está aqui foi escrito para ser lido por quem vai construir algo parecido, não para ser copiado e colado em produção sem entender.

As pastas se preenchem conforme cada exemplo é consolidado.
