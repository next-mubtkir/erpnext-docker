# ERPNext Docker Deployment

[English](README.md) | **Português**

Deploy do ERPNext v16 com Docker Compose, Traefik e apps adicionais (Helpdesk, CRM, Frappe Assistant).

## Início Rápido

### Pré-requisitos

- Docker
- Docker Compose v2

### Ambiente Local

```bash
# 1. Copiar variáveis de ambiente e editar senhas
cp .env.example .env
# Edite o .env e defina DB_PASSWORD e ADMIN_PASSWORD

# 2. Gerar certificados SSL para localhost (veja seção Certificados SSL abaixo)

# 3. Adicionar ao /etc/hosts
echo "127.0.0.1 erpnext.localhost" | sudo tee -a /etc/hosts

# 4. Iniciar
./start-local.sh

# 5. Acessar
# https://erpnext.localhost:9443
```

### Certificados SSL (Local)

Para HTTPS local, você precisa gerar certificados auto-assinados:

```bash
# Criar diretório de certificados
mkdir -p traefik/certs

# Gerar certificado auto-assinado
openssl req -x509 -newkey rsa:4096 -keyout traefik/certs/erpnext.localhost-key.pem -out traefik/certs/erpnext.localhost.pem -days 365 -nodes -subj "/CN=erpnext.localhost"

# Adicionar aos certificados confiáveis (macOS)
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain traefik/certs/erpnext.localhost.pem

# Para Linux (Ubuntu/Debian)
sudo cp traefik/certs/erpnext.localhost.pem /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### Portas (Local)

| Serviço | Porta |
|---------|-------|
| HTTP | 9080 |
| HTTPS | 9443 |
| Dashboard Traefik | 9081 |

## Apps Instalados

| App | Versão |
|-----|--------|
| frappe | 16.9.0 |
| erpnext | 16.6.1 |
| crm | 1.59.2 |
| telephony | 0.0.1 |
| helpdesk | 1.20.2 |
| frappe_assistant_core | 2.3.1 |

## Estrutura do Projeto

```
├── apps.json                 # Apps para build customizado
├── build-image.sh            # Build de imagem customizada
├── compose.yaml              # Configuração base do compose
├── compose.local.yaml        # Override para ambiente local
├── compose.prd.yaml          # Override para produção
├── traefik-compose.yaml      # Traefik local
├── .env.example              # Template de variáveis de ambiente
├── start-local.sh            # Script de inicialização local
├── start-prd.sh              # Script de inicialização produção
├── images/custom/Containerfile
├── resources/core/nginx/
└── traefik/
    ├── traefik.yml
    └── dynamic/
        └── certs.yml
```

## Comandos

### Local

```bash
./start-local.sh start    # Iniciar (Traefik + ERPNext)
./start-local.sh stop     # Parar tudo
./start-local.sh restart  # Reiniciar
./start-local.sh status   # Status dos containers
./start-local.sh logs     # Ver logs
./start-local.sh reset    # Reset completo (DESTRUTIVO)
```

### Produção

```bash
./start-prd.sh start    # Iniciar
./start-prd.sh stop     # Parar
./start-prd.sh restart  # Reiniciar
./start-prd.sh status   # Status
./start-prd.sh logs     # Logs
./start-prd.sh backup   # Backup do banco de dados
./start-prd.sh migrate  # Executar migrações
./start-prd.sh console  # Console Python
```

## Build de Imagem Customizada

O ERPNext v16 requer Python 3.14. Para construir uma imagem customizada:

```bash
# Edite o apps.json com os apps desejados
./build-image.sh           # Build normal
./build-image.sh --no-cache  # Build sem cache
```

Após o build, atualize o `.env`:

```bash
CUSTOM_IMAGE=erpnext-custom
CUSTOM_TAG=16
PULL_POLICY=missing
```

## Arquitetura

```
                    ┌─────────────────┐
                    │    Traefik      │
                    │  SSL/HTTPS      │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │         frontend            │
              │    (Nginx - porta 8080)     │
              └──────────────┬──────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────┴────┐        ┌─────┴─────┐      ┌──────┴──────┐
    │ backend │        │ websocket │      │   scheduler │
    └────┬────┘        └───────────┘      └─────────────┘
         │
    ┌────┴────────────────────────────┐
    │                                 │
┌───┴────┐   ┌────────────┐   ┌───────┴───────┐
│ MariaDB│   │    Redis   │   │ Queue Workers │
│   db   │   │ cache+queue│   │ short + long  │
└────────┘   └────────────┘   └───────────────┘
```

## Variáveis de Ambiente

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `ERPNEXT_VERSION` | Versão do ERPNext | `version-16` |
| `FRAPPE_VERSION` | Versão do Frappe | `version-16` |
| `CUSTOM_IMAGE` | Nome da imagem customizada | `frappe/erpnext` |
| `CUSTOM_TAG` | Tag da imagem | `version-16` |
| `PULL_POLICY` | Política de pull | `always` |
| `DB_PASSWORD` | Senha root do MariaDB | - |
| `ADMIN_PASSWORD` | Senha admin do site | - |
| `SITE_NAME` | Nome do site | - |
| `MARIADB_VERSION` | Versão do MariaDB | `11.8` |
| `REDIS_VERSION` | Versão do Redis | `6.2-alpine` |

## Troubleshooting

### Site não carrega

```bash
# Verificar containers
./start-local.sh status

# Ver logs
docker compose logs backend --tail=50

# Reiniciar
./start-local.sh restart
```

### Erro de banco de dados

```bash
# Verificar saúde do MariaDB
docker compose ps db

# Reiniciar banco
docker compose restart db
```

### Reset completo

```bash
./start-local.sh reset
```

## Deploy em Produção

1. Copie `.env.example` para `.env` e defina os valores de produção
2. Atualize `SITE_NAME` para seu domínio
3. Certifique-se de que o Traefik está configurado com Let's Encrypt
4. Execute `./start-prd.sh start`
5. Crie o site:

```bash
docker compose exec backend bench new-site seu-dominio.com \
    --mariadb-user-host-login-scope='%' \
    --db-root-password 'SUA_SENHA_DB' \
    --admin-password 'SUA_SENHA_ADMIN' \
    --install-app erpnext
```

## Referências

- [Documentação ERPNext](https://docs.erpnext.com)
- [Documentação Frappe](https://frappeframework.com/docs)
- [Fórum da Comunidade](https://discuss.frappe.io)
- [Frappe Docker GitHub](https://github.com/frappe/frappe_docker)
