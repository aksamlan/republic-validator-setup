# Republic AI Node - Troubleshooting Guide

## Common Issues and Solutions

### Node Not Syncing

#### Check Peer Connections
```bash
# Check number of connected peers
curl -s http://localhost:51657/net_info | jq '.result.n_peers'
```

**Solution**: If you have 0-2 peers:
```bash
# Update peers from RPC
URL="https://rpc.republicai.io/net_info"
response=$(curl -s $URL)
PEERS=$(echo $response | jq -r '.result.peers[] | select(.remote_ip | test("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$")) | "\(.node_info.id)@\(.remote_ip):" + (.node_info.listen_addr | capture(":(?<port>[0-9]+)$").port)' | paste -sd "," -)
sed -i 's|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.republicd/config/config.toml
sudo systemctl restart republicd
```

#### Check Sync Status
```bash
republicd status --node tcp://localhost:51657 | jq '.sync_info'
```

Look for:
- `catching_up: true` - Still syncing
- `catching_up: false` - Fully synced
- `latest_block_height` - Should be increasing

---

### Service Not Starting

#### Check Service Status
```bash
sudo systemctl status republicd
```

#### Check Logs
```bash
journalctl -u republicd -f -n 100
```

**Common Error Solutions:**

**Error: "permission denied"**
```bash
# Fix permissions
sudo chown -R $USER:$USER $HOME/.republicd
sudo chmod -R 755 $HOME/.republicd
```

**Error: "address already in use"**
```bash
# Check if port is in use
sudo lsof -i :51656
# Kill the process or change your port in config
```

**Error: "failed to load genesis"**
```bash
# Re-download genesis
curl -s https://raw.githubusercontent.com/RepublicAI/networks/main/testnet/genesis.json > $HOME/.republicd/config/genesis.json
sudo systemctl restart republicd
```

---

### Disk Space Issues

#### Check Disk Usage
```bash
df -h
du -sh $HOME/.republicd/data
```

#### Solution: Enable Pruning
```bash
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.republicd/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.republicd/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.republicd/config/app.toml
sudo systemctl restart republicd
```

---

### Validator Jailed

#### Check Jail Status
```bash
republicd query staking validator $(republicd keys show wallet --bech val -a) --node tcp://localhost:51657
```

#### Unjail Validator
```bash
republicd tx slashing unjail \
--from wallet \
--chain-id raitestnet_77701-1 \
--gas auto \
--gas-adjustment 1.5 \
--gas-prices 1000000000arai \
--node tcp://localhost:51657 \
-y
```

**Common Jail Reasons:**
1. **Downtime**: Node was offline too long
2. **Double signing**: Running validator on multiple servers (NEVER DO THIS)
3. **Missing blocks**: Poor network connection

**Prevention:**
- Monitor your node regularly
- Set up alerts for downtime
- Ensure stable internet connection
- Never run the same validator key on multiple servers

---

### Transaction Failures

#### Insufficient Gas
**Error**: "out of gas"

**Solution**: Increase gas adjustment
```bash
# Add --gas-adjustment 1.5 to your commands
republicd tx ... --gas auto --gas-adjustment 1.5
```

#### Insufficient Funds
**Error**: "insufficient funds"

**Solution**: Check balance and request faucet
```bash
republicd query bank balances $(republicd keys show wallet -a) --node tcp://localhost:51657
```

#### Sequence Mismatch
**Error**: "account sequence mismatch"

**Solution**: Wait a few seconds and retry, or add `-s` flag
```bash
republicd tx ... -s $(republicd query account $(republicd keys show wallet -a) | jq -r .sequence)
```

---

### Port Conflicts

#### Check Port Usage
```bash
# Check if ports are in use
sudo netstat -tulpn | grep :51

# Check specific port
sudo lsof -i :51656
```

#### Change Port
If port 51 is occupied, choose a different port:

```bash
# Set new port (e.g., 52)
export REPUBLIC_PORT='52'
echo "export REPUBLIC_PORT='52'" >> $HOME/.bash_profile

# Reconfigure
sed -i.bak -e "s%:51658%:${REPUBLIC_PORT}658%g;
s%:51657%:${REPUBLIC_PORT}657%g;
s%:51060%:${REPUBLIC_PORT}060%g;
s%:51656%:${REPUBLIC_PORT}656%g;
s%:51660%:${REPUBLIC_PORT}660%g" $HOME/.republicd/config/config.toml

sed -i.bak -e "s%:51317%:${REPUBLIC_PORT}317%g;
s%:51080%:${REPUBLIC_PORT}080%g;
s%:51090%:${REPUBLIC_PORT}090%g;
s%:51091%:${REPUBLIC_PORT}091%g;
s%:51545%:${REPUBLIC_PORT}545%g;
s%:51546%:${REPUBLIC_PORT}546%g;
s%:51065%:${REPUBLIC_PORT}065%g" $HOME/.republicd/config/app.toml

sudo systemctl restart republicd
```

