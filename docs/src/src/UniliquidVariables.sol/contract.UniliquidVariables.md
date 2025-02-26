# UniliquidVariables
[Git Source](https://github.com/pysel/uniliquid-hook/blob/e6880081808f7cb27684653b8c2e425139cf2240/src/UniliquidVariables.sol)


## State Variables
### LIQUID_TOKEN_SYMBOL_PREFIX
Prefix for the symbol of the uniliquid erc-20 stablecoin


```solidity
string public constant LIQUID_TOKEN_SYMBOL_PREFIX = "ul";
```


### LIQUID_TOKEN_NAME_PREFIX
Prefix for the name of the uniliquid erc-20 stablecoin


```solidity
string public constant LIQUID_TOKEN_NAME_PREFIX = "Uniliquid ";
```


### FEE_AMOUNT
Fee amount in basis points (0.3%)


```solidity
uint256 public constant FEE_AMOUNT = 3000;
```


## Events
### LiquidityAdded
Event emitted when liquidity is added to the pool


```solidity
event LiquidityAdded(address indexed currency0, address indexed currency1, uint256 amount0, uint256 amount1);
```

### LiquidityRemoved
Event emitted when liquidity is removed from the pool


```solidity
event LiquidityRemoved(address indexed currency0, address indexed currency1, uint256 amount0Out, uint256 amount1Out);
```

## Errors
### OnlyStablecoins
Error thrown when a non-stablecoin is passed to the hook


```solidity
error OnlyStablecoins(address currency0, address currency1);
```

### AddLiquidityDirectlyToHook
Error thrown when add liquidity is called through the pool manager (disabled)


```solidity
error AddLiquidityDirectlyToHook();
```

### RemoveLiquidityDirectlyFromHook
Error thrown when remove liquidity is called through the pool manager (disabled)


```solidity
error RemoveLiquidityDirectlyFromHook();
```

### InsufficientReserves
Error thrown when the reserves are insufficient


```solidity
error InsufficientReserves(address currency0, address currency1);
```

### ExactOutSwapsNotYetSupported
Temporary error thrown when amountSpecified is negative (exactOut swaps not yet supported)


```solidity
error ExactOutSwapsNotYetSupported();
```

### NormalizedDepositedLiquidityMismatch
Error thrown when the normalized deposited liquidity mismatch


```solidity
error NormalizedDepositedLiquidityMismatch();
```

### SlippageProtection
Error thrown when the output amount is less than the minimum amount out


```solidity
error SlippageProtection(uint256 amountOut, uint256 minAmountOut);
```

## Structs
### PoolReserves
Per-pool true reserves


```solidity
struct PoolReserves {
    uint256 currency0Reserves;
    uint256 currency1Reserves;
}
```

