# bluefin-cosmic-dx

Este projeto foi criado usando o template finpilot: <https://github.com/projectbluefin/finpilot>.

Versão em inglês: [README.md](README.md)

Ele constrói uma imagem bootc customizada baseada no Bluefin, usando o padrão multi-stage OCI do ecossistema Bluefin.

## O que é esta imagem

bluefin-cosmic-dx é uma imagem Bluefin focada em desenvolvimento, com COSMIC como desktop e um conjunto de ferramentas DX.

## O que muda nesta versão

Em relação ao Bluefin DX, esta imagem adiciona:

- Desktop COSMIC (System76) instalado via COPR
- VSCode Insiders (editor padrão) instalado via RPM
- Warp Terminal instalado via RPM
- Ferramentas DX embutidas na imagem (containers, virtualização e toolchain de build)

Imagem base: ghcr.io/ublue-os/base-main:latest

## Uso básico

Build local:

1. Rode o build:
 ```bash
 sudo just build
 ```

Criar imagem de VM:

1. Gere um QCOW2:
 ```bash
 sudo just build-qcow2
 ```

Trocar seu sistema para esta imagem:

1. Rebase:
 ```bash
 sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx:stable
 ```

2. Reinicie:
 ```bash
 sudo systemctl reboot
 ```

Voltar para o Bluefin DX:

1. Rebase de volta:
 ```bash
 sudo bootc switch ghcr.io/ublue-os/bluefin-dx:stable
 ```

2. Reinicie:
 ```bash
 sudo systemctl reboot
 ```
