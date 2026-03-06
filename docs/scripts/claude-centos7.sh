  #!/bin/bash
  # Install Claude Code on CentOS 7
  # Run as normal user (not root)
  #
  # Why Nix? CentOS 7 ships glibc 2.17 and no Node.js 20 packages.
  # Nix provides a modern Node.js without breaking the system.

  set -euo pipefail

  echo "=== Claude Code installer for CentOS 7 ==="

  # 1. Install Nix (single-user mode)
  echo "[1/5] Installing Nix..."
  if ! command -v nix-env &>/dev/null; then
      curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
      source ~/.nix-profile/etc/profile.d/nix.sh
  else
      echo "       Nix already installed, skipping."
      source ~/.nix-profile/etc/profile.d/nix.sh
  fi

  # 2. Install Node.js 20 via Nix
  echo "[2/5] Installing Node.js 20..."
  if ! command -v node &>/dev/null || [[ "$(node -v)" != v20* ]]; then
      nix-env -iA nixpkgs.nodejs_20
  else
      echo "       Node.js $(node -v) already installed, skipping."
  fi

  # 3. Configure npm global prefix (no root needed)
  echo "[3/5] Configuring npm..."
  mkdir -p ~/.npm-global
  npm config set prefix '~/.npm-global'
  export PATH="$HOME/.npm-global/bin:$PATH"

  # 4. Install Claude Code
  echo "[4/5] Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code

  # 5. Persist environment in .bashrc
  echo "[5/5] Updating .bashrc..."
  if ! grep -q "nix.sh" ~/.bashrc 2>/dev/null; then
      cat >> ~/.bashrc << 'EOF'

  # Nix
  if [ -f ~/.nix-profile/etc/profile.d/nix.sh ]; then
      source ~/.nix-profile/etc/profile.d/nix.sh
  fi

  # npm global
  export PATH="$HOME/.npm-global/bin:$PATH"
  EOF
      echo "       .bashrc updated."
  else
      echo "       .bashrc already configured, skipping."
  fi

  echo ""
  echo "=== Installation complete ==="
  echo "Claude Code version: $(claude --version 2>/dev/null || echo 'run source ~/.bashrc first')"
  echo ""
  echo "Next: source ~/.bashrc && claude"
