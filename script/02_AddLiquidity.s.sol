// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {UniliquidHook} from "../src/UniliquidHook.sol";
import {MockToken} from "./mocks/MockER20.s.sol";

import {EasyPosm} from "../test/utils/EasyPosm.sol";
import {Constants} from "./base/Constants.sol";
import {Config} from "./base/Config.sol";

contract AddLiquidityScript is Script, Constants, Config {
    using CurrencyLibrary for Currency;
    using EasyPosm for IPositionManager;
    using StateLibrary for IPoolManager;

    /////////////////////////////////////
    // --- Parameters to Configure --- //
    /////////////////////////////////////

    // --- pool configuration --- //
    // fees paid by swappers that accrue to liquidity providers
    uint24 lpFee = 3000; // 0.30%
    int24 tickSpacing = 60;

    // --- liquidity position configuration --- //
    uint256 public token0Amount = 1e18;
    uint256 public token1Amount = 1e18;

    // range of the position
    int24 tickLower = -600; // must be a multiple of tickSpacing
    int24 tickUpper = 600;
    /////////////////////////////////////

    function run() external {
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });

        vm.startBroadcast();
        tokenApprovals();
        vm.stopBroadcast();

        uint256 amount = 10000e18; // 10k USD of each stablecoin

        vm.startBroadcast();
        MockToken(address(usdc)).mint(msg.sender, amount);
        MockToken(address(usdt)).mint(msg.sender, amount);
        vm.stopBroadcast();

        vm.startBroadcast();
        UniliquidHook(address(hookContract)).addLiquidity(
            msg.sender, key, Currency.unwrap(currency0), Currency.unwrap(currency1), amount, amount
        );
        vm.stopBroadcast();
    }

    function tokenApprovals() public {
        if (!currency0.isAddressZero()) {
            usdc.approve(address(hookContract), type(uint256).max);
        }

        if (!currency1.isAddressZero()) {
            usdt.approve(address(hookContract), type(uint256).max);
        }
    }
}
