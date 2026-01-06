#!/usr/bin/env bash
# MBO Server Configs - VS Code Remote SSH Setup
#
# Sets up SSH config and key-based authentication for VS Code Remote - SSH
#
# Usage:
#   ./setup-vscode-remote.sh
#
# After running:
#   1. Install "Remote - SSH" extension in VS Code
#   2. Press Ctrl+Shift+P -> "Remote-SSH: Connect to Host" -> Select "rbo-w2"

set -e

# config
HOST_ALIAS="rbo-w2"
HOSTNAME="129.85.3.34"
USERNAME="RBO"
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
SSH_KEY="$SSH_DIR/id_ed25519_rbo"

# colors
info() { echo -e "\033[34m[INFO]\033[0m $*"; }
ok() { echo -e "\033[32m[OK]\033[0m $*"; }
warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
err() { echo -e "\033[31m[ERROR]\033[0m $*"; }

setup_ssh_dir() {
    if [[ ! -d "$SSH_DIR" ]]; then
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        ok "Created $SSH_DIR"
    fi
}

generate_ssh_key() {
    if [[ -f "$SSH_KEY" ]]; then
        ok "SSH key already exists: $SSH_KEY"
        return
    fi

    info "Generating SSH key..."
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "vscode-remote-rbo"
    ok "Generated SSH key: $SSH_KEY"
}

copy_key_to_server() {
    info "Copying SSH key to server..."
    echo ""
    echo "  You'll be prompted for the password for $USERNAME@$HOSTNAME"
    echo ""

    if ssh-copy-id -i "$SSH_KEY.pub" "$USERNAME@$HOSTNAME"; then
        ok "SSH key copied to server"
    else
        warn "Failed to copy SSH key. You may need to do this manually:"
        echo "  ssh-copy-id -i $SSH_KEY.pub $USERNAME@$HOSTNAME"
    fi
}

setup_ssh_config() {
    info "Configuring SSH..."

    # create config if it doesn't exist
    if [[ ! -f "$SSH_CONFIG" ]]; then
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
    fi

    # check if host already configured
    if grep -q "^Host $HOST_ALIAS" "$SSH_CONFIG" 2>/dev/null; then
        ok "SSH config already has $HOST_ALIAS entry"
        return
    fi

    # add config entry
    cat >> "$SSH_CONFIG" <<EOF

# MBO RBO-W2 Server (VS Code Remote)
Host $HOST_ALIAS
    HostName $HOSTNAME
    User $USERNAME
    IdentityFile $SSH_KEY
    IdentitiesOnly yes
    # Keepalive to prevent disconnects
    ServerAliveInterval 60
    ServerAliveCountMax 3
    # Connection multiplexing for faster reconnects
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600

EOF

    # create sockets directory for connection multiplexing
    mkdir -p "$SSH_DIR/sockets"

    ok "Added $HOST_ALIAS to SSH config"
}

test_connection() {
    info "Testing SSH connection..."

    if ssh -o BatchMode=yes -o ConnectTimeout=10 "$HOST_ALIAS" "echo 'Connection successful'" 2>/dev/null; then
        ok "SSH connection working (passwordless)"
    else
        warn "Passwordless SSH not working yet. Try running:"
        echo "  ssh-copy-id -i $SSH_KEY.pub $USERNAME@$HOSTNAME"
        echo ""
        echo "Then test with:"
        echo "  ssh $HOST_ALIAS"
    fi
}

show_next_steps() {
    echo ""
    echo "  =================================="
    echo "  Setup Complete!"
    echo "  =================================="
    echo ""
    echo "  Next steps:"
    echo ""
    echo "  1. Install VS Code extension:"
    echo "     - Open VS Code"
    echo "     - Install 'Remote - SSH' extension (ms-vscode-remote.remote-ssh)"
    echo ""
    echo "  2. Connect to server:"
    echo "     - Press Ctrl+Shift+P (or Cmd+Shift+P on Mac)"
    echo "     - Type: Remote-SSH: Connect to Host"
    echo "     - Select: $HOST_ALIAS"
    echo ""
    echo "  Or from command line:"
    echo "     ssh $HOST_ALIAS"
    echo ""
    echo "  To open a folder directly:"
    echo "     code --remote ssh-remote+$HOST_ALIAS /path/to/folder"
    echo ""
}

main() {
    echo ""
    echo "  VS Code Remote SSH Setup"
    echo "  ========================"
    echo "  Server: $USERNAME@$HOSTNAME ($HOST_ALIAS)"
    echo ""

    setup_ssh_dir
    generate_ssh_key
    setup_ssh_config
    copy_key_to_server
    test_connection
    show_next_steps
}

main
