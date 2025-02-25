// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {UniliquidHook} from "../src/UniliquidHook.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {BinarySearch} from "../src/library/BinarySearch.sol";
import {Uniliquid} from "../src/Uniliquid.sol";

/*
beforeInitialize: true,
beforeAddLiquidity: true,
beforeRemoveLiquidity: true,
beforeSwap: true,
afterSwap: true,
*/

contract UniliquidHookTest is Test, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using BinarySearch for uint256;

    UniliquidHook hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;
    uint256 constant SWAP_ERR_TOLERANCE = 1e12; // within a 0.0001% of the true amount out
    bytes hookData = abi.encode(address(this));

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        // // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | 
                Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_INITIALIZE_FLAG 
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("UniliquidHook.sol:UniliquidHook", constructorArgs, flags);
        hook = UniliquidHook(flags);

        hook.addAllowedStablecoin(Currency.unwrap(currency0));
        hook.addAllowedStablecoin(Currency.unwrap(currency1));

        approveHook(currency0, hook.AMOUNT_ADDED_INITIALLY());
        approveHook(currency1, hook.AMOUNT_ADDED_INITIALLY());

        // // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function approveHook(Currency currency, uint256 amount) public {
        ERC20(Currency.unwrap(currency)).approve(address(hook), amount);
    }

    function testAddLiquidity() public {
        uint256 amount = 1e18;
        approveHook(currency0, amount);
        approveHook(currency1, amount);
        
        (uint256 poolReserves0Before, uint256 poolReserves1Before) = hook.poolToReserves(poolId);

        uint256 uniliquidAmount0TotalBefore = hook.tokenToLiquid(Currency.unwrap(currency0)).totalSupply();
        uint256 uniliquidAmount1TotalBefore = hook.tokenToLiquid(Currency.unwrap(currency1)).totalSupply();

        uint256 uniliquidAmount0Before = hook.tokenToLiquid(Currency.unwrap(currency0)).balanceOf(address(this));
        uint256 uniliquidAmount1Before = hook.tokenToLiquid(Currency.unwrap(currency1)).balanceOf(address(this));

        uint256 stablecoin0BalanceBefore = currency0.balanceOf(address(this));
        uint256 stablecoin1BalanceBefore = currency1.balanceOf(address(this));

        hook.addLiquidity(address(this), key, Currency.unwrap(currency0), Currency.unwrap(currency1), amount, amount);

        // verify pool reserves are correctly updated
        (uint256 poolReserves0After, uint256 poolReserves1After) = hook.poolToReserves(poolId);

        assertEq(poolReserves0After, poolReserves0Before + amount);
        assertEq(poolReserves1After, poolReserves1Before + amount);

        // verify uniliquid tokens are correctly minted into total supply
        uint256 uniliquidAmount0TotalAfter = hook.tokenToLiquid(Currency.unwrap(currency0)).totalSupply();
        uint256 uniliquidAmount1TotalAfter = hook.tokenToLiquid(Currency.unwrap(currency1)).totalSupply();

        assertEq(uniliquidAmount0TotalAfter, uniliquidAmount0TotalBefore + amount);
        assertEq(uniliquidAmount1TotalAfter, uniliquidAmount1TotalBefore + amount);

        // verify uniliquid tokens are correctly minted into user's balance
        uint256 uniliquidAmount0After = hook.tokenToLiquid(Currency.unwrap(currency0)).balanceOf(address(this));
        uint256 uniliquidAmount1After = hook.tokenToLiquid(Currency.unwrap(currency1)).balanceOf(address(this));

        assertEq(uniliquidAmount0After, uniliquidAmount0Before + amount);
        assertEq(uniliquidAmount1After, uniliquidAmount1Before + amount);

        // verify stablecoin balances are correctly updated
        uint256 stablecoin0BalanceAfter = currency0.balanceOf(address(this));
        uint256 stablecoin1BalanceAfter = currency1.balanceOf(address(this));

        assertEq(stablecoin0BalanceAfter, stablecoin0BalanceBefore - amount);
        assertEq(stablecoin1BalanceAfter, stablecoin1BalanceBefore - amount);
    }

    function testRemoveLiquidity() public {
        uint256 amount = 1e18;
        approveHook(currency0, amount);
        approveHook(currency1, amount);

        (uint256 poolReserves0Before, uint256 poolReserves1Before) = hook.poolToReserves(poolId);

        uint256 uniliquidAmount0TotalBefore = hook.tokenToLiquid(Currency.unwrap(currency0)).totalSupply();
        uint256 uniliquidAmount1TotalBefore = hook.tokenToLiquid(Currency.unwrap(currency1)).totalSupply();

        uint256 uniliquidAmount0Before = hook.tokenToLiquid(Currency.unwrap(currency0)).balanceOf(address(this));
        uint256 uniliquidAmount1Before = hook.tokenToLiquid(Currency.unwrap(currency1)).balanceOf(address(this));

        uint256 stablecoin0BalanceBefore = currency0.balanceOf(address(this));
        uint256 stablecoin1BalanceBefore = currency1.balanceOf(address(this));

        hook.removeLiquidity(address(this), key, Currency.unwrap(currency0), Currency.unwrap(currency1), amount);

        // verify pool reserves are correctly updated
        (uint256 poolReserves0After, uint256 poolReserves1After) = hook.poolToReserves(poolId);

        assertEq(poolReserves0After, poolReserves0Before - amount); // FAILS HERE NOW
        assertEq(poolReserves1After, poolReserves1Before - amount);
        
        // verify uniliquid tokens are correctly burned
        uint256 uniliquidAmount0TotalAfter = hook.tokenToLiquid(Currency.unwrap(currency0)).totalSupply();
        uint256 uniliquidAmount1TotalAfter = hook.tokenToLiquid(Currency.unwrap(currency1)).totalSupply();

        assertEq(uniliquidAmount0TotalAfter, uniliquidAmount0TotalBefore - amount);
        assertEq(uniliquidAmount1TotalAfter, uniliquidAmount1TotalBefore - amount);

        // verify uniliquid tokens are correctly burned from user's balance
        uint256 uniliquidAmount0After = hook.tokenToLiquid(Currency.unwrap(currency0)).balanceOf(address(this));
        uint256 uniliquidAmount1After = hook.tokenToLiquid(Currency.unwrap(currency1)).balanceOf(address(this));

        assertEq(uniliquidAmount0After, uniliquidAmount0Before - amount);
        assertEq(uniliquidAmount1After, uniliquidAmount1Before - amount);
        
        // verify stablecoin balances are correctly updated
        uint256 stablecoin0BalanceAfter = currency0.balanceOf(address(this));
        uint256 stablecoin1BalanceAfter = currency1.balanceOf(address(this));

        assertEq(stablecoin0BalanceAfter, stablecoin0BalanceBefore + amount);
        assertEq(stablecoin1BalanceAfter, stablecoin1BalanceBefore + amount); 
    }

    function testSwapWithRemoveLiquidity() public {
        uint256 amount = 5e18;
        bool zeroForOne = true;

        approveHook(currency0, amount);
        
        // swap first 
        swap(key, zeroForOne, int256(amount), hookData);

        // then remove liquidity
        approveHook(currency0, amount);
        approveHook(currency1, amount);

        uint256 redemptionAmount = 1e18;

        (uint256 X, uint256 Y) = hook.poolToReserves(poolId);

        Uniliquid uniliquid0 = hook.tokenToLiquid(Currency.unwrap(currency0));
        Uniliquid uniliquid1 = hook.tokenToLiquid(Currency.unwrap(currency1));

        uint256 uniliquidAmount0Before = uniliquid0.balanceOf(address(this));
        uint256 uniliquidAmount1Before = uniliquid1.balanceOf(address(this));

        uint256 stablecoin0BalanceBefore = currency0.balanceOf(address(this));
        uint256 stablecoin1BalanceBefore = currency1.balanceOf(address(this));

        uint256 uniliquidAmount0TotalBefore = uniliquid0.totalSupply();
        uint256 uniliquidAmount1TotalBefore = uniliquid1.totalSupply();

        hook.removeLiquidity(address(this), key, Currency.unwrap(currency0), Currency.unwrap(currency1), redemptionAmount);

        uint256 decimals0 = ERC20(Currency.unwrap(currency0)).decimals();
        uint256 decimals1 = ERC20(Currency.unwrap(currency1)).decimals();

        // verify a user burned redemptionAmount of both uniliquid tokens
        uint256 uniliquidAmount0After = uniliquid0.balanceOf(address(this));
        uint256 uniliquidAmount1After = uniliquid1.balanceOf(address(this));

        assertEq(uniliquidAmount0After, uniliquidAmount0Before - redemptionAmount);
        assertEq(uniliquidAmount1After, uniliquidAmount1Before - redemptionAmount);

        // verify that a user received back X_u / X of both stablecoins
        uint256 fraction0Expected = redemptionAmount * 10 ** decimals0 / X;
        uint256 fraction1Expected = redemptionAmount * 10 ** decimals1 / Y;

        uint256 stablecoin0ReceivedExpected = fraction0Expected * X / 10 ** decimals0;
        uint256 stablecoin1ReceivedExpected = fraction1Expected * Y / 10 ** decimals1;

        uint256 stablecoin0After = currency0.balanceOf(address(this));
        uint256 stablecoin1After = currency1.balanceOf(address(this));

        assertEq(stablecoin0After, stablecoin0BalanceBefore + stablecoin0ReceivedExpected);
        assertEq(stablecoin1After, stablecoin1BalanceBefore + stablecoin1ReceivedExpected);

        // verify that the uniliquid tokens are correctly burned from the total supply
        uint256 uniliquidAmount0TotalAfter = uniliquid0.totalSupply();
        uint256 uniliquidAmount1TotalAfter = uniliquid1.totalSupply();

        assertEq(uniliquidAmount0TotalAfter, uniliquidAmount0TotalBefore - redemptionAmount);
        assertEq(uniliquidAmount1TotalAfter, uniliquidAmount1TotalBefore - redemptionAmount);
    }

    function testNativeLiquidityIsNotAllowed() public {
        vm.expectRevert();
        hook.beforeAddLiquidity(address(this),key, IPoolManager.ModifyLiquidityParams({
            tickLower: 0,
            tickUpper: 0,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        }), hookData);

        vm.expectRevert();
        hook.beforeRemoveLiquidity(address(this),key, IPoolManager.ModifyLiquidityParams({
            tickLower: 0,
            tickUpper: 0,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        }), hookData);
    }

    function testSwapGasCost() public {
        int256 amountIn = int256(1e18);
        bool zeroForOne = false;

        approveHook(currency1, uint256(amountIn));
        
        uint256 gasBefore = gasleft();
        swap(key, zeroForOne, amountIn, hookData);
        uint256 gasAfter = gasleft();

        console.log("gasBefore", gasBefore);
        console.log("gasAfter", gasAfter);
        console.log("gasUsed", gasBefore - gasAfter);
    }

    function testSwaps() public {
        int256 amountIn = int256(1e18);
        bool zeroForOne = false;

        approveHook(currency1, uint256(amountIn));

        uint256 currency0BalanceBefore = currency0.balanceOf(address(this));
        uint256 currency1BalanceBefore = currency1.balanceOf(address(this));

        swap(key, zeroForOne, amountIn, hookData);

        // https://www.wolframalpha.com/input?i=find+x+in+%2810e18+%2B+1e18%29%2810e18+-+x%29+%2F+1e18+*%28%2810e18+%2B+1e18%29%5E2+%2B+%2810e18+-+x%29%5E2%29+%2F+1e18+%3D+20000000000000000000000000000000000000000
        uint256 amountOutExpected = 999500518006395648; 
        amountOutExpected = applyFee(amountOutExpected);

        uint256 currency0BalanceAfter = currency0.balanceOf(address(this));
        uint256 currency1BalanceAfter = currency1.balanceOf(address(this));

        // currency0 should increase, currency1 should decrease
        uint256 currency0BalanceChange = currency0BalanceAfter - currency0BalanceBefore;
        uint256 currency1BalanceChange = currency1BalanceBefore - currency1BalanceAfter;

        assertTrue(currency0BalanceChange.within(SWAP_ERR_TOLERANCE, amountOutExpected));
        assertEq(currency1BalanceChange, uint256(amountIn));

        // oneForZero Swap
        zeroForOne = true;
        approveHook(currency0, uint256(amountIn));

        currency0BalanceBefore = currency0.balanceOf(address(this));
        currency1BalanceBefore = currency1.balanceOf(address(this));

        swap(key, zeroForOne, amountIn, hookData);

        // true amount out: https://www.wolframalpha.com/input?i=find+x+in+%289030484497534384903+%2B+1e18%29%2811e18+-+x%29%28%289030484497534384903+%2B+1e18%29%5E2+%2B+%2811e18+-+x%29%5E2%29+%3D+20120336243214102838134569266726391276333431006160704305597000000000000000000
        // this is diferent from the binary search test, because the binary search test does not take into account the fee
        amountOutExpected = 1000496269222984064; 
        amountOutExpected = applyFee(amountOutExpected);

        currency0BalanceAfter = currency0.balanceOf(address(this));
        currency1BalanceAfter = currency1.balanceOf(address(this));

        // currency0 should decrease, currency1 should increase
        currency0BalanceChange = currency0BalanceBefore - currency0BalanceAfter;
        currency1BalanceChange = currency1BalanceAfter - currency1BalanceBefore;

        assertTrue(currency1BalanceChange.within(SWAP_ERR_TOLERANCE, amountOutExpected));
        assertEq(currency0BalanceChange, uint256(amountIn));
    }

    function testUniliquidTokensCreated() public view {
        address ulCurrency0 = address(hook.tokenToLiquid(Currency.unwrap(currency0)));
        address ulCurrency1 = address(hook.tokenToLiquid(Currency.unwrap(currency1)));

        ERC20 ulCurrency0Token = ERC20(ulCurrency0);
        ERC20 ulCurrency1Token = ERC20(ulCurrency1);

        assertEq(ulCurrency0Token.totalSupply(), hook.AMOUNT_ADDED_INITIALLY());
        assertEq(ulCurrency1Token.totalSupply(), hook.AMOUNT_ADDED_INITIALLY());
    }

    // simulates two swaps: first is oneForZero, second is zeroForOne
    // function testBinarySearch() public view {
    //     (uint256 reserve0, uint256 reserve1) = hook.poolToReserves(poolId);
    //     uint256 k = reserve0 * reserve1 * (reserve0**2 + reserve1**2);
    //     uint256 amountIn = 1e18;

    //     uint256 amountOut = hook.binarySearchExactIn(k, reserve0, reserve1, amountIn);

    //     // true amount out: https://www.wolframalpha.com/input?i=find+x+in+%2810e18+%2B+1e18%29%2810e18+-+x%29%28%2810e18+%2B+1e18%29%5E2+%2B+%2810e18+-+x%29%5E2%29+%3D+2+*+10e75+
    //     uint256 amountOutExpected = 999500518006394112; 

    //     assertTrue(amountOut.within(SWAP_ERR_TOLERANCE, amountOutExpected));

    //     // update reserves
    //     reserve0 = reserve0 - amountOut; // approx 9000498771667480469
    //     reserve1 = reserve1 + amountIn; // 11e18

    //     // check another direction
    //     k = reserve0 * reserve1 * (reserve0**2 + reserve1**2); // k is slightly different from swap to swap

    //     amountIn = 1e18;

    //     amountOut = hook.binarySearchExactIn(k, reserve1, reserve0, amountIn);

    //     // true amount out: https://www.wolframalpha.com/input?i=find+x+in+%289000499481994211240+%2B+1e18%29%2811e18+-+x%29%28%289000499481994211240+%2B+1e18%29%5E2+%2B+%2811e18+-+x%29%5E2%29+%3D+20000000000002424510585603816519565336181102649003740864000000000000000000000
    //     amountOutExpected = 1000499481993604992;
    //     assertTrue(amountOut.within(SWAP_ERR_TOLERANCE, amountOutExpected));
    // }

    function applyFee(uint256 amount) internal view returns (uint256) {
        return amount * (1000000 - hook.FEE_AMOUNT()) / 1000000;
    }
}
