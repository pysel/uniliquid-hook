# UniliquidLibrary
[Git Source](https://github.com/pysel/uniliquid-hook/blob/e6880081808f7cb27684653b8c2e425139cf2240/src/library/UniliquidLibrary.sol)


## Functions
### within

Checks if two numbers are within a tolerance of each other


```solidity
function within(uint256 first, uint256 tolerance, uint256 second) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`first`|`uint256`|The first number|
|`tolerance`|`uint256`|The tolerance|
|`second`|`uint256`|The second number|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the numbers are within the tolerance, false otherwise|


### applyFee

Applies a fee to the amount


```solidity
function applyFee(uint256 amount, uint256 fee) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to apply the fee to|
|`fee`|`uint256`|The fee to apply|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount after the fee is applied|


### scaleAmount

Scales an amount from one decimal precision to another


```solidity
function scaleAmount(uint256 amount, uint256 fromDecimals, uint256 toDecimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to scale|
|`fromDecimals`|`uint256`|The current decimal precision|
|`toDecimals`|`uint256`|The target decimal precision|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The scaled amount|


