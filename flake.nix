{
  description = "Certificate Server Web - Development environment with comprehensive linting tools";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devshell.url = "github:numtide/devshell";
  };

  outputs = inputs@{ flake-parts, devshell, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devshell.flakeModule
      ];
      
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        devshells.default = {
          name = "certsrvweb-lint-env";
          
          motd = ''
            🔧 Certificate Server Web - Linting Environment
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            
            Essential linting tools for this project:
            ✅ shellcheck (shell scripts)    ✅ hadolint (Docker files)
            ✅ markdownlint (markdown)       ✅ ruff + black (Python)
            ✅ go fmt + go vet (Go)
            
            🚀 Quick start:
              ./lint           # Check all files
              ./lint --fix     # Fix issues automatically  
              ./lint --help    # See all options
            
            📦 Need more tools? Add to flake.nix packages:
              nodejs, nodePackages.{eslint,prettier,typescript}
              mypy, python3Packages.flake8, cargo, rustc, ruby, etc.
              
          '';
          
          packages = with pkgs; [
            # Core tools
            bash
            git
            curl
            
            # Essential linting tools (fast to build/download)
            shellcheck        # Shell script linting
            hadolint         # Docker linting  
            nodePackages.markdownlint-cli  # Markdown linting
            
            # Python ecosystem (essential tools)
            python3
            ruff             # Fast Python linter/formatter
            black            # Python code formatter
            
            # Go tools (lightweight, includes gofmt/go vet)
            go
          ];
          
          commands = [
            {
              name = "lint";
              help = "Run comprehensive code linting across all supported languages";
              command = "./lint $@";
            }
            {
              name = "lint-fix";
              help = "Auto-fix linting issues where possible";
              command = "./lint --fix";
            }
            {
              name = "lint-strict";
              help = "Run linting with strict rules (warnings as errors)";
              command = "./lint --strict";
            }
            {
              name = "lint-staged";
              help = "Lint only staged files (useful for pre-commit hooks)";
              command = "./lint --staged";
            }
            {
              name = "setup-hooks";
              help = "Set up pre-commit hooks for automatic linting";
              command = ''
                echo "Setting up pre-commit hooks..."
                mkdir -p .git/hooks
                cat > .git/hooks/pre-commit << 'EOF'
            #!/bin/sh
            ./lint --staged --check-only
            EOF
                chmod +x .git/hooks/pre-commit
                echo "✅ Pre-commit hook installed!"
              '';
            }
          ];
          
          env = [
            {
              name = "LINT_ENV";
              value = "development";
            }
          ];
        };
      };
    };
}
