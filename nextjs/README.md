# Next.js: build standalone e cache seguro

Este exemplo mostra a parte de infraestrutura de uma aplicação Next.js: build
multi-stage, saída `standalone`, execução sem root e configuração de cabeçalhos
que separam páginas públicas de dados privados. Ele é um recorte portável, não
uma aplicação completa que deve ser executada a partir desta pasta.

## Arquivos

| Arquivo | Demonstração |
| --- | --- |
| [`Dockerfile`](Dockerfile) | dependências, build e runtime mínimo em estágios separados |
| [`next.config.ts`](next.config.ts) | `output: "standalone"`, headers, cache e integrações opcionais |
| [`cache-boundary.ts`](cache-boundary.ts) | contrato explícito para rotas protegidas e `no-store` |
| [`.env.example`](.env.example) | separação entre configuração pública de build e valores server-only |
| [`callgraph.md`](callgraph.md) | fluxo do build e da requisição |
| [`docs/adr/`](docs/adr/) | fronteira do recorte, configuração, histórico e documentação |

Para usar o padrão em um app real, copie os arquivos para o diretório que
contém `package.json`, `src/` e o workspace compartilhado. O `Dockerfile`
assume um workspace pnpm com `packages-shared`; essa dependência é intencional
e deve ser removida se o app não tiver esse pacote.

## Porquês

1. **Build separado do runtime:** dependências de desenvolvimento ficam no
   estágio de build e o estágio final recebe somente o servidor standalone e
   os assets necessários.
2. **Runtime sem root:** o processo usa um usuário dedicado e `HOSTNAME` é
   explícito, reduzindo o impacto de uma falha no servidor HTTP.
3. **`output: "standalone"`:** o Next produz um conjunto rastreável para o
   contêiner, sem copiar o workspace inteiro para produção.
4. **Cache como política:** APIs e páginas autenticadas recebem
   `private, no-store`; arquivos estáticos versionados podem ser imutáveis.
5. **Integrações opt-in:** rewrites para analytics só existem quando uma
   origem válida está configurada. Uma configuração ausente desativa o adapter.

## Gotchas

- `NEXT_PUBLIC_*` é embutido no bundle durante o build. Nunca coloque segredo
  em uma variável com esse prefixo.
- `DATABASE_URL`, `API_URL` e `JWT_SECRET` devem ser lidos somente no servidor.
  O `.env.example` documenta nomes, não valores de um ambiente real.
- `outputFileTracingRoot` e os `COPY` do Dockerfile precisam apontar para a
  mesma raiz do workspace. Um move parcial quebra o build silenciosamente.
- O `next.config.ts` usa `@serwist/next` e `src/app/sw.ts` como seams do app
  preparado. Se o app não usa service worker, retire o wrapper em vez de
  deixar uma referência quebrada.
- Permitir SVG ou hosts de imagem remotos amplia a superfície de conteúdo. O
  exemplo aceita apenas `localhost`; adicione origens explícitas e revisadas.
- Argumentos de build podem aparecer em logs e metadados. Passe apenas valores
  públicos por `ARG`; segredos entram no runtime por um mecanismo de segredo.

## Segurança pública

Os valores neste diretório usam localhost, `example.com` ou placeholders. O
recorte não inclui banco, endpoint, conta, chave, imagem privada ou histórico
do app de origem.
