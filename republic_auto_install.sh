#!/bin/bash

# Republic AI Validator Node - Automated Installation Script
# Maintained by HusoNode
# Website: https://husonode.xyz
# Twitter: https://x.com/husonode

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
    echo -e "${BLUE}"
    echo "═══════════════════════════════════════════════════════════"
    echo "  Republic AI Validator Node - Automated Installation"
    echo "  Maintained by HusoNode"
    echo "  Website: https://husonode.xyz"
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then 
        print_error "Please do not run this script as root"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    print_message "Checking system requirements..."
    
    # Check Ubuntu version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            print_warning "This script is designed for Ubuntu. Your OS: $ID"
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    # Check available disk space (at least 100GB free)
    available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 100 ]; then
        print_warning "Low disk space detected: ${available_space}GB available"
        print_warning "Recommended: 500GB+ for validator node"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Update system
update_system() {
    print_message "Updating system packages..."
    sudo apt update -y && sudo apt upgrade -y
}

# Install dependencies
install_dependencies() {
    print_message "Installing required dependencies..."
    sudo apt install -y htop ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev \
        libnss3-dev tmux iptables curl nvme-cli git wget make jq libleveldb-dev \
        build-essential pkg-config ncdu tar clang bsdmainutils lsb-release \
        libssl-dev libreadline-dev libffi-dev gcc screen file nano btop unzip lz4
}

# Install Go
install_go() {
    print_message "Installing Go 1.22.3..."
    
    if command -v go &> /dev/null; then
        current_version=$(go version | awk '{print $3}' | sed 's/go//')
        if [[ "$current_version" == "1.22.3" ]]; then
            print_message "Go 1.22.3 is already installed"
            return
        else
            print_message "Updating Go from $current_version to 1.22.3..."
        fi
    fi
    
    cd $HOME
    wget -q https://go.dev/dl/go1.22.3.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.22.3.linux-amd64.tar.gz
    rm go1.22.3.linux-amd64.tar.gz
    
    # Add to bash profile if not already present
    if ! grep -q "/usr/local/go/bin" "$HOME/.bash_profile"; then
        echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> $HOME/.bash_profile
    fi
    
    source $HOME/.bash_profile
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    
    print_message "Go version: $(go version)"
}

# Install Cosmovisor
install_cosmovisor() {
    print_message "Installing Cosmovisor..."
    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest
}

# Configure environment variables
configure_env() {
    print_message "Configuring environment variables..."
    
    # Check if already configured
    if ! grep -q "REPUBLIC_WALLET" "$HOME/.bash_profile"; then
        echo "export REPUBLIC_WALLET='wallet'" >> $HOME/.bash_profile
    fi
    
    if ! grep -q "REPUBLIC_PORT" "$HOME/.bash_profile"; then
        echo "export REPUBLIC_PORT='51'" >> $HOME/.bash_profile
    fi
    
    source $HOME/.bash_profile
    export REPUBLIC_WALLET='wallet'
    export REPUBLIC_PORT='51'
}

# Download and install binary
install_binary() {
    print_message "Downloading Republic AI binary..."
    
    VERSION="v0.3.0"
    mkdir -p $HOME/.republicd/cosmovisor/genesis/bin
    
    cd $HOME
    curl -L "https://media.githubusercontent.com/media/RepublicAI/networks/main/testnet/releases/${VERSION}/republicd-linux-amd64" -o republicd
    chmod +x republicd
    
    mv republicd $HOME/.republicd/cosmovisor/genesis/bin/
    ln -sf $HOME/.republicd/cosmovisor/genesis $HOME/.republicd/cosmovisor/current
    sudo ln -sf $HOME/.republicd/cosmovisor/genesis/bin/republicd /usr/local/bin/republicd
    
    print_message "Binary version: $(republicd version)"
}

# Initialize node
initialize_node() {
    print_message "Initializing node..."
    
    read -p "Enter your validator name (English characters only): " NODE_NAME
    
    if [ -z "$NODE_NAME" ]; then
        print_error "Node name cannot be empty"
        exit 1
    fi
    
    republicd init "$NODE_NAME" --chain-id raitestnet_77701-1 --home $HOME/.republicd
}

# Download genesis
download_genesis() {
    print_message "Downloading genesis file..."
    curl -s https://raw.githubusercontent.com/RepublicAI/networks/main/testnet/genesis.json > $HOME/.republicd/config/genesis.json
}

