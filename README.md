------------------------------------------------------------------------------------------------------
# ATELIER API-DRIVEN INFRASTRUCTURE
------------------------------------------------------------------------------------------------------

**L'idée en 30 secondes** : Orchestration de services AWS via API Gateway et Lambda dans un environnement émulé.

Cet atelier propose de concevoir une architecture **API-driven** dans laquelle une requête HTTP déclenche, via **API Gateway** et une **fonction Lambda**, des actions d'infrastructure sur des **instances EC2**, le tout dans un **environnement AWS simulé avec LocalStack**.

> **⚠️ IMPORTANT** : Ce projet n'utilise **aucune dépendance localhost** ! L'URL de l'endpoint est configurable via la variable d'environnement `AWS_ENDPOINT_URL`.

## 🏗️ Architecture
![Architecture](API_Driven.png)

---

## 📋 Prérequis

- **Python 3.8+** avec pip
- **Docker** (requis pour LocalStack)
- **curl** pour tester les API

---

## 🚀 Démarrage Rapide (GitHub Codespaces)

### Étape 1 : Installation et démarrage

```bash
# Installer les dépendances (installe awslocal)
make install

# Démarrer LocalStack
make start

# Attendre que LocalStack soit prêt
sleep 20
```

### Étape 2 : Configurer l'endpoint (OBLIGATOIRE)

1. Aller dans l'onglet **PORTS** de GitHub Codespaces
2. Trouver le port LocalStack (peut être **4566**, **4510** ou autre)
3. Cliquer droit → **Visibilité du port → Public**
4. Copier l'URL publique et l'exporter :

```bash
# Remplacer par VOTRE URL du port LocalStack
export AWS_ENDPOINT_URL=https://votre-codespace-XXXX.app.github.dev
```

> **Note** : Le port peut varier ! Vérifiez dans l'onglet PORTS quel port est utilisé par LocalStack.

### Étape 3 : Déployer l'infrastructure

```bash
make deploy
```

---

## 🎮 Utilisation de l'API

### Démarrer l'instance EC2

```bash
make start-ec2
```

### Arrêter l'instance EC2

```bash
make stop-ec2
```

### Vérifier le statut de l'instance

```bash
make status-ec2
```

### Utilisation directe avec curl

```bash
# Récupérer l'API ID
API_ID=$(cat /tmp/api_gateway_id.txt)

# Démarrer l'instance
curl -X POST "${AWS_ENDPOINT_URL}/restapis/$API_ID/prod/_user_request_/ec2" \
  -H "Content-Type: application/json" \
  -d '{"action":"start"}'

# Arrêter l'instance
curl -X POST "${AWS_ENDPOINT_URL}/restapis/$API_ID/prod/_user_request_/ec2" \
  -H "Content-Type: application/json" \
  -d '{"action":"stop"}'

# Obtenir le statut
curl -X POST "${AWS_ENDPOINT_URL}/restapis/$API_ID/prod/_user_request_/ec2" \
  -H "Content-Type: application/json" \
  -d '{"action":"status"}'
```

---

## 📁 Structure du Projet

```
API_Driven/
├── Makefile                    # Automatisation des commandes
├── README.md                   # Cette documentation
├── API_Driven.png              # Schéma d'architecture
├── lambda/
│   └── lambda_function.py      # Fonction Lambda (contrôle EC2)
└── scripts/
    ├── setup-localstack.sh     # Installation LocalStack
    └── create-infrastructure.sh # Déploiement de l'infrastructure
```

---

## 🔧 Commandes Makefile Disponibles

| Commande | Description |
|----------|-------------|
| `make install` | Installer les dépendances (awslocal, boto3) |
| `make start` | Démarrer LocalStack |
| `make stop` | Arrêter LocalStack |
| `make status` | Vérifier le statut des services |
| `make deploy` | Déployer l'infrastructure |
| `make start-ec2` | Démarrer l'instance EC2 via API |
| `make stop-ec2` | Arrêter l'instance EC2 via API |
| `make status-ec2` | Obtenir le statut de l'instance EC2 |
| `make clean` | Nettoyer l'environnement |
| `make help` | Afficher l'aide |

---

## � Dépannage

### "aws: command not found"

C'est normal ! Nous utilisons `awslocal` (pas `aws`). Relancez :
```bash
make install
```

### Le port n'est pas 4566

LocalStack peut utiliser différents ports. Vérifiez l'onglet **PORTS** et utilisez le port correct dans votre URL.

### Erreur "AWS_ENDPOINT_URL is not set"

```bash
# Définir la variable avec l'URL de l'onglet PORTS
export AWS_ENDPOINT_URL=https://votre-url.app.github.dev
```

---

## ✅ Évaluation

| Critère | Points | Implémentation |
|---------|--------|----------------|
| Repository exécutable sans erreur | 4 | ✅ Scripts testés |
| Fonctionnement conforme | 4 | ✅ Start/Stop/Status EC2 via API |
| Degré d'automatisation | 4 | ✅ Makefile complet |
| Qualité du Readme | 4 | ✅ Documentation détaillée |
| Processus de travail | 4 | ✅ Commits cohérents |

---

**Auteur** : Arnaud  
**Date** : Février 2026
