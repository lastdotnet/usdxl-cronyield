#!/bin/bash

# Load environment variables from .env file
if [ -f /usr/local/bin/.env ]; then
    source /usr/local/bin/.env
else
    echo "Error: .env file not found"
    exit 1
fi

# Fetch token decimals
TOKEN_DECIMALS=$(cast call "$YIELD_TOKEN_ADDRESS" "decimals()(uint8)" --rpc-url "$RPC_URL")
if [ -z "$TOKEN_DECIMALS" ]; then
    echo "Error: Could not fetch token decimals"
    exit 1
fi

# Calculate amount in smallest unit (wei)
AMOUNT_WEI=$(cast to-uint256 $(cast --to-base $TOKEN_AMOUNT --decimals $TOKEN_DECIMALS))

# Log the start of execution
SENDER=$(cast wallet address --private-key $PRIVATE_KEY)
echo "Starting token transfer at: $(date)"
echo "Transferring $TOKEN_AMOUNT tokens ($AMOUNT_WEI in smallest unit, $TOKEN_DECIMALS decimals) from $SENDER to $YIELD_RECIPIENT"

# Execute the token transfer using cast
cast send \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    "$YIELD_TOKEN_ADDRESS" \
    "transfer(address,uint256)" \
    "$YIELD_RECIPIENT" \
    "$AMOUNT_WEI"

# Log the completion
echo "Token transfer completed at: $(date)" 