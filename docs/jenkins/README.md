# Guia Detalhado: Configurar Jenkins para este Repositório

Este guia mostra, do zero, como configurar o Jenkins para rodar os dois pipelines deste repositório (`ci/jenkins/Jenkinsfile.stable` e `ci/jenkins/Jenkinsfile.nvidia`) e fazer:

1. build da imagem
2. push no GHCR
3. assinatura dos digests publicados com Cosign
4. criação/atualização de release no GitHub
5. envio de evento para n8n
6. persistência no PostgreSQL + notificação por e-mail via n8n

## 1) Como o pipeline funciona

Os pipelines definidos em `ci/jenkins/Jenkinsfile.stable` e `ci/jenkins/Jenkinsfile.nvidia` executam este fluxo:

- `Build Image`: build da imagem e geração de `manifest.txt` + metadados.
- `Push GHCR`: autentica no GHCR, publica as tags datadas e registra o digest publicado.
- `Sign Image`: assina o digest publicado com Cosign e verifica a assinatura logo em seguida. Só roda quando `EFFECTIVE_BRANCH == DEFAULT_BRANCH` (`main`).
- `Promote Stable`: atualiza a tag `stable` somente depois que a assinatura do digest foi criada e verificada com sucesso.
- `Create GitHub Release`: cria/atualiza release e anexa `manifest.txt`.
- `post { always }`: arquiva `ci/jenkins/build/*` e envia o payload para n8n usando `ci/jenkins/scripts/notify_n8n.sh`. Como o hook é `always`, a notificação acontece mesmo quando o pipeline falha; o status enviado é derivado de `currentBuild.currentResult` (`success`/`failure`).

Contexto atual de CI/CD:

- O Jenkins é o pipeline oficial para build, publicação e assinatura.
- A assinatura usa chave tradicional Cosign e é feita por digest (`IMAGE_REPOSITORY@sha256:<digest>`), nunca apenas pela tag.
- O Cosign 3.x assina com `--new-bundle-format=false` (e `--use-signing-config=false`). Esse formato legado grava a assinatura como attachment OCI (`<digest>.sig`), que é o único que a policy `sigstoreSigned` do `containers/image` (`bootc`/`rpm-ostree`/`skopeo`) consome com `use-sigstore-attachments: true`. O formato padrão do Cosign 3.x (bundle/referrers) não é encontrado por essa policy e resulta em `A signature was required, but no signature exists`.
- Imediatamente após assinar, o Jenkins roda `cosign verify --new-bundle-format=false --key cosign.pub` no mesmo digest. Se a verificação falhar, o pipeline aborta antes de promover a tag `stable`.
- A chave pública `cosign.pub` é versionada e permite verificação independente com `cosign verify --new-bundle-format=false --key cosign.pub`.
- Attestations, SBOM, provenance e rechunking permanecem **fora do escopo**: não fazem parte do fluxo de assinatura.
- O GitHub Actions em `.github/workflows/build.yml` roda apenas como check de PR (`pull_request` para `main`) e não publica imagem/release nem assina releases.

Notificação para n8n é **best effort**: se o webhook falhar, o pipeline registra warning, mas não invalida o build já concluído.

## 2) Pré-requisitos no servidor Jenkins

No host/agent onde o job vai rodar, você precisa de:

- `docker` CLI + daemon funcionando
- `gh` (GitHub CLI)
- `cosign` (CLI) disponível no agente — usado pelo estágio `Sign Image`
- `oras` (CLI) disponível no agente — usado para publicar o metadata do Artifact Hub
- `bash`, `awk`, `coreutils`
- acesso de rede para:
  - `ghcr.io`
  - `api.github.com`
  - URL do n8n

Teste rápido no servidor:

```bash
docker --version
docker info
gh --version
gh auth status || true
cosign version
oras version
```

A versão do Cosign é gerenciada pelo agente Jenkins e não é fixada neste
repositório; registre a saída de `cosign version` no agente que executa os
pipelines. Não é necessário instalar Cosign no repositório.

O agente precisa do **Cosign 3.x**: `ci/jenkins/scripts/sign_image.sh` passa
`--new-bundle-format=false` e `--use-signing-config=false`, flags que existem a
partir do Cosign 3.x (são ocultas/deprecadas na CLI, mas funcionais em 3.1.x).
Sem elas, o Cosign 3.x usa por padrão o formato de bundle/referrers, que a
policy do `bootc` não reconhece.

