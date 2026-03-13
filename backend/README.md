# TickTick Clone — Backend API

Node.js/TypeScript/Express REST API with Firebase Admin SDK for Firestore and Auth.

## Quick Start

```bash
# Install dependencies
npm install

# Copy environment config
cp .env.example .env

# Start Firebase emulators (from project root)
cd .. && docker-compose up -d && cd backend

# Run in development mode
npm run dev
```

## API Endpoints

All endpoints under `/api/v1/`. Protected routes require `Authorization: Bearer <firebase-id-token>`.

### Public
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/health` | Health check |

### Tasks (authenticated)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/tasks` | List all tasks |
| POST | `/api/v1/tasks` | Create a task |
| POST | `/api/v1/tasks/batch` | Create multiple tasks |
| GET | `/api/v1/tasks/:id` | Get a task |
| PUT | `/api/v1/tasks/:id` | Update a task |
| DELETE | `/api/v1/tasks/:id` | Delete a task |
| PATCH | `/api/v1/tasks/:id/complete` | Toggle completion |

### Subtasks (authenticated)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/tasks/:id/subtasks` | List subtasks |
| POST | `/api/v1/tasks/:id/subtasks` | Create a subtask |
| PUT | `/api/v1/tasks/:id/subtasks/:sid` | Update a subtask |
| DELETE | `/api/v1/tasks/:id/subtasks/:sid` | Delete a subtask |

### Lists (authenticated)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/lists` | List all lists |
| POST | `/api/v1/lists` | Create a list |
| GET | `/api/v1/lists/:id` | Get a list |
| PUT | `/api/v1/lists/:id` | Update a list |
| DELETE | `/api/v1/lists/:id` | Delete a list |

### Tags (authenticated)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/tags` | List all tags |
| POST | `/api/v1/tags` | Create a tag |
| GET | `/api/v1/tags/:id` | Get a tag |
| PUT | `/api/v1/tags/:id` | Update a tag |
| DELETE | `/api/v1/tags/:id` | Delete a tag |

## Firestore Collections

```
users/{uid}/tasks/{taskId}
users/{uid}/tasks/{taskId}/subtasks/{subtaskId}
users/{uid}/lists/{listId}
users/{uid}/tags/{tagId}
```

## Scripts

```bash
npm run dev        # Development server with hot reload
npm run build      # Compile TypeScript
npm start          # Run compiled output
npm run typecheck  # Type check without emitting
npm run lint       # Run ESLint
npm test           # Run tests
```
