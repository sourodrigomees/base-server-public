# Instalador do base-server

Este repositório contém o instalador público do **base-server**. Com um único comando, ele:

1. pergunta se o repositório privado será clonado por **SSH** ou **HTTPS**;
2. instala as dependências necessárias (`git`, certificados e, no modo SSH, o cliente SSH);
3. solicita a credencial correspondente (chave SSH ou token do GitHub);
4. clona o projeto em `/opt/base-server`;
5. executa o `install.sh` do projeto clonado.

## Instalação

Em um servidor Debian ou Ubuntu, execute:

```bash
curl -fsSL https://raw.githubusercontent.com/sourodrigomees/base-server-public/main/install.sh | sudo bash
```

O instalador começa perguntando como clonar o repositório:

- **[1] SSH** (padrão): cole a chave privada SSH com acesso ao repositório
  `sourodrigomees/base-server`. Pressione **Enter** e depois **Ctrl-D** para continuar.
- **[2] HTTPS**: informe um *fine-grained personal access token* do GitHub com a permissão
  **Contents: Read** no repositório `sourodrigomees/base-server`. O token não aparece na
  tela enquanto é digitado.

> O instalador precisa ser executado em um terminal interativo para receber a credencial.
> Para instalações automatizadas, defina `BASE_SERVER_CLONE_METHOD` e
> `BASE_SERVER_REPOSITORY_URL` (com a credencial embutida) e o instalador não perguntará nada.

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
| `BASE_SERVER_CLONE_METHOD` | pergunta interativa | Método de clone: `ssh` ou `https` |
| `BASE_SERVER_REPOSITORY_SLUG` | `sourodrigomees/base-server` | Repositório clonado (`dono/nome`) |
| `BASE_SERVER_REPOSITORY_URL` | derivada do método e do slug | URL completa de clone (sobrepõe as duas acima) |
| `BASE_SERVER_INSTALL_SCRIPT` | `install.sh` | Script executado após o clone |
| `BASE_SERVER_GIT_HOST` | `github.com` | Host SSH do Git |

## Segurança

No modo SSH, a chave informada é salva em `/root/.ssh/id_ed25519`, com permissão `600`.
Se essa chave já existir, o instalador a reutiliza e não solicita uma nova.

No modo HTTPS, o token não é gravado em disco: ele é usado apenas na URL do `git clone`
e, logo depois, o remote `origin` é reescrito para `https://github.com/<repo>.git`, de
modo que nenhuma credencial fica em `.git/config`.

Confira o conteúdo
do script antes de executá-lo como administrador:

```bash
curl -fsSL https://raw.githubusercontent.com/sourodrigomees/base-server-public/main/install.sh
```

O instalador interrompe a execução se `/opt/base-server` já existir, evitando sobrescrever
uma instalação anterior.
