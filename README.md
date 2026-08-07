# Instalador do base-server

Este repositório contém o instalador público do **base-server**. Com um único comando, ele:

1. instala as dependências necessárias (`git` e certificados);
2. solicita um *fine-grained personal access token* do GitHub;
3. clona o projeto privado em `/opt/base-server`;
4. salva o token para que as atualizações futuras não peçam a credencial de novo;
5. executa o `install.sh` do projeto clonado.

## Instalação

Em um servidor Debian ou Ubuntu, execute:

```bash
curl -fsSL https://raw.githubusercontent.com/sourodrigomees/base-server-public/main/install.sh | sudo bash
```

O instalador pede um *fine-grained personal access token* do GitHub com a permissão
**Contents: Read** no repositório `sourodrigomees/base-server`. O token não aparece na tela
enquanto é digitado.

> O instalador precisa de um terminal interativo para receber o token. Para instalações
> automatizadas, defina `BASE_SERVER_GITHUB_TOKEN` e nada será perguntado.

Ao terminar, o instalador do projeto privado já terá sido executado. Não é necessário
entrar na pasta e iniciar outro script manualmente.

## Atualizando o projeto

```bash
sudo git -C /opt/base-server pull
```

O token informado na instalação fica salvo em `/root/.git-credentials` e é reutilizado
automaticamente, então o `git pull` não pede credencial. Quando o token expirar, basta
regravar o arquivo:

```bash
printf 'https://x-access-token:NOVO_TOKEN@github.com\n' | sudo tee /root/.git-credentials >/dev/null
sudo chmod 600 /root/.git-credentials
```

## Requisitos

- Debian ou Ubuntu com `apt-get`;
- acesso de administrador por `sudo`;
- um token do GitHub com acesso de leitura ao repositório privado;
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
| `BASE_SERVER_GITHUB_TOKEN` | pergunta interativa | Token usado no clone e nas atualizações |
| `BASE_SERVER_REPOSITORY_SLUG` | `sourodrigomees/base-server` | Repositório clonado (`dono/nome`) |
| `BASE_SERVER_CREDENTIALS_FILE` | `/root/.git-credentials` | Arquivo onde o token é salvo |
| `BASE_SERVER_INSTALL_SCRIPT` | `install.sh` | Script executado após o clone |
| `BASE_SERVER_GIT_HOST` | `github.com` | Host do Git |

## Segurança

O token nunca é gravado no remote nem em `.git/config`: o `origin` fica como
`https://github.com/<repo>.git` e a autenticação vem do `credential.helper store` do Git,
que lê `/root/.git-credentials` (permissão `600`, legível apenas pelo root). Regravar o
arquivo substitui apenas a entrada do host correspondente; credenciais de outros hosts são
preservadas.

Confira o conteúdo do script antes de executá-lo como administrador:

```bash
curl -fsSL https://raw.githubusercontent.com/sourodrigomees/base-server-public/main/install.sh
```

O instalador interrompe a execução se `/opt/base-server` já existir, evitando sobrescrever
uma instalação anterior.
