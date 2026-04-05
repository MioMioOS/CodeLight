# CodeLight

> Monitor and control your Claude Code sessions from your iPhone — with Dynamic Island support.

CodeLight is a native Swift iOS app that connects to your Claude Code sessions in real-time. It works with [CodeIsland](https://github.com/xmqywx/CodeIsland) (macOS notch companion) to sync session data through a self-hosted relay server.

```
Claude Code ──hook──→ CodeIsland (Mac) ──socket.io──→ CodeLight Server ──socket.io──→ CodeLight (iPhone)
```

## Features

- **Real-time session sync** — See your Claude Code conversations on your iPhone as they happen
- **Multiple session monitoring** — Track all active Claude Code sessions across projects
- **Dynamic Island** — Live Activity shows current session status (thinking, tool running, waiting for approval)
- **Send messages** — Type messages to Claude Code from your phone
- **Model/Mode selector** — Switch between Opus/Sonnet/Haiku and permission modes
- **E2E encryption** — Server is zero-knowledge, stores only ciphertext
- **QR code pairing** — Scan to connect, no accounts or passwords
- **Self-hosted** — Run your own server, own your data
- **Multi-server** — Connect to multiple CodeLight servers

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Mac                              │
│                                                         │
│   Claude Code ──hooks──→ CodeIsland                     │
│                            ├─ Notch UI (local)          │
│                            └─ Socket.io → Server        │
└─────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────┐
│              CodeLight Server (self-hosted)              │
│                                                         │
│   Fastify + Socket.io + PostgreSQL                      │
│   • Public key auth (Ed25519, no passwords)             │
│   • Session & message relay (encrypted)                 │
│   • RPC forwarding (phone → Mac)                        │
│   • APNs push notifications                             │
└─────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────┐
│                   Your iPhone                           │
│                                                         │
│   CodeLight App (SwiftUI)                               │
│   • Session list (grouped by project)                   │
│   • Chat view (messages, tool calls, thinking)          │
│   • Send messages to Claude                             │
│   • Dynamic Island status                               │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

```
CodeLight/
├── server/                          # Relay server (Node.js)
│   ├── sources/
│   │   ├── main.ts                  # Entry point
│   │   ├── api.ts                   # Fastify setup
│   │   ├── config.ts                # Environment config
│   │   ├── auth/
│   │   │   ├── crypto.ts            # Ed25519 + JWT
│   │   │   ├── middleware.ts        # Bearer token auth
│   │   │   └── authRoutes.ts        # POST /v1/auth
│   │   ├── pairing/
│   │   │   └── pairingRoutes.ts     # QR code pairing flow
│   │   ├── session/
│   │   │   └── sessionRoutes.ts     # Session CRUD + messages
│   │   ├── socket/
│   │   │   ├── socketServer.ts      # Socket.io setup
│   │   │   ├── eventRouter.ts       # Broadcast routing
│   │   │   ├── sessionHandler.ts    # Real-time message handling
│   │   │   └── rpcHandler.ts        # RPC forwarding
│   │   ├── push/
│   │   │   ├── apns.ts              # APNs integration
│   │   │   └── pushRoutes.ts        # Push token management
│   │   └── storage/
│   │       ├── db.ts                # Prisma client
│   │       └── seq.ts               # Sequence allocation
│   ├── prisma/
│   │   └── schema.prisma            # Database schema
│   └── package.json
│
├── app/                             # iOS app (SwiftUI)
│   ├── CodeLight.xcodeproj
│   ├── CodeLight/
│   │   ├── CodeLightApp.swift       # App entry point
│   │   ├── Models/
│   │   │   ├── AppState.swift       # Global state
│   │   │   ├── SocketClient.swift   # Server connection
│   │   │   ├── PushManager.swift    # Push notifications
│   │   │   ├── LiveActivityManager.swift
│   │   │   └── CodeLightActivity.swift  # ActivityAttributes
│   │   └── Views/
│   │       ├── RootView.swift       # Navigation root
│   │       ├── PairingView.swift    # QR scanner + manual URL
│   │       ├── ServerListView.swift # Paired servers
│   │       ├── SessionListView.swift # Active sessions
│   │       └── ChatView.swift       # Messages + input
│   └── CodeLightWidget/
│       ├── CodeLightWidgetBundle.swift
│       ├── CodeLightLiveActivity.swift  # Dynamic Island UI
│       └── Info.plist
│
├── packages/                        # Shared Swift Packages
│   ├── CodeLightProtocol/           # Message types, auth types
│   ├── CodeLightCrypto/             # KeyManager, MessageCrypto
│   └── CodeLightSocket/             # Socket.io client wrapper
│
└── DESIGN.md                        # Full design specification
```

## Getting Started

### Prerequisites

- macOS 14+ with Xcode 26+
- Node.js 20+
- PostgreSQL 16+
- An iPhone running iOS 17+
- [CodeIsland](https://github.com/xmqywx/CodeIsland) installed on your Mac

### 1. Deploy the Server

```bash
# Clone the repo
git clone https://github.com/xmqywx/CodeLight.git
cd CodeLight/server

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your database URL and a random MASTER_SECRET:
#   DATABASE_URL=postgresql://user:password@localhost:5432/codelight
#   MASTER_SECRET=<random-64-char-hex-string>
#   PORT=3006

# Create database and run migrations
createdb codelight
npx dotenv -e .env -- prisma migrate dev --name init

# Start the server
npm start
```

For production, use pm2:

```bash
pm2 start 'npx tsx --env-file=.env ./sources/main.ts' --name codelight-server
```

#### Nginx Reverse Proxy (recommended)

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3006;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_buffering off;
    }
}
```

### 2. Build the iOS App

```bash
cd CodeLight/app
open CodeLight.xcodeproj
```

In Xcode:
1. Select your development team in **Signing & Capabilities** for both targets (CodeLight + CodeLightWidgetExtension)
2. Select your iPhone device
3. Press **⌘R** to build and run

On first launch, enter your server URL (e.g., `https://your-domain.com`) to connect.

