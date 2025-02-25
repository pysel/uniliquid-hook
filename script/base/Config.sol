// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev populated with default anvil addresses
    IERC20 constant usdc = IERC20(address(0x9A633a7F11f61658E161A432A013507cF1960F96));
    IERC20 constant usdt = IERC20(address(0x0702d07EFD2518921ae738C74BECb5e24e47F662));
    IHooks constant hookContract = IHooks(0xfD51cB09A99dEE082B88870d58AdFF42A3976a80);

    Currency constant currency0 = Currency.wrap(address(usdt));
    Currency constant currency1 = Currency.wrap(address(usdc));
}
