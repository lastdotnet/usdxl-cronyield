#!/bin/bash

# Set PATH to include common locations for cast and other tools
export PATH="/root/.foundry/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Add timestamp to all output
echo "=== ECS Scheduled Task started at $(date) ==="

# Validate required environment variables
required_vars=("RPC_URL" "PRIVATE_KEY" "YIELD_TOKEN_ADDRESS" "YIELD_RECIPIENT" "TOKEN_AMOUNT")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Required environment variable $var is not set"
        exit 1
    fi
done
echo "✓ All required environment variables are set"

# Check if cast command is available
if ! command -v cast &> /dev/null; then
    echo "Error: 'cast' command not found in PATH: $PATH"
    exit 1
fi
echo "✓ Cast command is available"

# Fetch token decimals
echo "Fetching token decimals for $YIELD_TOKEN_ADDRESS..."
TOKEN_DECIMALS=$(cast call "$YIELD_TOKEN_ADDRESS" "decimals()(uint8)" --rpc-url "$RPC_URL" 2>/dev/null)
if [ -z "$TOKEN_DECIMALS" ]; then
    echo "Error: Could not fetch token decimals"
    exit 1
fi
echo "✓ Token decimals: $TOKEN_DECIMALS"

# Calculate amount in smallest unit (wei)
echo "Calculating amount in wei..."
AMOUNT_WEI=$(cast to-uint256 $(cast --to-base $TOKEN_AMOUNT --decimals $TOKEN_DECIMALS) 2>/dev/null)
if [ -z "$AMOUNT_WEI" ]; then
    echo "Error: Could not calculate amount in wei"
    exit 1
fi
echo "✓ Amount in wei: $AMOUNT_WEI"

# Get sender address
SENDER=$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null)
if [ -z "$SENDER" ]; then
    echo "Error: Could not get sender address from private key"
    exit 1
fi
echo "✓ Sender address: $SENDER"

# Log the start of execution
echo "Starting token transfer at: $(date)"
echo "Transferring $TOKEN_AMOUNT tokens ($AMOUNT_WEI in smallest unit, $TOKEN_DECIMALS decimals)"
echo "From: $SENDER"
echo "To: $YIELD_RECIPIENT"
echo "Token: $YIELD_TOKEN_ADDRESS"

# Execute the token transfer using cast
echo "Executing transfer..."
if cast send \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    "$YIELD_TOKEN_ADDRESS" \
    "transfer(address,uint256)" \
    "$YIELD_RECIPIENT" \
    "$AMOUNT_WEI"; then
    echo "✅ Token transfer completed successfully at: $(date)"
    echo "=== ECS Scheduled Task completed successfully at $(date) ==="
else
    echo "❌ Token transfer failed at: $(date)"
    echo "=== ECS Scheduled Task failed at $(date) ==="
    exit 1
fi 