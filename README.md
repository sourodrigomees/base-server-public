# Instalador do base-server

Este repositório contém o instalador público do **base-server**. Com um único comando, ele:

1. instala as dependências necessárias (`git`, cliente SSH e certificados);
2. solicita a chave SSH que dá acesso ao repositório privado;
3. clona o projeto em `/opt/base-server`;
4. executa o `install.sh` do projeto clonado.

## Instalação

Em um servidor Debian ou Ubuntu, execute:

```bash
curl -fsSL https://raw.githubusercontent.com/sourodrigomees/base-server-public/main/install.sh | sudo bash
```

Quando solicitado, cole a chave privada SSH com acesso ao repositório
`sourodrigomees/base-server`. Pressione **Enter** e depois **Ctrl-D** para continuar.

> O instalador precisa ser executado em um terminal interativo para receber a chave SSH.

Ao terminar, o instalador do projeto privado já terá sido executado. Não é necessário
entrar na pasta e iniciar outro script manualmente.

## Requisitos

- Debian ou Ubuntu com `apt-get`;
- acesso de administrador por `sudo`;
- uma chave SSH autorizada no repositório privado;
- acesso à internet e ao GitHub.

## Personalização

Os valores padrão podem ser alterados passando variáveis ao shell executado pelo `sudo`:

```bash
curl -fsSL https://raw.githubusercontent.com/sourodrigomees/base-server-public/main/install.sh \
  | sudo BASE_SERVER_PROJECT_DIR=/srv/base-server bash
```

Variáveis disponíveis:

| Variável | Padrão | Finalidade |
| --- | --- | --- |
| `BASE_SERVER_PROJECT_DIR` | `/opt/base-server` | Diretório de instalação |
| `BASE_SERVER_REPOSITORY_URL` | `git@github.com:sourodrigomees/base-server.git` | Repositório clonado |
| `BASE_SERVER_INSTALL_SCRIPT` | `install.sh` | Script executado após o clone |
| `BASE_SERVER_GIT_HOST` | `github.com` | Host SSH do Git |

## Segurança

A chave informada é salva em `/root/.ssh/id_ed25519`, com permissão `600`. Se essa
chave já existir, o instalador a reutiliza e não solicita uma nova. Confira o conteúdo
do script antes de executá-lo como administrador:

```bash
curl -fsSL https://raw.githubusercontent.com/sourodrigomees/base-server-public/main/install.sh
```

O instalador interrompe a execução se `/opt/base-server` já existir, evitando sobrescrever
uma instalação anterior.
