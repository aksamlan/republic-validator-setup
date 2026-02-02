# Republic AI Node - Quick Reference

## Installation

### Automated (Recommended)
```bash
wget -O republic_auto_install.sh https://raw.githubusercontent.com/husonode/republic-validator/main/republic_auto_install.sh && chmod +x republic_auto_install.sh && ./republic_auto_install.sh
```

---

## Node Management

### Service Control
```bash
# Start node
sudo systemctl start republicd

# Stop node
sudo systemctl stop republicd

# Restart node
sudo systemctl restart republicd

# Check status
sudo systemctl status republicd

# Enable auto-start
sudo systemctl enable republicd
```

### Logs
```bash
# Follow logs
journalctl -u republicd -f

# Last 100 lines
journalctl -u republicd -n 100

# Logs since today
journalctl -u republicd --since today
```

---

## Node Status

### Check Sync Status
```bash
republicd status --node tcp://localhost:51657 | jq '.sync_info'
```

### Check Peers
```bash
curl -s http://localhost:51657/net_info | jq '.result.n_peers'
```

### Check Block Height
```bash
republicd status --node tcp://localhost:51657 | jq -r '.sync_info.latest_block_height'
```

### Check Catching Up
```bash
republicd status --node tcp://localhost:51657 | jq -r '.sync_info.catching_up'
```

---

## Wallet Commands

### Create Wallet
```bash
republicd keys add wallet
```

### Recover Wallet
```bash
republicd keys add wallet --recover
```

### List Wallets
```bash
republicd keys list
```

### Show Wallet Address
```bash
republicd keys show wallet -a
```

### Show Validator Address
```bash
republicd keys show wallet --bech val -a
```

### Check Balance
```bash
republicd query bank balances $(republicd keys show wallet -a) --node tcp://localhost:51657
```

### Export Private Key
```bash
republicd keys export wallet
```

### Delete Wallet
```bash
republicd keys delete wallet
```

---

## Validator Commands

### Create Validator
```bash
PUBKEY=$(jq -r '.pub_key.value' $HOME/.republicd/config/priv_validator_key.json)

cat > validator.json << EOF
{
  "pubkey": {"@type":"/cosmos.crypto.ed25519.PubKey","key":"$PUBKEY"},
  "amount": "20000000000000000000arai",
  "moniker": "YOUR_VALIDATOR_NAME",
  "identity": "YOUR_KEYBASE_ID",
  "website": "https://husonode.xyz",
  "security": "contact@husonode.xyz",
  "details": "YOUR_DESCRIPTION",
  "commission-rate": "0.05",
  "commission-max-rate": "0.15",
  "commission-max-change-rate": "0.02",
  "min-self-delegation": "1"
}
EOF

republicd tx staking create-validator validator.json \
--from wallet \
--chain-id raitestnet_77701-1 \
--gas auto \
--gas-adjustment 1.5 \
--gas-prices "1000000000arai" \
--node tcp://localhost:51657 \
-y
```

### Check Validator Info
```bash
republicd query staking validator $(republicd keys show wallet --bech val -a) --node tcp://localhost:51657
```

### Edit Validator
```bash
republicd tx staking edit-validator \
--new-moniker="NEW_NAME" \
--identity="KEYBASE_ID" \
--website="https://husonode.xyz" \
--details="NEW_DESCRIPTION" \
--from wallet \
--chain-id raitestnet_77701-1 \
--gas auto \
--gas-adjustment 1.5 \
--gas-prices 1000000000arai \
--node tcp://localhost:51657 \
-y
```

### Unjail Validator
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

### Check Jail Status
```bash
republicd query slashing signing-info $(republicd tendermint show-validator)
```

---

## Staking Commands

### Delegate Tokens
```bash
# Delegate 10 tokens (10000000000000000000arai = 10 tokens)
republicd tx staking delegate YOUR_VALOPER_ADDRESS \
10000000000000000000arai \
--from wallet \
--chain-id raitestnet_77701-1 \
--gas auto \
--gas-adjustment 1.5 \
--gas-prices 1000000000arai \
--node tcp://localhost:51657 \
-y
```

### Redelegate Tokens
```bash
republicd tx staking redelegate SRC_VALOPER_ADDRESS DEST_VALOPER_ADDRESS \
10000000000000000000arai \
--from wallet \
--chain-id raitestnet_77701-1 \
--gas auto \
--gas-adjustment 1.5 \
--gas-prices 1000000000arai \
--node tcp://localhost:51657 \
-y
```

### Unbond Tokens
```bash
republicd tx staking unbond YOUR_VALOPER_ADDRESS \
10000000000000000000arai \
--from wallet \
--chain-id raitestnet_77701-1 \
--gas auto \
--gas-adjustment 1.5 \
--gas-prices 1000000000arai \
--node tcp://localhost:51657 \
-y
```

### Withdraw Rewards
```bash
republicd tx distribution withdraw-all-rewards \
--from wallet \
--chain-id raitestnet_77701-1 \
--gas auto \
--gas-adjustment 1.5 \
--gas-prices 1000000000arai \
--node tcp://localhost:51657 \
-y
```

### Withdraw Commission
```bash
republicd tx distribution withdraw-rewards YOUR_VALOPER_ADDRESS \
--commission \
--from wallet \
--chain-id raitestnet_77701-1 \
--gas auto \
--gas-adjustment 1.5 \
--gas-prices 1000000000arai \
--node tcp://localhost:51657 \
-y
```