## 3) Plugins Jenkins recomendados

Mínimo para este fluxo:

- `Pipeline`
- `Git`
- `Credentials Binding`
- `Timestamper`

Úteis (opcional):

- `Build Timeout`
- `Workspace Cleanup`
- `Folders`

## 4) Configurar credenciais no Jenkins

Abra: `Manage Jenkins` -> `Credentials` -> `(global)` -> `Add Credentials`

### 4.1 GHCR

- **Kind:** `Username with password`
- **ID:** `ghcr-creds`
- **Username:** usuário GitHub (ou machine user)
- **Password:** GitHub token com escopo para publicar pacotes (ex.: `write:packages`)

### 4.2 Segredos via Credentials Binding (recomendado)

Para evitar segredos globais em texto claro, use credenciais por job e injete via `withCredentials`:

- `github-token` (Secret text): token para `gh release ...`
- `n8n-webhook-url` (Secret text): URL de produção do webhook n8n
- `n8n-webhook-token` (Secret text): token compartilhado do header

No Pipeline job, use um bloco `withCredentials` para exportar:

- `GH_TOKEN`
- `WEBHOOK_URL`
- `N8N_WEBHOOK_SHARED_TOKEN`

Observação: os `Jenkinsfile.stable`/`Jenkinsfile.nvidia` deste repositório já usam Credentials Binding para autenticação no registro (`ghcr-creds`).
Observação: os `Jenkinsfile.stable`/`Jenkinsfile.nvidia` também usam `github-token`, `n8n-webhook-url` e `n8n-webhook-token` diretamente nos estágios/hook correspondentes.

Observação: para release automation, o token GitHub precisa de permissão para releases no repositório.

### 4.3 Cosign (assinatura dos digests)

A assinatura usa chave tradicional. Crie duas credenciais no mesmo escopo dos
dois jobs:

- **`cosign_key`** — **Kind:** `Secret file`; conteúdo: o arquivo privado
  `cosign.key` gerado com `cosign generate-key-pair`. O Jenkinsfile injeta o
  caminho em `COSIGN_KEY_FILE`.
- **`cosign_pass`** — **Kind:** `Secret text`; conteúdo: a senha que protege
  `cosign.key`. O Jenkinsfile injeta o valor em `COSIGN_PASSWORD`.

Regras:

- Não versione `cosign.key`. Apenas `cosign.pub` (chave pública) fica no
  repositório e é usada na verificação.
- Não substitua os IDs `cosign_key` e `cosign_pass` por valores inventados: são
  os IDs lidos por `ci/jenkins/Jenkinsfile.stable` e
  `ci/jenkins/Jenkinsfile.nvidia`.
- A assinatura é por digest. O estágio `Sign Image` só roda na `main` e chama
  `ci/jenkins/scripts/sign_image.sh` com `IMAGE_REPOSITORY@sha256:<digest>`.
- Attestations, SBOM, provenance e rechunking estão fora do escopo deste fluxo.

### 4.4 Artifact Hub

O pipeline standard publica `artifacthub-repo.yml` como um artefato OCI na tag
especial `ghcr.io/ericrocha97/bluefin-cosmic-dx:artifacthub.io` usando `oras`.
O login feito para o GHCR é reutilizado pelo `oras`; por isso o agente precisa
ter `oras` instalado e o token `ghcr-creds` precisa poder gravar no pacote.

O arquivo `artifacthub-repo.yml` contém o `repositoryID` e o owner usados pelo
Artifact Hub. Depois do primeiro push, faça o **Claim Ownership** no painel do
Artifact Hub com a conta GitHub correspondente. Configure somente a tag
mutável `stable` para este pacote. O status **Official** continua dependendo de
uma solicitação e aprovação manual do Artifact Hub.

## 5) Configurar n8n

### 5.1 Importar blueprint

- Arquivo: `n8n/blueprints/jenkins-build-events-workflow.json`

### 5.2 Configurar credenciais no n8n

- credencial PostgreSQL no node `Postgres Upsert`
- credencial SMTP no node `Send Email`

### 5.3 Configurar segurança do webhook

No ambiente do n8n, definir:

- `N8N_WEBHOOK_SHARED_TOKEN=<mesmo_token_configurado_no_jenkins>`

O workflow rejeita requests sem header `x-jenkins-webhook-token` válido.

### 5.4 Ativar workflow

- Ative o workflow no n8n e copie a URL de produção.
- endpoint esperado pelo blueprint: `/webhook/jenkins-build-events`

## 6) Configurar PostgreSQL

Executar schema:

```bash
psql "$POSTGRES_DSN" -f n8n/sql/001_ci_pipeline_runs.sql
```

Tabela principal criada: `ci_pipeline_runs`

- chave única: `(job_name, build_number)`
- armazenamento de payload em `jsonb`

## 7) Criar os Jobs Pipeline no Jenkins

Crie **dois** jobs Pipeline, um para cada variante.

### Job 1 — padrão (`bluefin-cosmic-dx`)

1. `New Item`
2. Nome: por exemplo `bluefin-main-build`
3. Tipo: `Pipeline`
4. Em `Pipeline`:
   - `Definition`: `Pipeline script from SCM`
   - `SCM`: `Git`
   - `Repository URL`: URL deste repositório
   - credencial Git (se necessário)
   - `Branches to build`:
     - enquanto estiver testando nesta branch: `*/feat/jenkins`
     - depois do merge para main: `*/main`
   - `Script Path`: `ci/jenkins/Jenkinsfile.stable`

Salvar.

- Cron: **semanal** — `H 2 * * 0` (domingo)
- Imagem publicada: `bluefin-cosmic-dx` (`ghcr.io/ericrocha97/bluefin-cosmic-dx`)
- Release: tag `v<data>` (ex.: `v20260101`)

### Job 2 — NVIDIA (`bluefin-cosmic-dx-nvidia`)

1. `New Item`
2. Nome: por exemplo `bluefin-main-build-nvidia`
3. Tipo: `Pipeline`
4. Em `Pipeline`:
   - `Definition`: `Pipeline script from SCM`
   - `SCM`: `Git`
   - `Repository URL`: URL deste repositório
   - credencial Git (se necessário)
   - `Branches to build`:
     - enquanto estiver testando nesta branch: `*/feat/jenkins`
     - depois do merge para main: `*/main`
   - `Script Path`: `ci/jenkins/Jenkinsfile.nvidia`

Salvar.

- Cron: **diário** — `H 10 * * *`
- Imagem publicada: `bluefin-cosmic-dx-nvidia` (`ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia`)
- Release: tag `v<data>-nvidia` (ex.: `v20260101-nvidia`)

## 8) Trigger (cron + manual)

O cron já está nos `Jenkinsfile`:

```groovy
triggers {
  cron('H 2 * * 0')    // Jenkinsfile.stable (semanal, domingo)
  cron('H 10 * * *')   // Jenkinsfile.nvidia (diário)
}
```

Isso agenda execução semanal (padrão) e diária (NVIDIA) em horário distribuído.
Você também pode executar manualmente com `Build Now`.

## 9) Primeiro teste (smoke test)

1. Rodar `Build Now`.
2. Verificar no log do Jenkins:
   - build da imagem
   - login/push no GHCR
   - estágio `Sign Image` concluído (chave e senha presentes, digest válido)
   - `gh release view/edit/create/upload`
   - warning/ok no notify para n8n
3. Verificar resultados externos:
    - GHCR recebeu tags (`stable`, `stable.YYYYMMDD`, `YYYYMMDD`) e o artefato
      `:artifacthub.io` foi publicado pelo pipeline standard
   - digest publicado assinado:
     `cosign verify --key cosign.pub ghcr.io/ericrocha97/bluefin-cosmic-dx@sha256:<digest>`
   - release no GitHub foi criada/atualizada
   - n8n recebeu execução
   - PostgreSQL recebeu upsert
   - e-mail foi enviado

## 10) Troubleshooting rápido

### Erro no push GHCR

- Mensagem comum: `unauthorized`
- Verifique credencial `ghcr-creds` e permissões do token para `ghcr.io`.

### Erro nos comandos `gh`

- Mensagem comum: auth/repo scope
- Verifique `GH_TOKEN`/`GITHUB_TOKEN` e escopos de release.

### Erro no estágio `Sign Image`

