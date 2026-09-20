# bluefin-cosmic-dx

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/bluefin-cosmic-dx)](https://artifacthub.io/packages/search?repo=bluefin-cosmic-dx)
[![GHCR Padrão](https://img.shields.io/badge/GHCR-bluefin--cosmic--dx-2ea44f?logo=github)](https://github.com/ericrocha97/bluefin/pkgs/container/bluefin-cosmic-dx)
[![GHCR NVIDIA](https://img.shields.io/badge/GHCR-bluefin--cosmic--dx--nvidia-76b900?logo=nvidia)](https://github.com/ericrocha97/bluefin/pkgs/container/bluefin-cosmic-dx-nvidia)

Este projeto foi criado usando o template finpilot: <https://github.com/projectbluefin/finpilot>.

Versão em inglês: [README.md](README.md)

Ele constrói uma imagem bootc customizada COSMIC-only baseada no Bluefin DX, usando o padrão multi-stage OCI do ecossistema Bluefin.

## Build e Publicação

- O build e a publicação oficiais da imagem rodam via pipelines Jenkins self-hosted (`ci/jenkins/Jenkinsfile.stable` para a imagem padrão e `ci/jenkins/Jenkinsfile.nvidia` para a variante NVIDIA).
- Registros oficiais da imagem: `ghcr.io/ericrocha97/bluefin-cosmic-dx` (padrão) e `ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia` (NVIDIA).
- O GitHub Actions (`.github/workflows/build.yml`) agora roda apenas como check de PR (`pull_request` para `main`) e não publica imagem.

## Modo Copilot Guiado

Este repositório foi feito para ser trabalhado com um agente de código (GitHub Copilot, OpenCode ou similar) usando o fluxo padrão de fork:

- Nunca faça commit diretamente na `main`; crie uma feature branch e abra um pull request contra a `main`.
- Use Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, ...) em todo commit e no título do PR.
- Rode os checks leves localmente antes de enviar: `just check`, `just lint`, `bats tests/unit/`, `bash ci/jenkins/tests/run-all.sh` e `git diff --check`. Um build completo da imagem não é obrigatório localmente.
- O GitHub Actions valida o pull request (build da imagem como check de PR, testes unitários, shellcheck, checagens de Brewfile/Flatpak/just/Renovate/Jenkins). Ele nunca publica nem assina imagens.
- As imagens de produção são construídas e publicadas pelo Jenkins somente a partir da `main` — veja [Promover para Stable](#promover-para-stable).
- As imagens de produção são assinadas pelo Jenkins com Cosign (chave tradicional). Não afirme que o GitHub Actions assina ou publica algo: ele roda apenas em PRs. Veja [Assinatura e verificação de imagem](#assinatura-e-verificação-de-imagem).

## Promover para Stable

A `main` é a branch de produção. Promova mudanças fazendo merge de um pull request na `main`; nunca faça push direto na `main`.

- **Imagem padrão** — `ci/jenkins/Jenkinsfile.stable` constrói e publica `ghcr.io/ericrocha97/bluefin-cosmic-dx` (agendado semanalmente, `H 2 * * 0`).
- **Imagem NVIDIA** — `ci/jenkins/Jenkinsfile.nvidia` constrói e publica `ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia` (agendado diariamente, `H 10 * * *`).
- Cada execução constrói com Docker, envia as tags GHCR `stable`, `stable.YYYYMMDD` e `YYYYMMDD`, depois cria o release no GitHub (`v<date>` para a imagem padrão, `v<date>-nvidia` para a NVIDIA) e notifica o n8n.
- Os estágios de push no GHCR e de release são condicionados à branch efetiva ser a `main`, então são ignorados em qualquer outro lugar.
- O GitHub Actions nunca publica imagens aqui; ele apenas faz validação de PR/leve e manutenção agendada (atualizações do Renovate e limpeza de imagens). O Jenkins assina os digests publicados com Cosign.

## O que torna este Raptor diferente?

Aqui estão as mudanças em relação ao Bluefin DX. Esta imagem é baseada no Bluefin e inclui estas personalizações:

### Pacotes adicionados (build-time)

- **Pacotes do sistema**: Ambiente desktop COSMIC completo incluindo:
  - Stack do desktop principal: session, compositor, panel, launcher, applets, greeter
  - Aplicações nativas: Settings, Files (gerenciador de arquivos), Edit (editor de texto), Terminal, Store (loja de apps), Player (reprodutor de mídia), Screenshot (ferramenta de captura de tela)
  - Componentes do sistema: wallpapers, ícones, notificações, OSD, biblioteca de apps, gerenciador de workspaces
  - Integração com desktop portal (xdg-desktop-portal-cosmic)
- **Ferramentas CLI**: copr-cli (gerenciamento e monitoramento de repositórios COPR)
- **Ferramentas do Sistema**: earlyoom (prevenção de OOM), ffmpegthumbnailer (thumbnails de vídeo)
- **Codecs**: Codecs multimídia completos via negativo17/fedora-multimedia (imagem base), com `libvdpau-va-gl` opcional quando disponível nos repositórios Fedora
- **Apps de terceiros**: VSCode Insiders, Warp Terminal, Vicinae, OpenLogi

### Aplicações adicionadas (runtime)

- **Ferramentas CLI (Homebrew)**: `rtk` (proxy de CLI que minimiza o consumo de tokens de LLM) e `topgrade` (atualiza tudo — pacotes do sistema, Homebrew e mais com um único comando). Instale em runtime com `ujust install-default-apps`.
- **Apps GUI (Flatpak)**: Zen Browser.

### Removidos/Desativados

- **Sessão GNOME**: Removida para que COSMIC seja a única sessão de login.
- **GDM**: Desativado/removido em favor do COSMIC Greeter.
- **Tuning específico do mutter/GNOME**: Removido porque GNOME não é mais enviado como sessão desktop.

### Otimizações do Sistema (CachyOS/LinuxToys)

- **sysctl**: Tweaks CachyOS para VM/rede/kernel (swappiness, vfs_cache_pressure, dirty bytes, etc.)
- **udev rules**: IO schedulers (BFQ/mq-deadline/none), áudio PM, SATA, HPET, CPU DMA latency
- **modprobe**: NVIDIA PAT + power management dinâmico, opções AMD GPU, blacklist de módulos
- **tmpfiles**: Transparent Huge Pages (defer+madvise, shrinker a 80%)
- **journald**: Tamanho do journal limitado a 50MB
- **earlyoom**: Threshold de 5% memória/swap, notificações D-Bus
- **Auto-updates**: rpm-ostreed AutomaticUpdatePolicy=stage
- **Fastfetch**: Config customizado exibindo nome/versão da imagem, versão do COSMIC e data do build (sobrescreve config padrão do Bluefin)

### Mudanças de configuração

- COSMIC Greeter é habilitado como gerenciador de login padrão.
- COSMIC é a única sessão de desktop apresentada no login.
- Comandos customizados do ujust disponíveis: install-nvm, install-sdkman, install-dev-managers, install-default-apps.

*Última atualização: 2026-09-20*

## O que é esta imagem

bluefin-cosmic-dx é uma imagem Bluefin DX focada em desenvolvimento que mantém a base Bluefin DX e entrega COSMIC como o único ambiente desktop.

## Instalação

Primeira instalação? Siga o guia passo a passo: **[Guia de Instalação](docs/instalacao.md)**

Já está rodando Bluefin? Faça o rebase direto:

```bash
# Padrão (GPUs Intel/AMD, VMs)
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx:stable

# NVIDIA (GPUs RTX)
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia:stable
```

## O que muda nesta versão

Baseado no **Bluefin DX**, esta imagem adiciona e altera:

- **Desktop COSMIC** (System76) como única sessão de desktop
- **COSMIC Greeter** como gerenciador de login
- **Sessão GNOME removida** da imagem final
- **VSCode Insiders** instalado via RPM
- **Warp Terminal** instalado via RPM
- **Vicinae** instalado via repo Terra (compatível com Bazzite)
- Recursos de desenvolvimento do Bluefin DX que continuam compatíveis com o alvo COSMIC-only

Imagem base: `ghcr.io/ublue-os/bluefin-dx:stable`

## Variantes

Esta imagem está disponível em duas variantes:

| Variante | Imagem Base                           | Pacote GHCR                                    | Para                |
| -------- | ------------------------------------- | ---------------------------------------------- | ------------------- |
| Padrão   | `bluefin-dx:stable`                   | `ghcr.io/ericrocha97/bluefin-cosmic-dx`        | GPUs Intel/AMD, VMs |
| NVIDIA   | `bluefin-dx-nvidia-open:stable-daily` | `ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia` | GPUs NVIDIA RTX     |

Ambas as variantes incluem o mesmo desktop COSMIC, otimizações de sistema e ferramentas de desenvolvimento. A variante NVIDIA adiciona os módulos de kernel NVIDIA open-source embutidos na imagem (sem necessidade de akmods/DKMS).

## Uso básico

### Comandos Just

Este projeto usa [Just](https://just.systems/) como executor de comandos. Aqui estão os principais comandos disponíveis:

**Build:**

```bash
just build              # Constrói a imagem do container
just build-nvidia        # Constrói a variante NVIDIA da imagem container
just build-vm           # Constrói imagem de VM (QCOW2) - alias para build-qcow2
just build-qcow2        # Constrói imagem de VM QCOW2
just build-iso          # Constrói imagem ISO instalador
just build-raw          # Constrói imagem de disco RAW
```

**Executar:**

```bash
just run-vm             # Executa a VM - alias para run-vm-qcow2
just run-vm-qcow2       # Executa VM a partir da imagem QCOW2
just run-vm-iso         # Executa VM a partir da imagem ISO
just run-vm-raw         # Executa VM a partir da imagem RAW
```

**Utilitários:**

```bash
just clean              # Limpa todos os arquivos temporários e artefatos de build
just lint               # Executa shellcheck em todos os scripts bash
just format             # Formata todos os scripts bash com shfmt
just --list             # Mostra todos os comandos disponíveis
```

**Comandos ujust customizados (na imagem):**

Esta imagem inclui comandos `ujust` para gerenciadores de desenvolvimento e ferramentas CLI de runtime:

```bash
ujust install-nvm
ujust install-sdkman
ujust install-dev-managers
ujust install-default-apps   # instala rtk e topgrade a partir do default.Brewfile
```

O `custom/brew/default.Brewfile` inclui `rtk` e `topgrade`. Se você adicionar mais arquivos `.Brewfile` (correspondentes ao padrão `*.Brewfile`) em qualquer lugar dentro de `custom/brew/`, eles serão copiados durante o build automaticamente.

**Fluxo completo:**

```bash
# Construir tudo e executar a VM
just build && just build-vm && just run-vm

# Ou passo a passo:
just build              # 1. Constrói imagem do container
just build-qcow2        # 2. Constrói imagem de VM
just run-vm-qcow2       # 3. Executa a VM
```

### Implantando no Seu Sistema

Trocar seu sistema para esta imagem:

```bash
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx:stable
sudo systemctl reboot
```

Para GPUs NVIDIA:

```bash
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia:stable
sudo systemctl reboot
```

Voltar para o Bluefin DX:

```bash
sudo bootc switch ghcr.io/ublue-os/bluefin-dx:stable
sudo systemctl reboot
```

## Assinatura e verificação de imagem

As imagens de produção são assinadas pelos pipelines do Jenkins com **Cosign**,
usando um par de chaves tradicional. O GitHub Actions roda apenas em pull
requests e nunca publica nem assina um release.

- **Credenciais do Jenkins**: os pipelines leem a chave privada da credencial
  `cosign_key` (`Secret file`) e a senha da chave da credencial `cosign_pass`
  (`Secret text`). Configure as duas em `Manage Jenkins → Credentials`, no
  escopo usado pelos dois jobs.
- **Assinatura por digest**: depois do `Push GHCR`, cada pipeline registra o
  digest publicado e assina `IMAGE_REPOSITORY@sha256:<digest>` em um estágio
  `Sign Image` condicionado à branch `main`. Tags sozinhas nunca são assinadas.
  O helper é `ci/jenkins/scripts/sign_image.sh`; o mesmo fluxo cobre as
  variantes padrão (`bluefin-cosmic-dx`) e NVIDIA (`bluefin-cosmic-dx-nvidia`).
- **Chave pública**: `cosign.pub` é versionado neste repositório. A chave privada
  `cosign.key` nunca é commitada (está listada no `.gitignore`).
- **Verificação**: verifique um digest publicado contra a chave pública
  versionada (uma tag como `:stable` também funciona, pois resolve para o digest
  assinado):

  ```bash
  cosign verify --key cosign.pub \
    ghcr.io/ericrocha97/bluefin-cosmic-dx@sha256:<digest>
  cosign verify --key cosign.pub \
    ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia@sha256:<digest>
  ```

### Ativando a verificação de assinatura do bootc

A imagem inclui uma política estrita de assinatura de containers e a chave
pública correspondente. A política rejeita imagens não assinadas por padrão e
aceita apenas imagens assinadas dos repositórios GHCR padrão e NVIDIA deste
projeto. Ela não é ativada automaticamente, pois a política usada no primeiro
switch vem do sistema que está rodando naquele momento.

Em uma instalação nova, faça o primeiro switch normalmente, reinicie no novo
sistema e ative a verificação uma vez:

```bash
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx:stable
sudo systemctl reboot
sudo bootc switch --enforce-container-sigpolicy \
  ghcr.io/ericrocha97/bluefin-cosmic-dx:stable
```

Use `bluefin-cosmic-dx-nvidia:stable` em sistemas NVIDIA. Instalações
existentes podem usar o mesmo bootstrap em duas etapas: execute `bootc
upgrade`, reinicie e depois repita o `bootc switch` com
`--enforce-container-sigpolicy`. A partir daí, os próximos `bootc upgrade`
usarão a política estrita. Também é possível verificar a primeira transição
instalando manualmente os arquivos da política no sistema atual antes do
switch.

A política bloqueia intencionalmente pulls de containers não assinados em outros
registros via `podman`. Esse é o trade-off esperado do enforcement estrito;
adicione registros confiáveis localmente se seu fluxo precisar deles.

- **Fora do escopo**: attestations, SBOM, provenance e rechunking **não** fazem
  parte deste fluxo. Não os confunda com a assinatura Cosign.

## Login COSMIC

A imagem inicia no COSMIC Greeter e abre a sessão Wayland do COSMIC. GNOME intencionalmente não é oferecido como opção de login.

## Solução de problemas

### Sessão COSMIC não aparece

1. Verifique pacotes: `rpm -qa | grep -i cosmic`
2. Verifique o arquivo de sessão: `ls /usr/share/wayland-sessions/cosmic.desktop`
3. Verifique o COSMIC Greeter: `systemctl status cosmic-greeter`

### VSCode ou Warp não abre

- Verifique RPM: `rpm -q code-insiders warp-terminal`
- Confirme que /opt está gravável dentro da imagem (necessário para RPM)

### Build local falha

- Verifique espaço: `df -h`
- Limpe e tente de novo: `just clean && just build`
- Veja logs: `journalctl -xe`

### VM não inicia

- Verifique KVM: `ls -l /dev/kvm`
- Recrie a imagem: `just build-qcow2`

## Screenshots

<details>
<summary>Ver screenshots</summary>

### COSMIC Greeter

![COSMIC Greeter](https://raw.githubusercontent.com/ericrocha97/bluefin/main/docs/images/cosmic-greeter.png)

### Desktop COSMIC

![Desktop COSMIC](https://raw.githubusercontent.com/ericrocha97/bluefin/main/docs/images/cosmic-desktop.png)

</details>
