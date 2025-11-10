{
  description = "MCP Agent Mail - A flake for coordinated multi-agent messaging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { config, self', inputs', pkgs, lib, system, ... }:
        let
          python = pkgs.python314;

          # Load the workspace
          workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

          # Create overlay from uv.lock
          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";  # Prefer binary wheels
          };

          # Construct Python base set
          pythonBase = pkgs.callPackage inputs.pyproject-nix.build.packages {
            inherit python;
          };

          # Compose the final Python set with build systems and dependencies
          pythonSet = pythonBase.overrideScope (
            lib.composeManyExtensions [
              inputs.pyproject-build-systems.overlays.wheel
              overlay
            ]
          );

          # Create virtual environment
          virtualenv = pythonSet.mkVirtualEnv "mcp-agent-mail-env" workspace.deps.default;

          # Create editable overlay for development
          editableOverlay = workspace.mkEditablePyprojectOverlay {
            root = "$REPO_ROOT";
            members = [ "mcp-agent-mail" ];
          };

          # Create editable Python set for development
          editablePythonSet = pythonSet.overrideScope editableOverlay;

          # Create development virtual environment
          devVirtualenv = editablePythonSet.mkVirtualEnv "mcp-agent-mail-dev-env" workspace.deps.all;

        in {
          packages = {
            default = pkgs.stdenv.mkDerivation {
              name = "mcp-agent-mail";
              version = "0.1.0";

              src = lib.cleanSource ./.;

              buildInputs = [ virtualenv ];

              installPhase = ''
                mkdir -p $out/bin
                mkdir -p $out/lib

                # Copy the virtual environment
                cp -r ${virtualenv} $out/lib/venv

                # Create wrapper script for the CLI
                cat > $out/bin/mcp-agent-mail << EOF
#!/bin/sh
export PYTHONPATH="${virtualenv}/${python.sitePackages}"
exec ${virtualenv}/bin/python -m mcp_agent_mail.cli "\$@"
EOF
                chmod +x $out/bin/mcp-agent-mail

                # Create wrapper script to run the server
                cat > $out/bin/mcp-agent-mail-server << EOF
#!/bin/sh
export PYTHONPATH="${virtualenv}/${python.sitePackages}"
exec ${virtualenv}/bin/python -m mcp_agent_mail.cli server start "\$@"
EOF
                chmod +x $out/bin/mcp-agent-mail-server
              '';

              meta = with lib; {
                description = "Coordinated multi-agent messaging and coordination MCP server";
                homepage = "https://github.com/Dicklesworthstone/mcp_agent_mail";
                license = licenses.mit;
                platforms = platforms.unix;
              };
            };

            # Convenience package that just provides the virtualenv
            virtualenv = virtualenv;
          };

          apps = {
            default = {
              type = "app";
              program = "${self'.packages.default}/bin/mcp-agent-mail-server";
            };

            cli = {
              type = "app";
              program = "${self'.packages.default}/bin/mcp-agent-mail";
            };

            server = {
              type = "app";
              program = "${self'.packages.default}/bin/mcp-agent-mail-server";
            };
          };

          devShells.default = pkgs.mkShell {
            packages = [
              devVirtualenv
              pkgs.uv
              python
            ];

            env = {
              UV_NO_SYNC = "1";
              UV_PYTHON = editablePythonSet.python.interpreter;
              UV_PYTHON_DOWNLOADS = "never";
            };

            shellHook = ''
              unset PYTHONPATH
              export REPO_ROOT=$(pwd)
              echo "MCP Agent Mail development environment"
              echo "Python: ${python.version}"
              echo ""
              echo "Available commands:"
              echo "  uv run python -m mcp_agent_mail.cli --help"
              echo "  uv run python -m mcp_agent_mail.cli server start --port 8765"
            '';
          };
        };
    };
}