# Configure ports
configure_ports() {
    print_message "Configuring network ports (using port prefix: $REPUBLIC_PORT)..."
    
    # Config.toml
    sed -i.bak -e "s%:26658%:${REPUBLIC_PORT}658%g;
s%:26657%:${REPUBLIC_PORT}657%g;
s%:6060%:${REPUBLIC_PORT}060%g;
s%:26656%:${REPUBLIC_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${REPUBLIC_PORT}656\"%;
s%:26660%:${REPUBLIC_PORT}660%g" $HOME/.republicd/config/config.toml
    
    # App.toml
    sed -i.bak -e "s%:1317%:${REPUBLIC_PORT}317%g;
s%:8080%:${REPUBLIC_PORT}080%g;
s%:9090%:${REPUBLIC_PORT}090%g;
s%:9091%:${REPUBLIC_PORT}091%g;
s%:8545%:${REPUBLIC_PORT}545%g;
s%:8546%:${REPUBLIC_PORT}546%g;
s%:6065%:${REPUBLIC_PORT}065%g" $HOME/.republicd/config/app.toml
}

# Configure peers and seeds
configure_peers() {
    print_message "Configuring peers and seeds..."
    
    SEEDS=""
    PEERS="cfb2cb90a241f7e1c076a43954f0ee6d42794d04@172.31.26.240:26656,1b0eac045d525cf18ce9df5e58b59f422e1ac147@172.31.22.66:26656,dc254b98cebd6383ed8cf2e766557e3d240100a9@172.31.28.158:26656,5909d46879ef1a352cfee63a93552432dd4bbeb7@172.31.21.191:26656,cc13360aec4a5ef532fce577f70bbc8fd665c211@65.108.110.246:26656,20a9721219f5056eacf89c19fd60c1999b398ea3@65.21.88.99:18656,08de17e0a650192861a6dd2ef63bbaca73f73592@34.55.100.110:26656,a5b245a4734167c9377ce3f7828947240cc7fd60@154.12.117.35:23656,a5d2fe7d932c3b6f7c9633164f102315d1f575c6@195.201.160.23:13356,bd892704441b02388b0527a0d15e40fee89b05b9@159.195.26.108:18656,f4435ef54602a368802f662a5a6a2b7b923f7071@103.171.146.57:26656,1999732342c6c89de4112f82008766bf3342aba2@104.152.210.127:55856,525ad7484153172c199433ed8ac7af26c2b228bc@14.169.16.64:26656,a698525f90433d6069a2fcc22b2b3f1cc13593cc@192.99.54.87:26656,194d200f41374b508bd79c062b29c75937c37103@38.49.209.147:26656,9ab906725d5a7f6eb513b4f0cbbe7ca357ebceea@213.109.161.44:26656,6ab1b623e0c1a0f2d3099cc502d9f3b4f9bc8a73@95.216.102.220:13356,d97efec4de6bcfa2c81052c0e7ebeff2a37655ea@34.51.40.253:26656,2c9641378e9dacc49b269b0efb807b475d033e56@89.167.15.180:26656,6dd3a10b5157d2ac68bd76922de849244ea1f4fa@65.109.55.116:34656,ec9cbd29992dea64e8adb26af1ebc5cc6a958875@34.44.164.13:26656,d1a6a7cfbd80805d486e12560ba3af6d868f108a@72.61.158.34:26656,65cf55232924bebfdd02c32446df5a101188a05e@161.97.95.86:26656,e2e2e02d42860e421294485740b48baf9e3e0b0b@179.43.150.242:26656,31e30d2dd6d10933c5a7281f7dffeb09d93fdf12@154.12.116.93:26656,f6d854d1b5d3cc3cc73fb46fbfe53e0df1c05d02@154.12.118.215:26656,cc2504dd639c01038444b309f4549139a43b77d3@206.168.81.49:26656,f990e33b674c0e91dc74e1067785bfe493985a34@182.9.2.84:26656,233fde2cfd5d8f87c15a2bf6ac0b19697e53897e@107.222.215.224:26656,b9f252664aad3370c4e186409c1fda71505a43b7@152.53.251.43:13356,d42950d61ff958d9f3a12549ef7a535b10357ce4@38.49.212.156:26656,c5f9653155d9095901c8044dc01fadf49212f350@45.143.198.6:26656,93d1e37cf97435491aaca98e04e18d2f6df99192@103.138.70.189:26656,d5401bc2fe46760e06f5c3af62b57463d83f90ad@89.167.26.162:26656,d5f910e658965da487e5537eac6a382f807e6a03@154.12.118.123:26756,9a8f0730cf929ea6655ca970c0a8ba81c19fb753@154.12.116.115:26656,5b4af65c46e97cf8ee991f07dca1f02d55cb2256@82.112.237.186:26656,6936fb0987f24160fcf0d6df2715dc578aae4c09@157.90.1.91:43656,c17a8d3bd27bce5ad90c3215e52671461697c19e@38.49.212.121:26656,d8798195b453a24b7d31b8075ac46de93267e6ea@2.50.222.30:26656,462fd3cf9880438ac732f221bc271b22a0ce7132@172.104.155.28:26656,2a939e0322783f1b85a16cf768091c79430457f1@138.197.115.112:26656,e5d2fd28460427dcb15efcd3b27843593cbedcc1@114.29.239.131:26656,b97f371120741a76abc21baea936659f9204f8b1@146.19.24.206:43656,7971d6669264775653766efcbcb87f8e9664faa6@192.151.150.34:13356,ea12408721fd0ed1865021add1f4789988783643@2.56.97.139:13356,007ee0fafbad23ec7e132a708281bdbdb7d89350@69.62.113.85:26656,033c76d723335e2a157236f75aefe98a83973f77@38.49.213.142:43656,0729cae89fbdb4e2065423a768f3a4e1b42ab3a7@38.49.214.35:43656,4e14a1edc972ed3f4c03eae8434cb3997b342029@46.224.213.11:43656"
    
    sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.republicd/config/config.toml
}

# Configure pruning
configure_pruning() {
    print_message "Configuring pruning settings..."
    
    sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.republicd/config/app.toml
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.republicd/config/app.toml
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.republicd/config/app.toml
}

# Disable indexer
disable_indexer() {
    print_message "Disabling indexer (saves resources)..."
    sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.republicd/config/config.toml
}

# Configure gas prices
configure_gas() {
    print_message "Configuring minimum gas prices..."
    sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "250000000arai"|g' $HOME/.republicd/config/app.toml
}

# Create systemd service
create_service() {
    print_message "Creating systemd service..."
    
    sudo tee /etc/systemd/system/republicd.service > /dev/null <<EOF
[Unit]
Description=Republic AI Node
After=network-online.target

[Service]
User=$USER
Environment="DAEMON_NAME=republicd"
Environment="DAEMON_HOME=$HOME/.republicd"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=true"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
ExecStart=$HOME/go/bin/cosmovisor run start --home $HOME/.republicd --chain-id raitestnet_77701-1
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
}

# Start node
start_node() {
    print_message "Starting Republic AI node..."
    
    sudo systemctl daemon-reload
    sudo systemctl enable republicd
    sudo systemctl start republicd
    
    sleep 3
    
    if sudo systemctl is-active --quiet republicd; then
        print_message "Node started successfully!"
    else
        print_error "Failed to start node. Check logs with: journalctl -u republicd -f"
        exit 1
    fi
}

# Print final instructions
print_final_instructions() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo ""
    echo "1. Check node logs:"
    echo -e "   ${BLUE}journalctl -u republicd -f${NC}"
    echo ""
    echo "2. Check sync status:"
    echo -e "   ${BLUE}republicd status --node tcp://localhost:51657 | jq '.sync_info'${NC}"
    echo ""
    echo "3. Wait for your node to sync with the network"
    echo "   - Monitor logs until block height matches explorer"
    echo "   - Explorer: https://explorer.republicai.io/blocks"
    echo ""
    echo "4. Create wallet (after sync):"
    echo -e "   ${BLUE}republicd keys add wallet${NC}"
    echo ""
    echo "5. Request testnet tokens from Discord faucet"
    echo ""
    echo "6. Create validator (after receiving tokens):"
    echo "   - Follow the validator creation guide in README.md"
    echo ""
    echo -e "${YELLOW}Important Files to Backup:${NC}"
    echo "   - Wallet mnemonic phrase (save securely!)"
    echo "   - $HOME/.republicd/config/priv_validator_key.json"
    echo "   - $HOME/.republicd/config/node_key.json"
    echo "   - $HOME/.republicd/data/priv_validator_state.json"
    echo ""
    echo -e "${GREEN}For more information:${NC}"
    echo "   - Website: https://husonode.xyz"
    echo "   - Twitter: https://x.com/husonode"
    echo "   - Full Guide: README.md"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
}

# Main installation function
main() {
    print_header
    
    check_root
    check_requirements
    
    print_message "Starting automated installation..."
    echo ""
    
    update_system
    install_dependencies
    install_go
    install_cosmovisor
    configure_env
    install_binary
    initialize_node
    download_genesis
    configure_ports
    configure_peers
    configure_pruning
    disable_indexer
    configure_gas
    create_service
    start_node
    
    print_final_instructions
}

# Run main function
main
