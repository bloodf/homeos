# Layers

Quick index of HomeOS layers and where to verify them.

| Layer | Exists? | Source of truth | Docs |
| --- | --- | --- | --- |
| Bash installer | yes | `universal-installer/install.sh` | `docs/ARCHITECTURE.md`, `docs/INSTALLATION.md` |
| Installer config | yes | `install.sh`, `universal-installer/homeos.conf.example` | `docs/CONFIGURATION.md` |
| Embedded `homeos` CLI | yes | heredoc in `universal-installer/install.sh` | `docs/OPERATIONS.md` |
| Smoke tests | yes | `universal-installer/smoke-test.sh`, `Makefile` | `docs/TESTING.md` |
| CI | yes | `.github/workflows/installer-ci.yml` | `docs/DEPLOYMENT.md`, `docs/RELEASE-PROCESS.md` |
| Runtime Docker stacks | generated on target systems | `install.sh` stack generation functions | `docs/ARCHITECTURE.md`, `docs/OPERATIONS.md` |
| AI tooling/MCP isolation | yes, installer-managed on target systems | `install.sh`, `homeos.conf.example` | `docs/AI-INTEGRATIONS.md`, `docs/MCP.md`, `docs/SECURITY.md` |
| Frontend app | no repo source found | not applicable | not documented as a layer |
| Backend API service | no repo source found | not applicable | not documented as a layer |
| REST/OpenAPI contract | no repo source found | not applicable | no `docs/API.md` or `docs/OPENAPI.md` |
| Database migrations | no repo source found | not applicable | not documented as a layer |
| Mobile/native app | no repo source found | not applicable | no mobile doc |
| Hardware/BLE/IoT firmware | no repo source found | not applicable | no hardware doc |

If a future change adds a new layer, add its source-of-truth paths here and create a focused doc only when the layer actually exists.
