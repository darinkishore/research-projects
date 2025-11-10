# MCP Agent Mail Nix Flake

A Nix flake packaging of [mcp_agent_mail](https://github.com/Dicklesworthstone/mcp_agent_mail) using uv2nix and flake-parts.

## Overview

This project packages MCP Agent Mail as a Nix flake, providing:
- Reproducible builds using Nix
- Dependency management via uv2nix
- Development and production environments
- Easy deployment on NixOS or any system with Nix

## What is MCP Agent Mail?

MCP Agent Mail is a mail-like coordination layer for coding agents, exposed as an HTTP-only FastMCP server. It provides:
- Memorable agent identities
- Inbox/outbox for async messaging
- Searchable message history
- File reservation system to prevent conflicts
- Git-backed artifact storage
- SQLite-based indexing

## Project Structure

```
mcp-agent-mail-nix-flake/
├── flake.nix           # Nix flake configuration with flake-parts
├── pyproject.toml      # Python project metadata
├── uv.lock            # Locked dependencies from uv
├── src/               # Source code
├── notes.md           # Development notes
└── README.md          # This file
```

## Prerequisites

- Nix with flakes enabled (2.4 or later)
- Git

### Installing Nix

If you don't have Nix installed, use the Determinate Systems installer:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

This automatically enables flakes and provides a better installation experience.

## Flake Architecture

### Inputs

The flake uses the following inputs:

- **nixpkgs**: Unstable channel for latest packages
- **flake-parts**: Modular flake framework
- **pyproject-nix**: Python project integration for Nix
- **uv2nix**: Converts uv.lock to Nix derivations
- **pyproject-build-systems**: Common Python build systems

### Outputs

The flake provides:

#### Packages

- `default`: Main MCP Agent Mail package with CLI and server wrappers
- `virtualenv`: Just the Python virtual environment

#### Apps

- `default` / `server`: Run the MCP server
- `cli`: Access the CLI directly

#### Development Shell

A development environment with:
- Python 3.14
- uv package manager
- Editable package installations
- Pre-configured environment variables

## Usage

### Running the Server

The easiest way to run the MCP Agent Mail server on localhost:

```bash
# Run with default settings (port 8765)
nix run

# Or specify a custom port
nix run . -- --port 9000
```

### Using the CLI

Access the CLI tools:

```bash
nix run .#cli -- --help
```

### Building the Package

Build the package to the Nix store:

```bash
nix build
```

The result will be in `./result/` with:
- `bin/mcp-agent-mail`: CLI wrapper
- `bin/mcp-agent-mail-server`: Server wrapper

### Development Environment

Enter a development shell with all dependencies:

```bash
nix develop
```

Inside the shell:

```bash
# Run the server
uv run python -m mcp_agent_mail.cli server start --port 8765

# Run tests
uv run pytest

# Run the CLI
uv run python -m mcp_agent_mail.cli --help
```

## Integration with uv2nix

This flake leverages uv2nix for Python dependency management:

1. **Workspace Loading**: Discovers and loads all Python projects
2. **Lock File Conversion**: Converts `uv.lock` to Nix derivations
3. **Virtual Environment**: Creates isolated Python environments
4. **Editable Packages**: Supports development with editable installations

### Key Features

- **Wheel Preference**: Uses binary wheels for faster builds
- **Build Systems**: Includes common build systems (hatchling, setuptools, etc.)
- **Dependency Groups**: Supports optional and development dependencies
- **Source Filtering**: Reduces rebuild triggers with smart filtering

## Flake-Parts Structure

The flake uses flake-parts for modularity:

```nix
perSystem = { config, self', inputs', pkgs, lib, system, ... }: {
  packages = { ... };
  apps = { ... };
  devShells = { ... };
}
```

Benefits:
- Multi-system support (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin)
- Cleaner configuration
- Easier to extend and maintain

## Python 3.14 Requirement

MCP Agent Mail requires Python 3.14. The flake handles this by:

1. Using `pkgs.python314` explicitly
2. Configuring uv2nix with the correct Python version
3. Setting `UV_PYTHON` in the development shell

## Configuration

### Environment Variables

The MCP server can be configured via environment variables:

- `MCP_PORT`: Server port (default: 8765)
- `MCP_TOKEN`: Authentication token
- `PROJECT_DIR`: Project directory for Git operations

### Nix Configuration

Key configuration in `flake.nix`:

```nix
python = pkgs.python314;  # Python version

workspace = inputs.uv2nix.lib.workspace.loadWorkspace {
  workspaceRoot = ./.;
};

overlay = workspace.mkPyprojectOverlay {
  sourcePreference = "wheel";  # Prefer binary wheels
};
```

## Troubleshooting

### Flakes Not Enabled

If you get "experimental feature 'flakes' not enabled":

```bash
# Enable flakes in your Nix configuration
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Python Version Issues

The flake requires Python 3.14. If you encounter issues:

```bash
# Check available Python version
nix eval .#python.version
```

### Build Failures

If builds fail:

1. Clear the flake cache: `rm -rf ~/.cache/nix`
2. Update inputs: `nix flake update`
3. Check build logs: `nix build --print-build-logs`

## Development Workflow

### Making Changes

1. Enter development shell: `nix develop`
2. Make changes to source code
3. Test changes: `uv run pytest`
4. Run locally: `uv run python -m mcp_agent_mail.cli server start`

### Updating Dependencies

When updating Python dependencies:

1. Update `pyproject.toml`
2. Run `uv lock` to update `uv.lock`
3. Rebuild: `nix build`

### Testing the Flake

```bash
# Check flake structure
nix flake show

# Check flake metadata
nix flake metadata

# Build all outputs
nix build .#default
nix build .#virtualenv
```

## Deployment

### NixOS

Add to your NixOS configuration:

```nix
{
  inputs.mcp-agent-mail.url = "github:yourusername/mcp-agent-mail-nix-flake";

  outputs = { self, nixpkgs, mcp-agent-mail }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        {
          environment.systemPackages = [
            mcp-agent-mail.packages.x86_64-linux.default
          ];

          # Optional: Add as a service
          systemd.services.mcp-agent-mail = {
            description = "MCP Agent Mail Server";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${mcp-agent-mail.packages.x86_64-linux.default}/bin/mcp-agent-mail-server";
              Restart = "always";
            };
          };
        }
      ];
    };
  };
}
```

### Docker

Build a Docker image:

```bash
nix build .#dockerImage
docker load < result
docker run -p 8765:8765 mcp-agent-mail:latest
```

(Note: Docker image output would need to be added to flake.nix)

## Technical Details

### Why uv2nix?

uv2nix provides several advantages:

1. **Lock File Based**: Uses uv.lock for reproducibility
2. **Fast Builds**: Prefers binary wheels
3. **No Python at Build Time**: Doesn't need Python to parse dependencies
4. **Full Ecosystem Support**: Handles complex dependency graphs

### Build Process

1. Load workspace from `pyproject.toml`
2. Parse `uv.lock` to extract dependencies
3. Create Nix overlay with Python packages
4. Build virtual environment with dependencies
5. Create wrapper scripts for CLI/server

### Directory Layout

```
result/
├── bin/
│   ├── mcp-agent-mail           # CLI wrapper
│   └── mcp-agent-mail-server    # Server wrapper
└── lib/
    └── venv/                     # Python virtual environment
```

## Resources

- [MCP Agent Mail Repository](https://github.com/Dicklesworthstone/mcp_agent_mail)
- [uv2nix Documentation](https://github.com/pyproject-nix/uv2nix)
- [flake-parts Documentation](https://flake.parts)
- [pyproject-nix Documentation](https://github.com/pyproject-nix/pyproject.nix)
- [Nix Flakes Guide](https://nixos.wiki/wiki/Flakes)

## License

This packaging follows the original project's MIT license.

## Contributing

Contributions are welcome! Please ensure:

1. Flake checks pass: `nix flake check`
2. Builds succeed: `nix build`
3. Tests pass: `nix develop -c pytest`

## Acknowledgments

- Original MCP Agent Mail by [Dicklesworthstone](https://github.com/Dicklesworthstone)
- uv2nix by the pyproject-nix team
- flake-parts by Hercules CI
