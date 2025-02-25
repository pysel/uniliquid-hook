// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev populated with default anvil addresses
    IERC20 constant usdc = IERC20(address(0xd6d150D27095Adce6f84FB1CeEc6A00C5F2645F6));
    IERC20 constant usdt = IERC20(address(0x92d32Daf42A0B08b275A2D7cbed1CEA2D086a122));
    IHooks constant hookContract = IHooks(0x9a67De9e4ac09f3E09C1B7827D333B364a946A80);

    Currency constant currency0 = Currency.wrap(address(usdt));
    Currency constant currency1 = Currency.wrap(address(usdc));
}
