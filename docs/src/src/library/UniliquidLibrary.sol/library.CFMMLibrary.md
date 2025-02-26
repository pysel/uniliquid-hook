# CFMMLibrary
[Git Source](https://github.com/pysel/uniliquid-hook/blob/e6880081808f7cb27684653b8c2e425139cf2240/src/library/UniliquidLibrary.sol)


## State Variables
### MAX_BINARY_ITERATIONS
Maximum number of binary search iterations for finding the amount out of a swap

*Each iteration is worthapproximately 3000 gas (0.0009 USD)*


```solidity
uint256 public constant MAX_BINARY_ITERATIONS = 30;
```


### ERROR_TOLERANCE
Error tolerance for the constant k from the guessed amount out to the true amount out (0.0001%)


```solidity
uint256 public constant ERROR_TOLERANCE = 1e12;
```


### NORMALIZED_DECIMALS
Base decimals for internal calculations (in case when stablecoins have different decimals)


```solidity
uint256 public constant NORMALIZED_DECIMALS = 18;
```


## Functions
### binarySearchExactIn

Performs a binary search to find the exact amount of a token a user should receive from the swap


```solidity
function binarySearchExactIn(uint256 k, uint256 reserveOut, uint256 reserveIn, uint256 addedIn)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`k`|`uint256`|The CFMM constant|
|`reserveOut`|`uint256`|The reserve of the token being swapped out|
|`reserveIn`|`uint256`|The reserve of the token being swapped in|
|`addedIn`|`uint256`|The amount of the token being swapped in|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of the token a user should receive from the swap|


### binK

Computes k for the binary search guess iteration

*k = (reserveOut - guessOut) * (reserveInNew) * ((reserveOut - guessOut)**2 + reserveInNew**2)*


```solidity
function binK(uint256 reserveOut, uint256 guessOut, uint256 reserveInNew) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reserveOut`|`uint256`|The reserve of the token being swapped out|
|`guessOut`|`uint256`|The guess (a binary search one) for the amount of the token being swapped out|
|`reserveInNew`|`uint256`|The reserve of the token being swapped in after the swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The constant k|


### K

Computes the constant k from reserves

*k = reserveOut * reserveIn*


```solidity
function K(uint256 reserveOut, uint256 reserveIn) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reserveOut`|`uint256`|The amount of currency0 in the pool|
|`reserveIn`|`uint256`|The amount of currency1 in the pool|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The constant k|