### 3. Set Up CodeIsland

CodeIsland needs the `feature/codelight-sync` branch with the sync module:

1. Open CodeIsland in Xcode
2. Add the shared Swift packages as local dependencies:
   - `CodeLight/packages/CodeLightProtocol`
   - `CodeLight/packages/CodeLightCrypto`
3. Add `socket.io-client-swift` (16.1.1+) as a remote SPM dependency
4. Build and run

CodeIsland will automatically connect to the server on launch and start syncing your Claude Code sessions.

## Server API

### Authentication

```
POST /v1/auth
```

Public key challenge-response authentication using Ed25519 signatures. No accounts, no passwords — your public key is your identity.

```json
{
  "publicKey": "<base64>",
  "challenge": "<base64>",
  "signature": "<base64>"
}
```

Returns a JWT token for subsequent requests.

### Sessions

```
GET    /v1/sessions                          # List all sessions
POST   /v1/sessions                          # Create/load session (idempotent by tag)
GET    /v1/sessions/:id/messages             # Get messages (cursor-based)
POST   /v1/sessions/:id/messages             # Batch send messages
PATCH  /v1/sessions/:id/metadata             # Update metadata (optimistic concurrency)
DELETE /v1/sessions/:id                      # Delete session + messages
```

### Pairing

```
POST   /v1/pairing/request                   # Create QR pairing request
POST   /v1/pairing/respond                   # Respond to pairing (from scanner)
GET    /v1/pairing/status?tempPublicKey=...   # Poll pairing status
```

### Push Tokens

```
POST   /v1/push-tokens                       # Register device token
DELETE /v1/push-tokens/:token                # Remove token
GET    /v1/push-tokens                       # List tokens
```

### Socket.io Events

Connect to `/v1/updates` with auth token in query params:

| Event | Direction | Purpose |
|-------|-----------|---------|
| `message` | client → server | Send session message |
| `update` | server → client | Broadcast new messages |
| `ephemeral` | server → client | Transient status updates |
| `update-metadata` | client → server | Update session metadata |
| `session-alive` | client → server | Heartbeat |
| `session-end` | client → server | Mark session inactive |
| `rpc-call` | bidirectional | Remote procedure call forwarding |
| `rpc-register` | client → server | Register as RPC handler |

## Database Schema

Three core tables:

```
Device          — id, publicKey (unique), name, seq
Session         — id, tag (unique per device), metadata, metadataVersion, seq, active
SessionMessage  — id, sessionId, localId (dedup), seq, content
```

Plus `PairingRequest` (temporary) and `PushToken` for APNs.

## Security

- **Ed25519 public key authentication** — No passwords, no OAuth, no accounts
- **E2E encryption ready** — Server stores opaque content, ChaChaPoly encryption via CryptoKit
- **Zero-knowledge relay** — Server cannot read message content
- **JWT tokens** — Signed with server's master secret
- **Keychain storage** — Keys stored in iOS/macOS Keychain, never exported

## Dynamic Island

CodeLight shows live session status on iPhone's Dynamic Island:

| State | Compact | Expanded |
|-------|---------|----------|
| Thinking | 🟣 + timer | Project name + "Thinking..." |
| Tool running | 🔵 + timer | Project name + tool name |
| Needs approval | 🟠 + timer | Project name + "Needs approval" |
| Done | 🟢 | Dismissed after 5s |

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Server | Node.js, TypeScript, Fastify 5, Socket.io |
| Database | PostgreSQL + Prisma ORM |
| iOS App | Swift, SwiftUI, ActivityKit |
| Crypto | CryptoKit (ChaChaPoly, Ed25519), TweetNaCl |
| macOS Bridge | CodeIsland + Socket.io Swift client |

## Related Projects

- [CodeIsland](https://github.com/xmqywx/CodeIsland) — macOS notch companion for Claude Code (required for the Mac ↔ Server bridge)

## License

MIT
