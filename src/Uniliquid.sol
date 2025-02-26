// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Uniliquid
/// @notice A stablecoin liquid representation that is created by the hook
contract Uniliquid is ERC20 {
    address public hook;

    modifier onlyHook() {
        if (msg.sender != hook) {
            revert("Only hook can call this function");
        }
        _;
    }

    constructor(string memory name, string memory symbol, address _hook) ERC20(name, symbol) {
        hook = _hook;
    }

    function mint(address to, uint256 amount) external onlyHook {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyHook {
        _burn(from, amount);
    }
}
