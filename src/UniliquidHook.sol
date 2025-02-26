// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "./forks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {Uniliquid} from "./Uniliquid.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {UniliquidLibrary, CFMMLibrary} from "./library/UniliquidLibrary.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {toBeforeSwapDelta, BeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UniliquidVariables} from "./UniliquidVariables.sol";

/// @title UniliquidHook
/// @author Ruslan Akhtariev
/// @notice A hook for creating liquid LP positions on stablecoin pools with a custom AMM implementation (CFMM - xy(x^2 + y^2) = k)
/// @notice The curve graph may be found here: https://www.desmos.com/calculator/kbo1rjbalx
contract UniliquidHook is BaseHook, UniliquidVariables, SafeCallback {
    using PoolIdLibrary for PoolKey;
    using UniliquidLibrary for uint256;
    using SafeCast for uint256;

    /// @notice Mapping of allowed stablecoins
    mapping(address => ERC20) public allowedStablecoins;
    /// @notice Mapping of uniliquid erc-20 implementaitons
    mapping(address => Uniliquid) public tokenToLiquid;
    /// @notice Mapping of pool reserves
    mapping(PoolId => PoolReserves) public poolToReserves;

    bool private reentrancyGuard_ = false;

    /// @notice Prevents non-stablecoin tokens being passed to the hook
    modifier onlyStablecoins(Currency currency0, Currency currency1) {
        address currency0Address = Currency.unwrap(currency0);
        address currency1Address = Currency.unwrap(currency1);

        if (
            allowedStablecoins[currency0Address] == ERC20(address(0)) ||
            allowedStablecoins[currency1Address] == ERC20(address(0))
        ) {
            revert OnlyStablecoins(currency0Address, currency1Address);
        }
        _;
    }

    /// @notice Prevents reentrancy
    modifier reentrancyGuard() {
        if (reentrancyGuard_) {
            revert();
        }
        reentrancyGuard_ = true;
        _;
        reentrancyGuard_ = false;
    }

    constructor(IPoolManager manager) SafeCallback(manager) {}

    function _poolManager() internal view override returns (IPoolManager) { 
        return poolManager;
    }

    /// @notice The hook permissions:
    /// @notice - beforeInitialize: true
    /// @notice - beforeAddLiquidity: true
    /// @notice - beforeRemoveLiquidity: true
    /// @notice - beforeSwap: true
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: false,
                beforeAddLiquidity: true,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: true,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    /// @notice The hook that initializes the pool
    /// @notice During the initialization, the hook creates the uniliquid erc-20 stablecoins if they are allowed, but non-existent yet
    /// @notice Adds the initial liquidity to the pool
    /// @param key The pool key
    /// @return Selector of the hook
    function _beforeInitialize(
        address,
        PoolKey calldata key,
        uint160
    )
        internal
        override
        onlyStablecoins(key.currency0, key.currency1)
        returns (bytes4)
    {
        address currency0 = Currency.unwrap(key.currency0);
        address currency1 = Currency.unwrap(key.currency1);

        // creates a uniliquid erc-20 stablecoin if it is allowed, but non-existent yet
        if (tokenToLiquid[currency0] == Uniliquid(address(0))) {
            string memory symbol = string.concat(
                LIQUID_TOKEN_SYMBOL_PREFIX,
                ERC20(currency0).symbol()
            );
            string memory name = string.concat(
                LIQUID_TOKEN_NAME_PREFIX,
                ERC20(currency0).name()
            );
            tokenToLiquid[currency0] = new Uniliquid(
                name,
                symbol,
                address(this)
            );
        }

        if (
            tokenToLiquid[Currency.unwrap(key.currency1)] ==
            Uniliquid(address(0))
        ) {
            string memory symbol = string.concat(
                LIQUID_TOKEN_SYMBOL_PREFIX,
                ERC20(currency1).symbol()
            );
            string memory name = string.concat(
                LIQUID_TOKEN_NAME_PREFIX,
                ERC20(currency1).name()
            );
            tokenToLiquid[currency1] = new Uniliquid(
                name,
                symbol,
                address(this)
            );
        }

        return BaseHook.beforeInitialize.selector;
    }

    /// @notice The no-op hook that performs a swap on a custom CFMM curve.
    /// @param key The pool key
    /// @param params The swap parameters
    /// @return The no-op return
    function _beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        address currency0 = Currency.unwrap(key.currency0);
        address currency1 = Currency.unwrap(key.currency1);

        uint256 reserve0 = poolToReserves[key.toId()].currency0Reserves;
        uint256 reserve1 = poolToReserves[key.toId()].currency1Reserves;

        uint256 reserveIn = params.zeroForOne ? reserve0 : reserve1;
        uint256 reserveOut = params.zeroForOne ? reserve1 : reserve0;

        if (reserveIn == 0 || reserveOut == 0) {
            revert InsufficientReserves(currency0, currency1);
        }

        uint256 k = CFMMLibrary.K(reserveIn, reserveOut);

        int256 amountInI = params.amountSpecified;
        if (amountInI >= 0) {
            revert ExactOutSwapsNotYetSupported();
        }

        Currency input = params.zeroForOne ? key.currency0 : key.currency1;
        Currency output = params.zeroForOne ? key.currency1 : key.currency0;

        uint256 amountIn = uint256(-params.amountSpecified);

        // mint input tokens to the hook
        poolManager.mint(address(this), input.toId(), amountIn);

        // Normalize input amount
        uint256 normalizedIn = amountIn.scaleAmount(
            ERC20(currency0).decimals(),
            CFMMLibrary.NORMALIZED_DECIMALS
        );

        // decode the minimum amount out
        uint256 minAmountOut = abi.decode(data, (uint256));

        // Calculate output in normalized decimals
        uint256 normalizedOut = CFMMLibrary.binarySearchExactIn(
            k,
            reserveOut,
            reserveIn,
            normalizedIn
        );

        // apply fee
        normalizedOut = normalizedOut.applyFee(key.fee);

        // Convert output back to token decimals
        uint256 amountOut = normalizedOut.scaleAmount(
            CFMMLibrary.NORMALIZED_DECIMALS,
            ERC20(currency1).decimals()
        );
        
        // check if the output amount is less than the minimum amount out
        if (amountOut < minAmountOut) {
            revert SlippageProtection(amountOut, minAmountOut);
        }

        // update reserves
        if (params.zeroForOne) {
            poolToReserves[key.toId()].currency0Reserves += normalizedIn;
            poolToReserves[key.toId()].currency1Reserves -= normalizedOut;
        } else {
            poolToReserves[key.toId()].currency0Reserves -= normalizedOut;
            poolToReserves[key.toId()].currency1Reserves += normalizedIn;
        }

        poolManager.burn(address(this), output.toId(), amountOut);

        return (BaseHook.beforeSwap.selector, toBeforeSwapDelta(amountIn.toInt128(), -amountOut.toInt128()), 0);
    }

    /// @notice The disabled native Uniswap V4 add liquidity functionality
    function _beforeAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) internal pure override returns (bytes4) {
        revert AddLiquidityDirectlyToHook();
    }

    /// @notice The disabled native Uniswap V4 remove liquidity functionality
    function _beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) internal pure override returns (bytes4) {
        revert RemoveLiquidityDirectlyFromHook();
    }

    /// @notice Adds liquidity to the pool
    /// @dev the amount of each token deposited must be the same
    /// @param sender The address of the sender
    /// @param key The pool key
    /// @param currency0 The address of the first stablecoin
    /// @param currency1 The address of the second stablecoin
    /// @param amount0 The amount of the first stablecoin to deposit
    /// @param amount1 The amount of the second stablecoin to deposit
    function addLiquidity(
        address sender,
        PoolKey calldata key,
        address currency0,
        address currency1,
        uint256 amount0,
        uint256 amount1
    )
        public
        onlyStablecoins(Currency.wrap(currency0), Currency.wrap(currency1))
        reentrancyGuard
    {
        // Convert amounts to normalized decimals for internal accounting
        uint256 normalized0 = amount0.scaleAmount(
            ERC20(currency0).decimals(),
            CFMMLibrary.NORMALIZED_DECIMALS
        );
        uint256 normalized1 = amount1.scaleAmount(
            ERC20(currency1).decimals(),
            CFMMLibrary.NORMALIZED_DECIMALS
        );

        // depositing stablecoins to a pool with different normalized amounts is not allowed
        // TODO: this can actually be allowed, we can compute the correct amount here and return change, if any
        if (normalized0 != normalized1) {
            revert NormalizedDepositedLiquidityMismatch();
        }

        // Mint liquid tokens using normalized amounts
        tokenToLiquid[currency0].mint(sender, normalized0);
        tokenToLiquid[currency1].mint(sender, normalized1);

        // ERC20(currency0).transferFrom(sender, address(this), amount0);
        // ERC20(currency1).transferFrom(sender, address(this), amount1);

        // Store normalized reserves
        poolToReserves[key.toId()].currency0Reserves += normalized0;
        poolToReserves[key.toId()].currency1Reserves += normalized1;

        // poolManager.mint(address(this), Currency.wrap(currency0).toId(), amount0);
        // poolManager.mint(address(this), Currency.wrap(currency1).toId(), amount1);

        poolManager.unlock(
            abi.encode(
                sender,
                key.currency0,
                key.currency1,
                amount0,
                amount1,
                true
            )
        );

        emit LiquidityAdded(currency0, currency1, amount0, amount1);
    }

    /// @notice Removes liquidity from the pool
    /// @param sender The address of the sender
    /// @param key The pool key
    /// @param currency0 The address of the first stablecoin
    /// @param currency1 The address of the second stablecoin
    /// @param amount The amount of each token to remove
    function removeLiquidity(
        address sender,
        PoolKey calldata key,
        address currency0,
        address currency1,
        uint256 amount
    )
        external
        onlyStablecoins(Currency.wrap(currency0), Currency.wrap(currency1))
        reentrancyGuard
    {
        tokenToLiquid[currency0].burn(sender, amount);
        tokenToLiquid[currency1].burn(sender, amount);

        uint256 fraction0Out = (amount * 10 ** ERC20(currency0).decimals()) /
            poolToReserves[key.toId()].currency0Reserves;
        uint256 fraction1Out = (amount * 10 ** ERC20(currency1).decimals()) /
            poolToReserves[key.toId()].currency1Reserves;

        uint256 amount0Out = (fraction0Out *
            poolToReserves[key.toId()].currency0Reserves) /
            10 ** ERC20(currency0).decimals();
        uint256 amount1Out = (fraction1Out *
            poolToReserves[key.toId()].currency1Reserves) /
            10 ** ERC20(currency1).decimals();

        // ERC20(currency0).transfer(sender, amount0Out);
        // ERC20(currency1).transfer(sender, amount1Out);


        poolToReserves[key.toId()].currency0Reserves -= amount0Out;
        poolToReserves[key.toId()].currency1Reserves -= amount1Out;

        poolManager.unlock(
            abi.encode(
                sender,
                key.currency0,
                key.currency1,
                amount0Out,
                amount1Out,
                false
            )
        );

        emit LiquidityRemoved(currency0, currency1, amount0Out, amount1Out);
    }

    function _unlockCallback(
        bytes calldata data
    ) internal virtual override returns (bytes memory) {
        (
            address sender,
            Currency currency0,
            Currency currency1,
            uint256 amount0,
            uint256 amount1,
            bool add
        ) = abi.decode(data, (address, Currency, Currency, uint256, uint256, bool));

        if (add) {
            poolManager.sync(currency0);
            IERC20(Currency.unwrap(currency0)).transferFrom(
                sender,
                address(poolManager),
                amount0
            );
            poolManager.settle();

            poolManager.sync(currency1);
            IERC20(Currency.unwrap(currency1)).transferFrom(
                sender,
                address(poolManager),
                amount1
            );
            poolManager.settle();

            // mint ERC6909 to the hook
            poolManager.mint(address(this), currency0.toId(), amount0);
            poolManager.mint(address(this), currency1.toId(), amount1);
        } else {
            // take what is owed to the hook to the sender
            poolManager.take(currency0, sender, amount0);
            poolManager.take(currency1, sender, amount1);

            poolManager.burn(address(this), currency0.toId(), amount0);
            poolManager.burn(address(this), currency1.toId(), amount1);
        }

        return "";
    }

    /////////////////// Hook Management functions ///////////////////

    /// @notice Adds a stablecoin to the allowed list
    /// @param currency The address of the stablecoin to add
    function addAllowedStablecoin(address currency) external {
        allowedStablecoins[currency] = ERC20(currency);
    }

    /// @notice Removes a stablecoin from the allowed list
    /// @param currency The address of the stablecoin to remove
    function removeAllowedStablecoin(address currency) external {
        allowedStablecoins[currency] = ERC20(address(0));
    }
}
