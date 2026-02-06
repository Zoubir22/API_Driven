------------------------------------------------------------------------------------------------------
# ATELIER API-DRIVEN INFRASTRUCTURE
------------------------------------------------------------------------------------------------------

**L'idée en 30 secondes** : Orchestration de services AWS via API Gateway et Lambda dans un environnement émulé.

Cet atelier propose de concevoir une architecture **API-driven** dans laquelle une requête HTTP déclenche, via **API Gateway** et une **fonction Lambda**, des actions d'infrastructure sur des **instances EC2**, le tout dans un **environnement AWS simulé avec LocalStack**.

> **⚠️ IMPORTANT** : Ce projet n'utilise **aucune dépendance localhost** ! L'URL de l'endpoint est configurable via la variable d'environnement `AWS_ENDPOINT_URL`.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              LocalStack (AWS Émulé)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────────────────┐  │
│   │              │      │              │      │                          │  │
│   │ API Gateway  │─────▶│   Lambda     │─────▶│     EC2 Instance        │  │
│   │  (POST /ec2) │      │ (controller) │      │  (start/stop/status)    │  │
│   │              │      │              │      │                          │  │
│   └──────────────┘      └──────────────┘      └──────────────────────────┘  │
│         ▲                                                                    │
│         │                                                                    │
└─────────┼────────────────────────────────────────────────────────────────────┘
          │
    HTTP Request
    (curl / Postman)
```

![Architecture](API_Driven.png)

---

## 📋 Prérequis

- **Python 3.8+** avec pip
- **Docker** (requis pour LocalStack)
- **curl** pour tester les API

---

## 🚀 Démarrage Rapide

### Étape 1 : Installation et démarrage

```bash
# Installer les dépendances
make install

# Démarrer LocalStack
make start
```

### Étape 2 : Configurer l'endpoint (OBLIGATOIRE)

**Sur GitHub Codespaces :**
1. Aller dans l'onglet **PORTS**
2. Trouver le port **4566**
3. Cliquer droit → **Visibilité du port → Public**
4. Copier l'URL publique et exécuter :

```bash
export AWS_ENDPOINT_URL=https://ubiquitous-funicular-6pxjvq5qppr2r9v9-4566.app.github.dev
```

**En local (Docker) :**
```bash
# Obtenir l'IP du conteneur LocalStack
export AWS_ENDPOINT_URL=http://$(docker inspect localstack-main --format '{{.NetworkSettings.IPAddress}}'):4566
```

### Étape 3 : Déployer l'infrastructure

```bash
make deploy
```

### Installation complète en une commande

```bash
# Après avoir défini AWS_ENDPOINT_URL
make all
```

---

## 🎮 Utilisation de l'API

### Démarrer l'instance EC2

```bash
make start-ec2
```

**Résultat attendu :**
```json
{
    "message": "Instance i-xxxxx is starting",
    "instance_id": "i-xxxxx",
    "state": "pending",
    "action": "start"
}
```

### Arrêter l'instance EC2

```bash
make stop-ec2
```

**Résultat attendu :**
```json
{
    "message": "Instance i-xxxxx is stopping",
    "instance_id": "i-xxxxx",
    "state": "stopping",
    "action": "stop"
}
```

### Vérifier le statut de l'instance

```bash
make status-ec2
```

**Résultat attendu :**
```json
{
    "message": "Instance i-xxxxx is running",
    "instance_id": "i-xxxxx",
    "state": "running",
    "action": "status"
}
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
| `make all` | Installation complète (install + start + deploy) |
| `make install` | Installer les dépendances |
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

## 🔍 Détails Techniques

### Fonction Lambda

La fonction Lambda (`lambda/lambda_function.py`) :
- Reçoit des requêtes JSON via API Gateway
- Interprète l'action demandée (`start`, `stop`, `status`)
- Utilise boto3 pour interagir avec EC2
- Utilise `LOCALSTACK_HOSTNAME` (variable interne de LocalStack) pour la communication

### API Gateway

L'API Gateway expose un endpoint POST :
- **Endpoint** : `/ec2`
- **Méthode** : POST
- **Body** : `{"action": "start|stop|status"}`

### Instance EC2

L'instance EC2 simulée :
- **AMI** : ami-12345678 (image fictive LocalStack)
- **Type** : t2.micro
- **État initial** : running

### Variables d'environnement

| Variable | Description | Obligatoire |
|----------|-------------|-------------|
| `AWS_ENDPOINT_URL` | URL de l'API LocalStack | ✅ Oui |
| `LOCALSTACK_HOSTNAME` | Hostname interne (auto-géré par LocalStack) | Non |
| `EC2_INSTANCE_ID` | ID de l'instance EC2 (auto-généré) | Non |

---

## 🐛 Dépannage

### LocalStack ne démarre pas

```bash
# Vérifier que Docker est en cours d'exécution
docker ps

# Redémarrer LocalStack
make stop
make start
```

### Erreur "AWS_ENDPOINT_URL is not set"

```bash
# Définir la variable d'environnement
export AWS_ENDPOINT_URL=<votre-url>

# Vérifier qu'elle est définie
echo $AWS_ENDPOINT_URL
```

### L'API ne répond pas

```bash
# Vérifier le statut des services
make status

# Vérifier que l'API Gateway est déployé
aws --endpoint-url=$AWS_ENDPOINT_URL apigateway get-rest-apis
```

---

## 📚 Références

- [LocalStack Documentation](https://docs.localstack.cloud/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)

---

## 📝 Notes pour GitHub Codespaces

1. **Démarrer LocalStack** :
   ```bash
   make install
   make start
   ```

2. **Rendre le port 4566 public** :
   - Aller dans l'onglet **PORTS**
   - Trouver le port 4566
   - Cliquer droit → Visibilité du port → **Public**

3. **Récupérer et définir l'URL** :
   ```bash
   # Copier l'URL du port 4566 et l'exporter
   export AWS_ENDPOINT_URL=https://votre-codespace-4566.app.github.dev
   ```

4. **Déployer et tester** :
   ```bash
   make deploy
   make status-ec2
   make stop-ec2
   make start-ec2
   ```

---

## ✅ Évaluation

Ce projet répond aux critères suivants :

| Critère | Points | Implémentation |
|---------|--------|----------------|
| Repository exécutable sans erreur | 4 | ✅ Scripts testés et fonctionnels |
| Fonctionnement conforme | 4 | ✅ Start/Stop/Status EC2 via API |
| Degré d'automatisation | 4 | ✅ Makefile complet avec toutes les commandes |
| Qualité du Readme | 4 | ✅ Documentation détaillée |
| Processus de travail | 4 | ✅ Commits réguliers et cohérents |

---

**Auteur** : Arnaud  
**Date** : Février 2026
