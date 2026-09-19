# Análise de lacunas: `bluefin-cosmic-dx` vs. finpilot upstream

Comparação entre este repositório (`ericrocha97/bluefin`) e o template de origem
[`projectbluefin/finpilot`](https://github.com/projectbluefin/finpilot).

- **Este repositório**: criado a partir do template em `2026-01-20`; último commit `2026-09-03`.
- **finpilot upstream**: último commit observado em `2026-09-14` (projeto ativo).
- **Análise realizada em**: `2026-09-16`.

> Observação: este repositório divergiu de propósito (COSMIC-only, variante NVIDIA,
> publicação via Jenkins). Itens que conflitam com essa arquitetura estão marcados
> como **opcional/intencional**.

---

## 1. Identidade da imagem e build — ALTA prioridade

| Upstream finpilot | Este repositório | Impacto |
| --- | --- | --- |
| `build/00-image-info.sh` | **não existe** | Gera `/usr/share/ublue-os/image-info.json` e customiza `/usr/lib/os-release` (`VARIANT_ID`, `IMAGE_ID`, `IMAGE_REF` como `ostree-image-signed:docker://...`). Sem isso, `bootc`, `fastfetch` e o ecossistema ublue não reconhecem a imagem corretamente. |
| ARGs `IMAGE_NAME`, `IMAGE_VENDOR`, `UBLUE_IMAGE_TAG`, `BASE_IMAGE_NAME`, `FEDORA_MAJOR_VERSION`, `VERSION` no Containerfile | apenas `BASE_IMAGE` e `RELEASE_TAG` | Metadados de identidade ausentes na build. |
| `build/clean-stage.sh` (limpeza antes do lint) | **não existe** | Upstream reverte `keepcache`, limpa `versionlock`, mascara `flatpak-add-fedora-repos.service`, limpa `/var`, `/run/dnf`, `/tmp`, `/boot`. O lint pode passar sujo. |
| `RUN bootc container lint --fatal-warnings` | `bootc container lint` (sem flag) | Warnings passam silenciosamente. |
| Contextos OCI **pinados por digest** (`common`, `brew` direto em `FROM ...@sha256:`) | `COPY --from=...:latest` sem pin | Reproducibilidade: upstream deixa o Renovate fixar o SHA. |
| Base `quay.io/fedora-ostree-desktops/silverblue:44` | `ghcr.io/ublue-os/bluefin-dx:stable` | Direção intencional deste repositório; notar que o upstream já está em Fedora 44 e reduziu os contextos a `common` + `brew` (branding/artwork/base-main foram absorvidos pelo `common`). |

---

## 2. Segurança de CI — ALTA prioridade ⚠️

Achado mais relevante da análise:

- **`validate-brewfiles.yml` deste repositório executa código Ruby controlado pelo PR.**
  Ele roda `brew bundle exec whoami --file="$brewfile"`, ou seja, avalia o Brewfile como
  Ruby dentro do CI. O upstream **abandonou isso** e criou `build/validate-brewfiles.sh`,
  que só faz *grep* literal e passa os nomes como dados para `brew info` (nunca `bash -c`),
  rejeitando taps não-literais. Comentário do upstream: *"evaluating a PR-controlled
  [Brewfile] is code execution in CI (#288, #323)"*.
- **`.pre-commit-config.yaml` aponta para o caminho errado e também avalia Ruby**:
  `files: '^brew/.*\.Brewfile.*$'` — a pasta correta é `custom/brew/`, então o hook
  **nunca roda**. E usa `brew bundle check`, o mesmo padrão inseguro.
- **Não existe** `build/validate-flatpaks.sh` (upstream extraiu a validação para um script
  único com contrato: toda seção precisa de `Branch=` e o app-id precisa existir no flathub).
- **Não existe** `.github/actions/check-token-health/` (valida escopos do `RENOVATE_TOKEN`
  antes de rodar o bot) nem os testes correspondentes.
- Observação: hoje **não há nenhum `*.Brewfile` em `custom/brew/`** — só o README.
  Portanto a validação de Brewfile está efetivamente inativa.

---

## 3. Processo de release e workflows — MÉDIA/ALTA (parcialmente opcional)

O upstream adotou o **modelo de duas branches**:

- `main` publica `:stable-testing`; `stable` publica `:stable`.
- `promote-main-to-stable.yml` abre/atualiza o PR de promoção (squash) via
  `projectbluefin/actions/.../reusable-promote-squash.yml`.
- `sync-stable-to-main.yml` traz hotfixes de `stable` de volta para `main`.
- `approve-trusted-promotion-runs.yml` aprova automaticamente os checks dos PRs de bot.

Este repositório **não tem nada disso** — tem apenas `main` e publica via Jenkins.

Outros workflows ausentes:

- `unit-tests.yml` + `tests/unit/*.bats` (14 arquivos: `00-image-info`, `clean-stage`,
  `copr-helpers`, `validate-brewfiles`, `validate-flatpaks`, `justfile-*`,
  `precommit-brewfile-hook`, `shellcheck-scope`, entre outros).
- `pr-validation.yml` consolidado chamando `projectbluefin/actions/bootc-build/validate-pr`
  com ShellCheck **e hadolint** (`dockerfile` + `hadolint-config`).
- `label-enforcement.yml` (enforcement de template de issue/PR via reusable da org).
- `clean.yml` migrado para `projectbluefin/actions/bootc-build/ghcr-cleanup`
  (este repositório usa `dataaxiom/ghcr-cleanup-action` — funciona, mas está fora do padrão da org).
- `build-image.yml` completo com `projectbluefin/actions`, `generate-tags`, cache de DNF,
  **assinatura keyless OIDC + attestations**, opção de rechunk OCI.
- **Não usa `projectbluefin/actions` em lugar nenhum** (grep confirmou zero ocorrências).

---

## 4. Tooling local (Justfile) — MÉDIA

Upstream tem recipes/arquivos ausentes aqui:

- Recipes: `test-unit`, `validate-brewfiles`, `validate-flatpaks`, `tag-images`,
  `shell-sources`, além de `lint` lendo `.shellcheck-scope`.
- Arquivos de configuração: **`.shellcheck-scope`** (fonte única de quais `.sh` são padrão de
  lint, consumido por `just lint` e pelos testes) e **`.hadolint.yaml`**.
- `.dockerignore`.

Em contrapartida, o Justfile deste repositório é **mais rico** em VM/disk
(bib, QCOW2/RAW/VHDX, variante NVIDIA) — não regredir isso.

---

## 5. Documentação e skills de agente — MÉDIA

- `docs/skills/` + `.agents/skills/` com 14 skills `finpilot-*` (`finpilot-overview`,
  `-onboarding`, `-packages`, `-custom`, `-build`, `-ci`, `-maintain`, `-troubleshooting`,
  `-router`, `-pr-checklist`, etc.) e `finpilot-router` para roteamento.
  Aqui existe apenas `.github/copilot-instructions.md` + `AGENTS.md`.
- README com **"Guided Copilot Mode"** em 3 fases (Bootstrap / Customize / Production)
  e seção **"Promote to Stable"**.
- `AGENTS.md` do upstream documenta a estratégia de branches, o fluxo de release e
  *known gaps* (ex.: gate sem E2E, issue #281).

---

## 6. Itens que existem aqui e não no upstream

Para **não sincronizar às cegas**, estes elementos são deste repositório e devem ser mantidos:

- Pipelines Jenkins (`ci/jenkins/`).
- Variante NVIDIA dual-build.
- Scripts COSMIC (`30-cosmic-desktop.sh`, `40-remove-gnome.sh`).
- `15-system-optimizations.sh`.
- `custom/system-files/` (sysctl, udev, modprobe, tmpfiles).
- `iso/iso-nvidia.toml`.
- Geração de VHDX.
- README em PT-BR e as recipes de VM/disk do Justfile.

---

## Prioridades sugeridas

1. **`build/00-image-info.sh`** + ARGs no Containerfile → identidade correta da imagem.
2. **`build/clean-stage.sh`** + `bootc container lint --fatal-warnings`.
3. **Substituir `validate-brewfiles.yml` pelo `build/validate-brewfiles.sh`** e corrigir o
   caminho no `.pre-commit-config.yaml` (fecha o furo de RCE).
4. **Extrair `build/validate-flatpaks.sh`** e criar `.shellcheck-scope` + `.hadolint.yaml`.
5. `tests/unit` com BATS + `unit-tests.yml`.
6. (Opcional, decisão de arquitetura) adotar o modelo `main`→`stable` e/ou migrar a
   publicação para `projectbluefin/actions`.

Os itens **1–3** são independentes do modelo Jenkins/NVIDIA e não quebram a arquitetura
atual, sendo o melhor ponto de partida.
