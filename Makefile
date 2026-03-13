.PHONY: dev test build deploy emulators clean lint setup

# ── Local Development ────────────────────────────────
dev:
	docker compose up --build

dev-detached:
	docker compose up --build -d

stop:
	docker compose down

# ── Firebase Emulators (standalone, no Docker) ───────
emulators:
	firebase emulators:start --project ticktick-clone-local --import ./emulator-data --export-on-exit ./emulator-data

# ── Testing ──────────────────────────────────────────
test:
	cd backend && npm test

test-watch:
	cd backend && npm run test:watch

lint:
	cd backend && npm run lint

# ── Build ────────────────────────────────────────────
build:
	docker build -t ticktick-clone-api -f infrastructure/Dockerfile .

build-frontend:
	cd frontend && flutter build web

# ── Deploy ───────────────────────────────────────────
deploy:
	gcloud builds submit --config cloudbuild.yaml .

deploy-rules:
	firebase deploy --only firestore:rules

deploy-indexes:
	firebase deploy --only firestore:indexes

deploy-hosting:
	cd frontend && flutter build web
	firebase deploy --only hosting

# ── Setup ────────────────────────────────────────────
setup:
	cd backend && npm install
	cd frontend && flutter pub get
	firebase setup:emulators:firestore
	firebase setup:emulators:auth
	@echo "Setup complete. Run 'make dev' to start development."

# ── Cleanup ──────────────────────────────────────────
clean:
	docker compose down -v --rmi local
	rm -rf backend/node_modules backend/dist
	rm -rf frontend/build
