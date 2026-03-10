## Corrigir acesso ao registro local do Docker no workflow

### Descrição:

Durante a execução do job https://github.com/ericrocha97/bluefin/actions/runs/22915655029/job/66500169999, o workflow falhou ao tentar puxar a imagem bluefin-cosmic-dx:stable do registro local (localhost). A mensagem de erro encontrada nos logs foi:

Error: initializing source docker://localhost/bluefin-cosmic-dx:stable: pinging container registry localhost: Get "https://localhost/v2/": dial tcp [::1]:443: connect: connection refused

### Motivo:

O workflow tenta acessar um registro local do Docker (localhost) sem este estar em execução, resultando em erro de conexão.

### Solução sugerida:
1. Iniciar um registro local na porta 5000 antes de executar comandos pull/push:

```
- name: Start local registry
  run: docker run -d -p 5000:5000 --name registry registry:2
```

2. Atualizar a referência das imagens para localhost:5000 e usar http ao invés de https.
3. Alternativamente, usar um registro externo (Docker Hub ou GitHub Container Registry) caso não seja obrigatório o registro local.

### Exemplo de correção para o arquivo .github/workflows/build.yml:

```
jobs:
  build:
    steps:
      - name: Start local registry
        run: docker run -d -p 5000:5000 --name registry registry:2

      - name: Build image
        run: docker build -t localhost:5000/bluefin-cosmic-dx:stable .

      - name: Push image
        run: docker push localhost:5000/bluefin-cosmic-dx:stable

      - name: Pull image for test
        run: docker pull localhost:5000/bluefin-cosmic-dx:stable
```

### Referência:

job d80249f804ec81ab7127ffa40086d98491fe86bc
