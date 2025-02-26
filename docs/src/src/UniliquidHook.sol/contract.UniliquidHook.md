# UniliquidHook
[Git Source](https://github.com/pysel/uniliquid-hook/blob/e6880081808f7cb27684653b8c2e425139cf2240/src/UniliquidHook.sol)

**Inherits:**
[BaseHook](/src/forks/BaseHook.sol/abstract.BaseHook.md), [UniliquidVariables](/src/UniliquidVariables.sol/contract.UniliquidVariables.md), SafeCallback

**Author:**
Ruslan Akhtariev

A hook for creating liquid LP positions on stablecoin pools with a custom AMM implementation (CFMM - xy(x^2 + y^2) = k)

The curve graph may be found here: https://www.desmos.com/calculator/kbo1rjbalx


## State Variables
### allowedStablecoins
Mapping of allowed stablecoins


```solidity
mapping(address => ERC20) public allowedStablecoins;
```


### tokenToLiquid
Mapping of uniliquid erc-20 implementaitons


```solidity
mapping(address => Uniliquid) public tokenToLiquid;
```


### poolToReserves
Mapping of pool reserves


```solidity
mapping(PoolId => PoolReserves) public poolToReserves;
```


### reentrancyGuard_

```solidity
bool private reentrancyGuard_ = false;
```


## Functions
### onlyStablecoins

Prevents non-stablecoin tokens being passed to the hook


```solidity
modifier onlyStablecoins(Currency currency0, Currency currency1);
```

### reentrancyGuard

Prevents reentrancy


```solidity
modifier reentrancyGuard();
```

### constructor


```solidity
constructor(IPoolManager manager) SafeCallback(manager);
```

### _poolManager


```solidity
function _poolManager() internal view override returns (IPoolManager);
```

### getHookPermissions

The hook permissions:

- beforeInitialize: true

- beforeAddLiquidity: true

- beforeRemoveLiquidity: true

- beforeSwap: true


```solidity
function getHookPermissions() public pure override returns (Hooks.Permissions memory);
```

### _beforeInitialize

The hook that initializes the pool

During the initialization, the hook creates the uniliquid erc-20 stablecoins if they are allowed, but non-existent yet

Adds the initial liquidity to the pool


```solidity
function _beforeInitialize(address, PoolKey calldata key, uint160)
    internal
    override
    onlyStablecoins(key.currency0, key.currency1)
    returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`||
|`key`|`PoolKey`|The pool key|
|`<none>`|`uint160`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|Selector of the hook|


### _beforeSwap

The no-op hook that performs a swap on a custom CFMM curve.


```solidity
function _beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata data)
    internal
    override
    returns (bytes4, BeforeSwapDelta, uint24);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`||
|`key`|`PoolKey`|The pool key|
|`params`|`IPoolManager.SwapParams`|The swap parameters|
|`data`|`bytes`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|The no-op return|
|`<none>`|`BeforeSwapDelta`||
|`<none>`|`uint24`||


### _beforeAddLiquidity

The disabled native Uniswap V4 add liquidity functionality


```solidity
function _beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
    internal
    pure
    override
    returns (bytes4);
```

### _beforeRemoveLiquidity

The disabled native Uniswap V4 remove liquidity functionality


```solidity
function _beforeRemoveLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
    internal
    pure
    override
    returns (bytes4);
```

### addLiquidity

Adds liquidity to the pool

*the amount of each token deposited must be the same*


```solidity
function addLiquidity(
    address sender,
    PoolKey calldata key,
    address currency0,
    address currency1,
    uint256 amount0,
    uint256 amount1
) public onlyStablecoins(Currency.wrap(currency0), Currency.wrap(currency1)) reentrancyGuard;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address of the sender|
|`key`|`PoolKey`|The pool key|
|`currency0`|`address`|The address of the first stablecoin|
|`currency1`|`address`|The address of the second stablecoin|
|`amount0`|`uint256`|The amount of the first stablecoin to deposit|
|`amount1`|`uint256`|The amount of the second stablecoin to deposit|


### removeLiquidity

Removes liquidity from the pool


```solidity
function removeLiquidity(address sender, PoolKey calldata key, address currency0, address currency1, uint256 amount)
    external
    onlyStablecoins(Currency.wrap(currency0), Currency.wrap(currency1))
    reentrancyGuard;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address of the sender|
|`key`|`PoolKey`|The pool key|
|`currency0`|`address`|The address of the first stablecoin|
|`currency1`|`address`|The address of the second stablecoin|
|`amount`|`uint256`|The amount of each token to remove|


### _unlockCallback


```solidity
function _unlockCallback(bytes calldata data) internal virtual override returns (bytes memory);
```

### addAllowedStablecoin

Adds a stablecoin to the allowed list


```solidity
function addAllowedStablecoin(address currency) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`address`|The address of the stablecoin to add|


### removeAllowedStablecoin

Removes a stablecoin from the allowed list


```solidity
function removeAllowedStablecoin(address currency) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`address`|The address of the stablecoin to remove|


