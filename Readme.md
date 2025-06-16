# Polygon PoS Local Development Environment

This repository contains a local development environment for Polygon PoS (Proof of Stake) using Kurtosis and Blockscout (at `localhost:80`).

## Prerequisites

- Docker
- Just (command runner)
- Kurtosis CLI
- yq (YAML processor)
- jq (JSON processor)

## Installation

1. Install Just:

```bash
brew install just
```

2. Install Kurtosis:

```bash
curl -fsSL https://raw.githubusercontent.com/kurtosis-tech/kurtosis/main/install.sh | bash
```

3. Install yq and jq:

```bash
brew install python-yq jq
```

## Usage

### Start the Environment

To start the complete environment with default settings (2 validators) and blockscout connected to local bor:

```bash
just start
```

To start with a specific number of validators:

```bash
just start 3 true  # Starts with 3 validators and blockscout connected to kurtosis bor-el-rpc
```

### Individual Commands

- `just kurtosis [count]` - Run Kurtosis Polygon PoS with optional validator count
- `just blockscout [with_kurtosis]` - Run Blockscout (optionally connected to Kurtosis)
- `just bor` - Run Bor node alongside Kurtosis enclave
- `just clean` - Clean generated data
- `just clean-docker` - Clean generated containers
