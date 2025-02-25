// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";

import {Constants} from "./base/Constants.sol";
import {Config} from "./base/Config.sol";

contract SwapScript is Script, Constants, Config {
    // slippage tolerance to allow for unlimited price impact
    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;

    /////////////////////////////////////
    // --- Parameters to Configure --- //
    /////////////////////////////////////

    // PoolSwapTest Contract address, default to the sepolia address
    PoolSwapTest swapRouter = PoolSwapTest(0x9140a78c1A137c7fF1c151EC8231272aF78a99A4);

    // --- pool configuration --- //
    // fees paid by swappers that accrue to liquidity providers
    uint24 lpFee = 3000; // 0.30%
    int24 tickSpacing = 60;

    function run() external {
        PoolKey memory pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });

        // approve tokens to the hook
        vm.broadcast();
        usdt.approve(address(hookContract), type(uint256).max);
        vm.broadcast();
        usdc.approve(address(hookContract), type(uint256).max);

        // ------------------------------ //
        // Swap 100e18 token0 into token1 //
        // ------------------------------ //
        bool zeroForOne = false;
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: 256e18,
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : type(uint160).max
        });

        // in v4, users have the option to receieve native ERC20s or wrapped ERC1155 tokens
        // here, we'll take the ERC20s
        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        bytes memory hookData = abi.encode(msg.sender);
        
        console.log("usdt balance before swap", usdt.balanceOf(msg.sender));
        console.log("usdc balance before swap", usdc.balanceOf(msg.sender));

        vm.broadcast();
        swapRouter.swap(pool, params, testSettings, hookData);

        console.log("usdt balance after swap", usdt.balanceOf(msg.sender));
        console.log("usdc balance after swap", usdc.balanceOf(msg.sender));
    }
}
