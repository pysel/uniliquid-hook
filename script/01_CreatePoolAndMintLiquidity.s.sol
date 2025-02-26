// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {UniliquidHook} from "../src/UniliquidHook.sol";

import {Constants} from "./base/Constants.sol";
import {Config} from "./base/Config.sol";

contract CreatePoolAndMintLiquidityScript is Script, Constants, Config {
    using CurrencyLibrary for Currency;

    /////////////////////////////////////
    // --- Parameters to Configure --- //
    /////////////////////////////////////

    // --- pool configuration --- //
    // fees paid by swappers that accrue to liquidity providers
    uint24 lpFee = 3000; // 0.30%
    int24 tickSpacing = 60;

    // starting price of the pool, in sqrtPriceX96
    uint160 startingPrice = 79228162514264337593543950336; // floor(sqrt(1) * 2^96)

    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    // range of the position
    int24 tickLower = -600; // must be a multiple of tickSpacing
    int24 tickUpper = 600;
    /////////////////////////////////////

    function run() external {
        PoolKey memory key = PoolKey(currency0, currency1, 3000, 60, hookContract);
        // --------------------------------- //

        // if the pool is an ETH pair, native tokens are to be transferred

        vm.startBroadcast();
        allowTokens();
        vm.stopBroadcast();

        vm.startBroadcast();
        tokenApprovals();
        vm.stopBroadcast();

        // multicall to atomically create pool & add liquidity
        vm.broadcast();
        POOLMANAGER.initialize(key, SQRT_PRICE_1_1);

        UniliquidHook hook = UniliquidHook(address(hookContract));

        vm.broadcast();
        hook.addLiquidity(msg.sender, key, Currency.unwrap(currency0), Currency.unwrap(currency1), 10e18, 10e18);
    }

    function allowTokens() public {
        UniliquidHook(address(hookContract)).addAllowedStablecoin(address(usdc));
        UniliquidHook(address(hookContract)).addAllowedStablecoin(address(usdt));
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
