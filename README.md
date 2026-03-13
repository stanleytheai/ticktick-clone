# TickTick Clone

Full-featured task management app built with Flutter (mobile/web) and Node.js (backend) on Google Cloud.

See [FEATURES.md](FEATURES.md) for the complete feature specification.

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Node.js | 20+ | [nodejs.org](https://nodejs.org/) |
| Flutter | 3.24+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Firebase CLI | latest | `npm install -g firebase-tools` |
| Docker | 24+ | [docker.com](https://www.docker.com/get-started) |
| Google Cloud SDK | latest | [cloud.google.com/sdk](https://cloud.google.com/sdk/docs/install) |

## Project Structure

```
ticktick-clone/
├── backend/                # Node.js API (Express/Fastify)
│   ├── src/
│   ├── package.json
│   └── tsconfig.json
├── frontend/               # Flutter app (mobile + web)
│   ├── lib/
│   ├── test/
│   └── pubspec.yaml
├── infrastructure/
│   └── Dockerfile          # Multi-stage Docker build
├── .github/
│   └── workflows/
│       └── ci.yml          # GitHub Actions CI pipeline
├── docker-compose.yml      # Local dev (backend + Firebase emulators)
├── docker-compose.prod.yml # Production overrides
├── cloudbuild.yaml         # GCP Cloud Build pipeline
├── firebase.json           # Firebase config (emulators, hosting, rules)
├── firestore.rules         # Firestore security rules
├── firestore.indexes.json  # Firestore composite indexes
├── Makefile                # Dev commands
├── FEATURES.md             # Feature specification
└── README.md
```

## Local Development Setup

### 1. Clone and install dependencies

```bash
git clone https://github.com/stanleytheai/ticktick-clone.git
cd ticktick-clone
make setup
```

### 2. Start with Docker (recommended)

This starts the backend and Firebase emulators together:

```bash
make dev
```

| Service | URL |
|---------|-----|
| Backend API | http://localhost:3000 |
| Firebase Emulator UI | http://localhost:4000 |
| Firestore Emulator | localhost:8080 |
| Auth Emulator | localhost:9099 |

### 3. Start without Docker

Run Firebase emulators standalone:

```bash
make emulators
```

In a separate terminal, start the backend:

```bash
cd backend
FIRESTORE_EMULATOR_HOST=localhost:8080 FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 npm run dev
```

### 4. Run the Flutter frontend

```bash
cd frontend
flutter run -d chrome    # Web
flutter run              # Mobile (connected device/emulator)
```

## Running with Emulators

Firebase emulators provide local versions of Firestore, Auth, and other services. Data persists between restarts via the `emulator-data/` directory.

The backend auto-connects to emulators when these environment variables are set:

- `FIRESTORE_EMULATOR_HOST=localhost:8080`
- `FIREBASE_AUTH_EMULATOR_HOST=localhost:9099`

The Emulator UI at http://localhost:4000 lets you inspect data, create test users, and trigger functions.

## Testing

```bash
make test           # Run backend tests once
make test-watch     # Run tests in watch mode
make lint           # Run linter
```

## Building

```bash
make build          # Build Docker image
make build-frontend # Build Flutter web app
```

## Deploying to GCP

### Initial GCP Setup

```bash
# Create a GCP project
gcloud projects create ticktick-clone --name="TickTick Clone"
gcloud config set project ticktick-clone

# Enable required APIs
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  firestore.googleapis.com

# Create Artifact Registry repository
gcloud artifacts repositories create ticktick-clone \
  --repository-format=docker \
  --location=us-central1

# Initialize Firestore
gcloud firestore databases create --location=us-central1

# Deploy security rules and indexes
make deploy-rules
make deploy-indexes
```

### Deploy

```bash
make deploy         # Full deploy via Cloud Build (test → build → push → deploy)
make deploy-hosting # Deploy Flutter web to Firebase Hosting
```

### CI/CD

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs automatically on:
- Push to `main`
- Pull requests targeting `main`

It runs backend tests, Flutter analysis, and validates the Docker build.

For production deploys, Cloud Build (`cloudbuild.yaml`) handles the full pipeline:
test → build image → push to Artifact Registry → deploy to Cloud Run.

## Make Commands

| Command | Description |
|---------|-------------|
| `make dev` | Start backend + emulators with Docker |
| `make stop` | Stop Docker services |
| `make emulators` | Start Firebase emulators standalone |
| `make test` | Run backend tests |
| `make lint` | Lint backend code |
| `make build` | Build Docker image |
| `make deploy` | Deploy to GCP via Cloud Build |
| `make deploy-rules` | Deploy Firestore security rules |
| `make deploy-hosting` | Build and deploy Flutter web |
| `make setup` | Install all dependencies |
| `make clean` | Remove containers, volumes, build artifacts |
