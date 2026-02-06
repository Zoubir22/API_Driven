------------------------------------------------------------------------------------------------------
# ATELIER API-DRIVEN INFRASTRUCTURE
------------------------------------------------------------------------------------------------------

**Orchestration de services AWS via API Gateway et Lambda dans un environnement émulé (LocalStack).**

![Architecture](API_Driven.png)

---

## 🚀 Démarrage Rapide (GitHub Codespaces)

```bash
# 1. Installer les dépendances
make install

# 2. Démarrer LocalStack
make start
sleep 20

# 3. Dans l'onglet PORTS, rendre le port 4566 PUBLIC
# 4. Copier l'URL et l'exporter
export AWS_ENDPOINT_URL=https://votre-codespace-4566.app.github.dev

# 5. Déployer l'infrastructure
make deploy

# 6. Tester les APIs
make status-ec2
make stop-ec2
make start-ec2
```

---

## 🎮 Commandes Disponibles

| Commande | Description |
|----------|-------------|
| `make install` | Installer les dépendances |
| `make start` | Démarrer LocalStack |
| `make deploy` | Déployer EC2 + Lambda + API Gateway |
| `make status-ec2` | Voir le statut de l'instance EC2 |
| `make stop-ec2` | Arrêter l'instance EC2 |
| `make start-ec2` | Démarrer l'instance EC2 |
| `make clean` | Nettoyer l'environnement |

---

## 📡 Utilisation de l'API avec curl

```bash
# Statut de l'instance
curl -X POST "${AWS_ENDPOINT_URL}/restapis/<API_ID>/prod/_user_request_/ec2" \
  -H "Content-Type: application/json" \
  -d '{"action":"status"}'

# Arrêter l'instance
curl -X POST "${AWS_ENDPOINT_URL}/restapis/<API_ID>/prod/_user_request_/ec2" \
  -H "Content-Type: application/json" \
  -d '{"action":"stop"}'

# Démarrer l'instance
curl -X POST "${AWS_ENDPOINT_URL}/restapis/<API_ID>/prod/_user_request_/ec2" \
  -H "Content-Type: application/json" \
  -d '{"action":"start"}'
```

> **Note** : L'API_ID est affiché après `make deploy`. Le header `Content-Type: application/json` est **obligatoire**.

---

## 📁 Structure du Projet

```
API_Driven/
├── Makefile                        # Automatisation
├── README.md                       # Documentation
├── API_Driven.png                  # Schéma d'architecture
├── lambda/
│   └── lambda_function.py          # Fonction Lambda (contrôle EC2)
└── scripts/
    ├── create-infrastructure.py    # Déploiement (Python/boto3)
    └── setup-localstack.sh         # Installation LocalStack
```

---

## 🔧 Architecture

```
HTTP Request → API Gateway → Lambda → EC2 (start/stop/status)
                    ↑
              LocalStack (AWS émulé)
```

---

## ⚠️ Important

- **Port** : LocalStack utilise le port **4566** (vérifiez dans l'onglet PORTS)
- **Visibilité** : Le port doit être **Public** dans GitHub Codespaces
- **Variable** : `AWS_ENDPOINT_URL` doit être définie avant `make deploy`

---

## ✅ Critères d'Évaluation

| Critère | Status |
|---------|--------|
| Repository exécutable sans erreur | ✅ |
| Fonctionnement conforme | ✅ |
| Automatisation (Makefile) | ✅ |
| Qualité du README | ✅ |

---

**Auteur** : Arnaud Louvois 
**Date** : Février 2026