---

## Token Operations

### Send Tokens
```bash
republicd tx bank send wallet RECIPIENT_ADDRESS \
1000000000000000000arai \
--chain-id raitestnet_77701-1 \
--gas auto \
--gas-adjustment 1.5 \
--gas-prices 1000000000arai \
--node tcp://localhost:51657 \
-y
```

### Token Conversion
```
1 TOKEN = 1000000000000000000 arai
10 TOKENS = 10000000000000000000 arai
100 TOKENS = 100000000000000000000 arai
```

---

## Network Maintenance

### Update Peers
```bash
URL="https://rpc.republicai.io/net_info"
response=$(curl -s $URL)
PEERS=$(echo $response | jq -r '.result.peers[] | select(.remote_ip | test("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$")) | "\(.node_info.id)@\(.remote_ip):" + (.node_info.listen_addr | capture(":(?<port>[0-9]+)$").port)' | paste -sd "," -)
sed -i 's|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.republicd/config/config.toml
sudo systemctl restart republicd
```

### Reset Node (Keep Validator Keys)
```bash
# Backup keys
cp $HOME/.republicd/config/priv_validator_key.json $HOME/priv_validator_key.json.backup

# Reset
republicd tendermint unsafe-reset-all --home $HOME/.republicd

# Restore keys
cp $HOME/priv_validator_key.json.backup $HOME/.republicd/config/priv_validator_key.json

# Restart
sudo systemctl restart republicd
```

---

## System Monitoring

### Disk Usage
```bash
df -h
du -sh $HOME/.republicd/data
```

### Memory Usage
```bash
free -h
```

### CPU Usage
```bash
top
# or
htop
```

### Network Usage
```bash
sudo iftop
```

---

## Backup Commands

### Backup Validator Keys
```bash
mkdir -p $HOME/backup
cp $HOME/.republicd/config/priv_validator_key.json $HOME/backup/
cp $HOME/.republicd/config/node_key.json $HOME/backup/
cp $HOME/.republicd/data/priv_validator_state.json $HOME/backup/
```

### Create Backup Archive
```bash
tar -czf republic_backup_$(date +%Y%m%d).tar.gz \
$HOME/.republicd/config/priv_validator_key.json \
$HOME/.republicd/config/node_key.json \
$HOME/.republicd/data/priv_validator_state.json
```

---

## Query Commands

### Query Account
```bash
republicd query account $(republicd keys show wallet -a) --node tcp://localhost:51657
```

### Query Transaction
```bash
republicd query tx TX_HASH --node tcp://localhost:51657
```

### Query All Validators
```bash
republicd query staking validators --node tcp://localhost:51657
```

### Query Delegations
```bash
republicd query staking delegations $(republicd keys show wallet -a) --node tcp://localhost:51657
```

### Query Unbonding Delegations
```bash
republicd query staking unbonding-delegations $(republicd keys show wallet -a) --node tcp://localhost:51657
```

---

## Important Paths

```bash
# Binary
/usr/local/bin/republicd

# Home directory
$HOME/.republicd

# Config
$HOME/.republicd/config/

# Data
$HOME/.republicd/data/

# Validator key
$HOME/.republicd/config/priv_validator_key.json

# Node key
$HOME/.republicd/config/node_key.json

# Genesis
$HOME/.republicd/config/genesis.json

# Service file
/etc/systemd/system/republicd.service
```

---

## Environment Variables

```bash
# View current settings
echo $REPUBLIC_WALLET
echo $REPUBLIC_PORT

# Set wallet name
export REPUBLIC_WALLET="wallet"
echo "export REPUBLIC_WALLET='wallet'" >> $HOME/.bash_profile

# Set port
export REPUBLIC_PORT="51"
echo "export REPUBLIC_PORT='51'" >> $HOME/.bash_profile

# Reload
source $HOME/.bash_profile
```

---

## Quick Checks

### Is Node Running?
```bash
sudo systemctl is-active republicd
```

### Is Node Synced?
```bash
republicd status --node tcp://localhost:51657 | jq -r '.sync_info.catching_up'
# false = synced
# true = still syncing
```

### Current Block Height
```bash
republicd status --node tcp://localhost:51657 | jq -r '.sync_info.latest_block_height'
```

### Validator Address
```bash
republicd keys show wallet --bech val -a
```

### Node ID
```bash
republicd tendermint show-node-id
```

---

## Useful Links

- **Explorer**: https://explorer.republicai.io
- **Official Website**: https://republicai.io
- **Official Twitter**: https://x.com/republicfdn
- **HusoNode Website**: https://husonode.xyz
- **HusoNode Twitter**: https://x.com/husonode

---

## Emergency Commands

### Stop Node Immediately
```bash
sudo systemctl stop republicd
```

### Kill Stuck Process
```bash
pkill republicd
```

### Check Port Usage
```bash
sudo lsof -i :51656
```

### Free Up Disk Space
```bash
# Clean apt cache
sudo apt clean

# Clean journal logs
sudo journalctl --vacuum-time=3d
```

---

**Maintained by HusoNode** | [Website](https://husonode.xyz) | [Twitter](https://x.com/husonode)
