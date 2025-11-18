# Skyhook CLI

Command-line tool for managing Kubernetes services with Skyhook.

## Installation

### macOS (Homebrew)

```bash
brew tap skyhook-io/skyhook-cli
brew install skyhook-io/skyhook-cli/skyhook
```

### Linux/macOS (Direct Download)

Download the latest release from the [releases page](https://github.com/skyhook-io/skyhook-cli/releases).

```bash
# Example for macOS ARM64
curl -L https://github.com/skyhook-io/skyhook-cli/releases/latest/download/skyhook_cli_Darwin_arm64 -o skyhook
chmod +x skyhook
sudo mv skyhook /usr/local/bin/
```

### Windows

Download the Windows binary from the [releases page](https://github.com/skyhook-io/skyhook-cli/releases).

## Usage

```bash
# View available commands
skyhook --help

# Create a new service
skyhook create

# Update API from OpenAPI spec
skyhook update api

# Update CI/CD workflows
skyhook update cicd

# List clusters
skyhook cluster list

# Register a new cluster
skyhook cluster register <cluster-name> --location <region> --project <project-id>
```

## Configuration

The CLI stores configuration in `~/.skyhook/conf.yaml`.

Set default organization:
```bash
skyhook config set org <org-id>
```

## Development

This repository contains releases only. The CLI is built from the main [backend repository](https://github.com/koalaops/koala-backend).

## License

Copyright © 2025 Skyhook