---

### Memory Issues

#### Check Memory Usage
```bash
free -h
htop
```

#### Solution: Add Swap Space
```bash
# Create 4GB swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

### Lost Wallet Access

#### Restore from Mnemonic
```bash
republicd keys add wallet --recover
# Enter your mnemonic phrase when prompted
```

#### List All Keys
```bash
republicd keys list
```

#### Export Private Key
```bash
republicd keys export wallet
# Enter keyring password when prompted
```

---

### Node Upgrade Issues

#### Check Version
```bash
republicd version
```

#### Manual Binary Update
```bash
cd $HOME
curl -L "https://media.githubusercontent.com/media/RepublicAI/networks/main/testnet/releases/NEW_VERSION/republicd-linux-amd64" -o republicd
chmod +x republicd
sudo systemctl stop republicd
sudo mv republicd $(which republicd)
sudo systemctl start republicd
```

---

### Network Issues

#### Test Connectivity
```bash
# Test RPC endpoint
curl http://localhost:51657/status

# Test public RPC
curl https://rpc.republicai.io/status
```

#### DNS Issues
```bash
# Use Google DNS
sudo nano /etc/resolv.conf
# Add: nameserver 8.8.8.8
```

---

### Complete Node Reset

⚠️ **WARNING**: This will delete all node data. Backup important files first!

```bash
# Stop service
sudo systemctl stop republicd

# Backup validator keys
cp $HOME/.republicd/config/priv_validator_key.json $HOME/priv_validator_key.json.backup
cp $HOME/.republicd/config/node_key.json $HOME/node_key.json.backup

# Remove old data
rm -rf $HOME/.republicd

# Re-run installation
wget -O republic_auto_install.sh https://raw.githubusercontent.com/husonode/republic-validator/main/republic_auto_install.sh && chmod +x republic_auto_install.sh && ./republic_auto_install.sh

# Restore validator keys
cp $HOME/priv_validator_key.json.backup $HOME/.republicd/config/priv_validator_key.json
cp $HOME/node_key.json.backup $HOME/.republicd/config/node_key.json

sudo systemctl restart republicd
```

---

### State Sync (Fast Sync)

Speed up syncing with state sync:

```bash
# Stop service
sudo systemctl stop republicd

# Get trust height and hash
SNAP_RPC="https://rpc.republicai.io:443"
LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height)
TRUST_HEIGHT=$((LATEST_HEIGHT - 2000))
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$TRUST_HEIGHT" | jq -r .result.block_id.hash)

# Configure state sync
sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$TRUST_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/.republicd/config/config.toml

# Reset data and restart
republicd tendermint unsafe-reset-all --home $HOME/.republicd
sudo systemctl restart republicd
```

---

## Monitoring Best Practices

### Setup Monitoring Script
```bash
cat > $HOME/check_node.sh << 'EOF'
#!/bin/bash
echo "=== Node Status ==="
republicd status --node tcp://localhost:51657 | jq '.sync_info'
echo ""
echo "=== Connected Peers ==="
curl -s http://localhost:51657/net_info | jq '.result.n_peers'
echo ""
echo "=== Service Status ==="
sudo systemctl status republicd --no-pager | head -n 5
EOF

chmod +x $HOME/check_node.sh
```

Run monitoring:
```bash
./check_node.sh
```

---

## Getting Help

If you're still experiencing issues:

1. **Check Logs**: `journalctl -u republicd -f -n 100`
2. **Discord Community**: Join Republic AI Discord
3. **HusoNode Support**: 
   - Website: https://husonode.xyz
   - Twitter: https://x.com/husonode
4. **Include in Support Request**:
   - Node version: `republicd version`
   - Error logs: Last 50 lines
   - System info: `uname -a`
   - Disk space: `df -h`

---

**Maintained by HusoNode** | [Website](https://husonode.xyz) | [Twitter](https://x.com/husonode)
