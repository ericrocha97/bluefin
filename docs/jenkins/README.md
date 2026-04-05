# Guia Detalhado: Configurar Jenkins para este Repositório

Este guia mostra, do zero, como configurar o Jenkins para rodar o `Jenkinsfile` deste repositório e fazer:

1. build da imagem
2. push no GHCR
3. criação/atualização de release no GitHub
4. envio de evento para n8n
5. persistência no PostgreSQL + notificação por e-mail via n8n

## 1) Como o pipeline funciona

O pipeline definido em `Jenkinsfile` executa este fluxo:

- `Build Image`: build da imagem e geração de `manifest.txt` + metadados.
- `Push GHCR`: autentica no GHCR e publica as tags.
- `Create GitHub Release`: cria/atualiza release e anexa `manifest.txt`.
- `post { success/failure }`: envia payload para n8n usando `ci/jenkins/scripts/notify_n8n.sh`.

Notificação para n8n é **best effort**: se o webhook falhar, o pipeline registra warning, mas não invalida o build já concluído.

## 2) Pré-requisitos no servidor Jenkins

No host/agent onde o job vai rodar, você precisa de:

- `docker` CLI + daemon funcionando
- `gh` (GitHub CLI)
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
```

## 3) Plugins Jenkins recomendados

Mínimo para este fluxo:

- `Pipeline`
- `Git`
- `Credentials Binding`

Úteis (opcional):

- `Build Timeout`
- `Timestamper`
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

Observação: o `Jenkinsfile` deste repositório já usa Credentials Binding para autenticação no registro (`ghcr-creds`).

Observação: para release automation, o token GitHub precisa de permissão para releases no repositório.

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

## 7) Criar o Job Pipeline no Jenkins

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
   - `Script Path`: `Jenkinsfile`

Salvar.

## 8) Trigger (cron + manual)

O cron já está no `Jenkinsfile`:

```groovy
triggers {
  cron('H 10 * * *')
}
```

Isso agenda execução diária em horário distribuído.
Você também pode executar manualmente com `Build Now`.

## 9) Primeiro teste (smoke test)

1. Rodar `Build Now`.
2. Verificar no log do Jenkins:
   - build da imagem
   - login/push no GHCR
   - `gh release view/edit/create/upload`
   - warning/ok no notify para n8n
3. Verificar resultados externos:
   - GHCR recebeu tags (`stable`, `stable.YYYYMMDD`, `YYYYMMDD`)
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

### Erro no notify para n8n

- Mensagem comum: `WEBHOOK_URL is required` ou `N8N_WEBHOOK_SHARED_TOKEN is required`
- Confirme variáveis de ambiente no Jenkins.

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
