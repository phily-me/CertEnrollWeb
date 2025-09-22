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
          name = "dev";
          
          motd = ''
            🔧 Dev Environment
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            Available linting tools:
            ✅ shellcheck, hadolint, markdownlint
            ✅ eslint, prettier, typescript
            ✅ ruff, black, mypy
            ✅ go fmt, go vet

            🚀 Quick commands:
              lint            # Check code (dry-run, no changes)
              lint-fix        # Check and fix issues automatically
              setup-hooks     # Install pre-commit hooks

            💡 The lint script auto-detects project type and runs
               appropriate tools. Use 'lint --help' for all options.

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

            # JavaScript/TypeScript ecosystem
            nodejs            # Node.js runtime
            nodePackages.eslint  # JavaScript linter
            nodePackages.prettier  # Code formatter
            nodePackages.typescript  # TypeScript compiler

            # Python ecosystem
            python3
            ruff             # Fast Python linter/formatter
            black            # Python code formatter
            mypy             # Python type checker

            # Go tools (lightweight, includes gofmt/go vet)
            go
          ];
          
          commands = [
            {
              name = "lint";
              help = "Run linters in dry-run mode (check only, no modifications)";
              command = ''
                ./lint --check-only "$@"
              '';
            }
            {
              name = "lint-fix";
              help = "Run linters and auto-fix issues where possible";
              command = ''
                ./lint --fix "$@"
              '';
            }
            {
              name = "setup-hooks";
              help = "Set up pre-commit hooks for automatic linting";
              command = ''
                ./setup-hooks "$@"
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
