# bluefin-cosmic-dx

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

### Aplicações adicionadas (runtime)

- **Ferramentas CLI (Homebrew)**: Nenhuma (ainda sem adições no Homebrew).
- **Apps GUI (Flatpak)**: Zen Browser.

### Removidos/Desativados

- Nenhum.

### Mudanças de configuração

- Sessões de desktop duplas disponíveis no GDM (GNOME e COSMIC).

*Última atualização: 2026-02-03*

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

Build local:

```bash
just build
```

Criar imagem de VM:

```bash
just build-qcow2
```

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
