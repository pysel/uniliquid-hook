// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev populated with default anvil addresses
    IERC20 constant usdc = IERC20(address(0xDba72418a27113BB4F2F351B9341F8d650FFA08a));
    IERC20 constant usdt = IERC20(address(0x65a546448393872bB56Aa74931AFEf34DeD45514));
    IHooks constant hookContract = IHooks(0xA1BDa7CA8B5b9c08C4942E0b43CCF26a70206a88);

    Currency constant currency0 = Currency.wrap(address(usdt));
    Currency constant currency1 = Currency.wrap(address(usdc));
}
