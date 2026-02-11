# bluefin-cosmic-dx

[![Build](https://github.com/ericrocha97/bluefin/actions/workflows/build.yml/badge.svg)](https://github.com/ericrocha97/bluefin/actions/workflows/build.yml)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/bluefin-cosmic-dx)](https://artifacthub.io/packages/search?repo=bluefin-cosmic-dx)

Este projeto foi criado usando o template finpilot: <https://github.com/projectbluefin/finpilot>.

Versão em inglês: [README.md](README.md)

Ele constrói uma imagem bootc customizada baseada no Bluefin DX, usando o padrão multi-stage OCI do ecossistema Bluefin.

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
- **Codecs**: Codecs multimídia completos via negativo17/fedora-multimedia (imagem base), libvdpau-va-gl

### Aplicações adicionadas (runtime)

- **Ferramentas CLI (Homebrew)**: Nenhuma (ainda sem Brewfiles).
- **Apps GUI (Flatpak)**: Zen Browser.

### Removidos/Desativados

- Nenhum.

### Otimizações do Sistema (CachyOS/LinuxToys)

- **sysctl**: Tweaks CachyOS para VM/rede/kernel (swappiness, vfs_cache_pressure, dirty bytes, etc.)
- **udev rules**: IO schedulers (BFQ/mq-deadline/none), áudio PM, SATA, HPET, CPU DMA latency
- **modprobe**: NVIDIA PAT + power management dinâmico, opções AMD GPU, blacklist de módulos
- **tmpfiles**: Transparent Huge Pages (defer+madvise, shrinker a 80%)
- **journald**: Tamanho do journal limitado a 50MB
- **earlyoom**: Threshold de 5% memória/swap, notificações D-Bus
- **Auto-updates**: rpm-ostreed AutomaticUpdatePolicy=stage
- **GNOME**: mutter check-alive-timeout configurado para 20s

### Mudanças de configuração

- Sessões de desktop duplas disponíveis no GDM (GNOME e COSMIC).
- Comandos customizados do ujust disponíveis: install-nvm, install-sdkman, install-dev-managers.

*Última atualização: 2026-02-11*

## O que é esta imagem

bluefin-cosmic-dx é uma imagem Bluefin focada em desenvolvimento, com **suporte a GNOME + COSMIC dual desktop**. Você pode escolher qual ambiente usar na tela de login.

## O que muda nesta versão

Baseado no **Bluefin DX**, esta imagem adiciona:

- **Desktop COSMIC** (System76) como alternativa ao GNOME
- **VSCode Insiders** instalado via RPM
- **Warp Terminal** instalado via RPM
- **Suporte dual desktop**: Escolha GNOME ou COSMIC no login (GDM)
- Todos os recursos do Bluefin DX (containers, DevPods, ferramentas CLI, etc.)

Imagem base: `ghcr.io/ublue-os/bluefin-dx:stable-daily`

## Uso básico

### Comandos Just

Este projeto usa [Just](https://just.systems/) como executor de comandos. Aqui estão os principais comandos disponíveis:

**Build:**

```bash
just build              # Constrói a imagem do container
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

Esta imagem inclui comandos `ujust` para gerenciadores de desenvolvimento:

```bash
ujust install-nvm
ujust install-sdkman
ujust install-dev-managers
```

Não existem Brewfiles por padrão. Se você adicionar arquivos `.Brewfile` (correspondentes ao padrão `*.Brewfile`) em qualquer lugar dentro de `custom/brew/`, eles serão copiados durante o build automaticamente.

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

## Assinatura de imagem (opcional)

A assinatura de imagem vem desativada por padrão para que os primeiros builds funcionem imediatamente. Ative depois para uso em produção (veja a seção de assinatura neste repositório).

Voltar para o Bluefin DX:

```bash
sudo bootc switch ghcr.io/ublue-os/bluefin-dx:stable
sudo systemctl reboot
```

## Escolhendo o Desktop no Login

Na tela de login (GDM), clique no **ícone de engrenagem ⚙️** para selecionar:

- **GNOME** - Desktop padrão do Bluefin
- **COSMIC** - Novo ambiente desktop da System76

## Solução de problemas

### Sessão COSMIC não aparece no GDM

1. Verifique pacotes: `rpm -qa | grep -i cosmic`
2. Verifique o arquivo de sessão: `ls /usr/share/wayland-sessions/cosmic.desktop`
3. Reinicie o GDM: `sudo systemctl restart gdm`

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

### Seletor de sessão no GDM

![Seletor de sessão no GDM](https://raw.githubusercontent.com/ericrocha97/bluefin/main/docs/images/gdm-selector.png)

### Desktop COSMIC

![Desktop COSMIC](https://raw.githubusercontent.com/ericrocha97/bluefin/main/docs/images/cosmic-desktop.png)

### Desktop GNOME

![Desktop GNOME](https://raw.githubusercontent.com/ericrocha97/bluefin/main/docs/images/gnome-desktop.png)

</details>
