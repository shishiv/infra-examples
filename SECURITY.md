# Revisão da superfície pública

Este repositório é público. O conteúdo foi tratado como material de publicação,
não como um diretório de trabalho.

## Regras

- Não adicionar `.git`, histórico, dumps, arquivos `.env`, tokens, chaves,
  credenciais, cookies, hosts internos, IPs operacionais ou dados de cliente.
- Usar somente `localhost`, `127.0.0.1`, `192.0.2.0/24`, `example.com`,
  `example.test` e `example.invalid` quando um valor de documentação for
  necessário.
- Nomes e caminhos do app de origem não são evidência de que um valor pode ser
  público. Se um arquivo não puder ser explicado sem contexto privado, ele fica
  fora do portfólio.
- Scripts que geram ou recebem segredo podem aparecer como padrão operacional,
  mas não podem conter uma chave, token ou valor de ambiente real.

## Varredura antes da entrega

A revisão local usa busca literal e por padrão de alto risco, além da inspeção
de cada arquivo adicionado:

```bash
git ls-files -co --exclude-standard
git grep -nE 'BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|gh[pors]_[A-Za-z0-9]+|AKIA[0-9A-Z]{16}|xox[baprs]-|sk-[A-Za-z0-9]' -- .
rg -n --hidden --glob '!.git/**' --glob '!*.png' --glob '!*.jpg' \
  'triangulotec|gastei|tecsites|tijolar|contabo|hostinger|shishiv|internal|\.local|\.lan|\.corp' .
```

Os comandos acima são filtros de revisão, não uma garantia matemática. Depois
deles, cada arquivo novo é lido no diff e os valores de host, e-mail, IP,
registry, usuário e caminho são classificados como placeholder ou removidos.

## Resultado desta consolidação

A varredura própria da mudança revisou 86 arquivos. O resultado foi `0`
findings bloqueantes; os únicos IPs observados foram loopback, `0.0.0.0` e a
faixa reservada `192.0.2.0/24`, e os hosts literais foram localhost, domínios
`example.*`, GitHub ou GHCR públicos. Os dois `.env.example` foram revisados
como templates, e nenhum `.env` real foi adicionado.

- Não foi copiado histórico nem `.git` dos materiais privados.
- Configurações públicas usam placeholders e ambientes locais.
- Fixtures de teste usam valores sintéticos e não representam contas, contatos
  ou endpoints ativos.
- `docker-swarm/staging/tests/` exercita redaction, mas os valores de fixture
  são explicitamente técnicos e não credenciais.

Se uma futura mudança produzir qualquer resultado ambíguo, o arquivo deve ser
removido da mudança e a decisão deve ser registrada antes de continuar.
