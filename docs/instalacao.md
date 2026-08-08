# Instalando o bluefin-cosmic-dx

Este guia explica como começar com o bluefin-cosmic-dx do zero: instale a ISO oficial do Bluefin e depois faça o rebase para esta imagem COSMIC-only.

## Pré-requisitos

- Um pendrive USB (mínimo 8 GB)
- Backup dos dados importantes da máquina de destino
- Conexão com a internet

## 1. Baixe a ISO do Bluefin

Acesse a página oficial de instalação:

**[docs.projectbluefin.io/installation](https://docs.projectbluefin.io/installation/)**

Escolha a ISO conforme sua necessidade:

| ISO            | Ideal para                                  |
| -------------- | ------------------------------------------- |
| **Bluefin**    | Uso geral com GNOME                         |
| **Bluefin DX** | Desenvolvedores — inclui ferramentas extras |

Qualquer uma das duas funciona. O rebase na seção 4 substituirá o ambiente desktop por COSMIC independentemente da sua escolha.

## 2. Grave a ISO no pendrive

Use o **Fedora Media Writer** — uma ferramenta simples e confiável disponível para Linux, Windows e macOS.

1. Baixe o Fedora Media Writer em [fedoraproject.org](https://fedoraproject.org/workstation/download/) (role até o final para o download independente)
2. Abra a ferramenta e selecione **"Gravar imagem personalizada"** (ou arraste o arquivo `.iso` baixado para a janela)
3. Selecione seu pendrive na lista
4. Clique em **"Gravar"** e aguarde a conclusão

> **Atenção:** Todo o conteúdo do pendrive será apagado.

## 3. Instale o Bluefin

1. Insira o pendrive na máquina de destino e inicie a partir dele (pressione F2, F12 ou Del na inicialização para selecionar o dispositivo de boot)
2. Selecione **"Install Bluefin"** no menu de boot
3. Siga o instalador guiado — escolha o idioma, layout do teclado, disco e crie sua conta de usuário
4. Ao finalizar a instalação, reinicie e remova o pendrive

Para um passo a passo detalhado com capturas de tela, consulte o [guia oficial de instalação](https://docs.projectbluefin.io/installation/).

## 4. Faça o rebase para bluefin-cosmic-dx

Entre no seu novo sistema Bluefin e abra um terminal. Execute um dos comandos abaixo:

**Padrão (GPUs Intel/AMD, VMs):**

```bash
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx:stable
```

**NVIDIA (GPUs RTX):**

```bash
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia:stable
```

Depois reinicie:

```bash
sudo systemctl reboot
```

O sistema agora iniciará com o COSMIC Greeter e a sessão desktop COSMIC.

## 5. Pós-instalação

Após fazer login:

```bash
# Verifique se o COSMIC está rodando
echo $XDG_CURRENT_DESKTOP   # deve exibir "COSMIC"

# Instale gerenciadores de desenvolvimento
ujust install-dev-managers

# Flatpaks são instalados automaticamente no primeiro boot — acompanhe:
flatpak list
```

Comandos `ujust` disponíveis:

```bash
ujust install-nvm        # Gerenciador de versões do Node.js
ujust install-sdkman     # Gerenciador de SDKs (Java, Kotlin, Gradle, etc.)
ujust install-dev-managers  # Ambos acima
ujust setup-vicinae-cosmic # Configurações do Vicinae para COSMIC
```

## Próximos passos

- [README](../README.pt-BR.md) — visão geral do projeto e instruções de build
- [Documentação oficial do Bluefin](https://docs.projectbluefin.io/)
- [Desktop COSMIC pela System76](https://system76.com/cosmic/)
