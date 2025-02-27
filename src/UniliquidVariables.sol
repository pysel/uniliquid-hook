// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UniliquidVariables {
    /// @notice Error thrown when a non-stablecoin is passed to the hook
    error OnlyStablecoins(address currency0, address currency1);
    /// @notice Error thrown when add liquidity is called through the pool manager (disabled)
    error AddLiquidityDirectlyToHook();
    /// @notice Error thrown when remove liquidity is called through the pool manager (disabled)
    error RemoveLiquidityDirectlyFromHook();
    /// @notice Error thrown when the reserves are insufficient
    error InsufficientReserves(address currency0, address currency1);
    /// @notice Temporary error thrown when amountSpecified is negative (exactOut swaps not yet supported)
    error ExactOutSwapsNotYetSupported();
    /// @notice Error thrown when the normalized deposited liquidity mismatch
    error NormalizedDepositedLiquidityMismatch();
    /// @notice Error thrown when the output amount is less than the minimum amount out
    error SlippageProtection(uint256 amountOut, uint256 minAmountOut);

    /// @notice Event emitted when liquidity is added to the pool
    event LiquidityAdded(address indexed currency0, address indexed currency1, uint256 amount0, uint256 amount1);
    /// @notice Event emitted when liquidity is removed from the pool
    event LiquidityRemoved(
        address indexed currency0, address indexed currency1, uint256 amount0Out, uint256 amount1Out
    );

    /// @notice Per-pool true reserves
    struct PoolReserves {
        uint256 currency0Reserves;
        uint256 currency1Reserves;
    }

    /// @notice Per-pool fee accrual
    struct PoolFeeAccrual {
        uint256 feeAccruedToken0;
        uint256 feeAccruedToken1;
    }

    /* Naming convention for uniliquid erc-20 stablecoins
        Symbol: ul<stablecoin_symbol>
        Name: uniliquid <stablecoin_name>
        Example:
            Symbol: ulUSDC
            Name: uniliquidUSDC
    */

    /// @notice Prefix for the symbol of the uniliquid erc-20 stablecoin
    string public constant LIQUID_TOKEN_SYMBOL_PREFIX = "ul";
    /// @notice Prefix for the name of the uniliquid erc-20 stablecoin
    string public constant LIQUID_TOKEN_NAME_PREFIX = "Uniliquid ";

    /// @notice Fee amount in basis points (0.3%)
    uint256 public constant FEE_AMOUNT = 3000;
}