- Sintomas comuns: `COSIGN_KEY_FILE is required`, `COSIGN_PASSWORD is required`,
  `image reference must be pinned by digest` ou `unable to determine the
  published image digest`.
- Confirme as credenciais `cosign_key` (`Secret file`) e `cosign_pass`
  (`Secret text`) no escopo dos jobs.
- Confirme que o push no GHCR terminou na `main` e que o digest foi capturado em
  `ci/jenkins/build/image_digest`.
- O estágio é ignorado fora da `main`; isso é esperado.
- Se `cosign verify` falhar depois do build, confirme que o `cosign.pub`
  versionado corresponde à chave privada carregada em `cosign_key`.

### `bootc switch --enforce-container-sigpolicy` retorna `A signature was required, but no signature exists`

- Causa: a assinatura foi gravada no formato de bundle/referrers padrão do
  Cosign 3.x (`ghcr.io/...:<repo>` com a tag `sha256-<64hex>` sem sufixo), que a
  policy `sigstoreSigned` + `use-sigstore-attachments: true` do
  `containers/image` **não** lê. A policy procura o attachment legado
  `sha256-<64hex>.sig`.
- Verifique as tags de assinatura publicadas:

  ```bash
  skopeo list-tags docker://ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia \
    | grep '<64hex-do-digest>'
  ```

  O correto é existir `sha256-<64hex>.sig`; se existir apenas
  `sha256-<64hex>` (sem `.sig`), o build foi assinado no formato antigo.
- Correção: garanta que `ci/jenkins/scripts/sign_image.sh` assine com
  `--new-bundle-format=false --use-signing-config=false` e rode um novo build
  Jenkins na `main`. A `policy.json` e o `use-sigstore-attachments: true` **não**
  devem ser alterados.
- Verificação manual do digest novo:

  ```bash
  cosign verify --new-bundle-format=false --key cosign.pub \
    ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia@sha256:<novo_digest>
  ```

### Erro no notify para n8n

- Mensagem comum: `WEBHOOK_URL is required` ou `N8N_WEBHOOK_SHARED_TOKEN is required`
- Confirme variáveis de ambiente no Jenkins.
- Se a URL usar `localhost`/`127.0.0.1`, ela resolve dentro do runtime do Jenkins. Em ambientes com n8n separado, use hostname/IP acessível pelo container/agent Jenkins.

### n8n rejeita webhook

- Mensagem comum de token inválido
- Verifique se `N8N_WEBHOOK_SHARED_TOKEN` é idêntico em Jenkins e n8n.

### PostgreSQL não grava

- Verifique credencial do node `Postgres Upsert`.
- Garanta que o schema foi aplicado (`n8n/sql/001_ci_pipeline_runs.sql`).

## 11) Configuração recomendada de resiliência

`ci/jenkins/scripts/notify_n8n.sh` já suporta tuning via env vars:

- `N8N_NOTIFY_CONNECT_TIMEOUT_SECONDS` (default `5`)
- `N8N_NOTIFY_MAX_TIME_SECONDS` (default `30`)
- `N8N_NOTIFY_RETRY_COUNT` (default `3`)
- `N8N_NOTIFY_RETRY_DELAY_SECONDS` (default `2`)

Exemplo (variáveis não sensíveis no job/agent):

- `N8N_NOTIFY_CONNECT_TIMEOUT_SECONDS=5`
- `N8N_NOTIFY_MAX_TIME_SECONDS=20`
- `N8N_NOTIFY_RETRY_COUNT=2`
- `N8N_NOTIFY_RETRY_DELAY_SECONDS=2`

## 12) Comandos de validação local (opcional)

```bash
bash ci/jenkins/tests/run-all.sh
shellcheck ci/jenkins/scripts/*.sh ci/jenkins/tests/*.sh
just --list
```

Verificação de assinatura de um digest publicado (requer `cosign` 3.x e o
`cosign.pub` versionado; uma tag como `:stable` também funciona, pois resolve
para o digest assinado). Use `--new-bundle-format=false` para ler a assinatura
no formato legado usado pela policy do `bootc`:

```bash
cosign verify --new-bundle-format=false --key cosign.pub \
  ghcr.io/ericrocha97/bluefin-cosmic-dx@sha256:<digest>
cosign verify --new-bundle-format=false --key cosign.pub \
  ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia@sha256:<digest>
```
