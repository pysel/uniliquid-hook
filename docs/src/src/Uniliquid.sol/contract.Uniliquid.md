# Uniliquid
[Git Source](https://github.com/pysel/uniliquid-hook/blob/e6880081808f7cb27684653b8c2e425139cf2240/src/Uniliquid.sol)

**Inherits:**
ERC20

A stablecoin liquid representation that is created by the hook


## State Variables
### hook

```solidity
address public hook;
```


## Functions
### onlyHook


```solidity
modifier onlyHook();
```

### constructor


```solidity
constructor(string memory name, string memory symbol, address _hook) ERC20(name, symbol);
```

### mint


```solidity
function mint(address to, uint256 amount) external onlyHook;
```

### burn


```solidity
function burn(address from, uint256 amount) external onlyHook;
```

