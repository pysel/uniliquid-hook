// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {console} from "forge-std/console.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {Uniliquid} from "./Uniliquid.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BinarySearch} from "./library/BinarySearch.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {toBeforeSwapDelta, BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";


/// @title UniliquidHook
/// @author Ruslan Akhtariev
/// @notice A hook for creating liquid LP positions on stablecoin pools with a custom AMM implementation (CFMM - xy(x^2 + y^2) = k)
/// @notice The curve graph may be found here: https://www.desmos.com/calculator/kbo1rjbalx
contract UniliquidHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using BinarySearch for uint256;
    using SafeCast for uint256;

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

    /// @notice Event emitted when liquidity is added to the pool
    event LiquidityAdded(address indexed currency0, address indexed currency1, uint256 amount0, uint256 amount1);
    /// @notice Event emitted when liquidity is removed from the pool
    event LiquidityRemoved(address indexed currency0, address indexed currency1, uint256 amount0Out, uint256 amount1Out);

    /// @notice Per-pool true reserves
    struct PoolReserves {
        uint256 currency0Reserves;
        uint256 currency1Reserves;
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

    /// @notice Initially added amount of both stablecoins to create k. Initial k is thus 100e18
    uint256 public constant AMOUNT_ADDED_INITIALLY = 10e18;
    /// @notice Base decimals for internal calculations (in case when stablecoins have different decimals)
    uint256 public constant NORMALIZED_DECIMALS = 18; 
    /// @notice Fee amount in basis points (0.3%)
    uint256 public constant FEE_AMOUNT = 3000; 
    /// @notice Maximum number of binary search iterations for finding the amount out of a swap
    /// @dev Each iteration is worthapproximately 3000 gas (0.0009 USD)
    uint256 private constant MAX_BINARY_ITERATIONS = 30; 
    /// @notice Error tolerance for the constant k from the guessed amount out to the true amount out (0.01%)
    uint256 private constant ERROR_TOLERANCE = 1e69; 

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

        if (allowedStablecoins[currency0Address] == ERC20(address(0)) || allowedStablecoins[currency1Address] == ERC20(address(0))) {
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

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}


    /// @notice The hook permissions:
    /// @notice - beforeInitialize: true
    /// @notice - beforeAddLiquidity: true
    /// @notice - beforeRemoveLiquidity: true
    /// @notice - beforeSwap: true
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
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
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @notice The hook that initializes the pool
    /// @notice During the initialization, the hook creates the uniliquid erc-20 stablecoins if they are allowed, but non-existent yet
    /// @notice Adds the initial liquidity to the pool
    /// @param sender The address of the sender
    /// @param key The pool key
    /// @return Selector of the hook
    function _beforeInitialize(address sender, PoolKey calldata key, uint160) 
        internal 
        override 
        onlyStablecoins(key.currency0, key.currency1)
        returns (bytes4)  
    {
        address currency0 = Currency.unwrap(key.currency0);
        address currency1 = Currency.unwrap(key.currency1);

        // creates a uniliquid erc-20 stablecoin if it is allowed, but non-existent yet
        if (tokenToLiquid[currency0] == Uniliquid(address(0))) {
            string memory symbol = string.concat(LIQUID_TOKEN_SYMBOL_PREFIX, ERC20(currency0).symbol());
            string memory name = string.concat(LIQUID_TOKEN_NAME_PREFIX, ERC20(currency0).name());
            tokenToLiquid[currency0] = new Uniliquid(name, symbol, address(this));
        }

        if (tokenToLiquid[Currency.unwrap(key.currency1)] == Uniliquid(address(0))) {
            string memory symbol = string.concat(LIQUID_TOKEN_SYMBOL_PREFIX, ERC20(currency1).symbol());
            string memory name = string.concat(LIQUID_TOKEN_NAME_PREFIX, ERC20(currency1).name());
            tokenToLiquid[currency1] = new Uniliquid(name, symbol, address(this));
        }

        // Convert AMOUNT_ADDED_INITIALLY to the appropriate decimals for each token
        uint256 amount0 = scaleAmount(AMOUNT_ADDED_INITIALLY, NORMALIZED_DECIMALS, ERC20(currency0).decimals());
        uint256 amount1 = scaleAmount(AMOUNT_ADDED_INITIALLY, NORMALIZED_DECIMALS, ERC20(currency1).decimals());

        addLiquidity(sender, key, currency0, currency1, amount0, amount1);

        return BaseHook.beforeInitialize.selector;
    }

    /// @notice The no-op hook that performs a swap on a custom CFMM curve.
    /// @param key The pool key
    /// @param params The swap parameters
    /// @param data The hook data (the sender address if comes from the swap router)
    /// @return The no-op return
    function _beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata data)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        address sender = abi.decode(data, (address));

        address currency0 = Currency.unwrap(key.currency0);
        address currency1 = Currency.unwrap(key.currency1);

        uint256 reserve0 = poolToReserves[key.toId()].currency0Reserves;
        uint256 reserve1 = poolToReserves[key.toId()].currency1Reserves;

        if (reserve0 == 0 || reserve1 == 0) {
            revert InsufficientReserves(currency0, currency1);
        }

        uint256 k = K(reserve0, reserve1);

        int256 amountInI = params.amountSpecified;
        if (amountInI <= 0) {
            revert ExactOutSwapsNotYetSupported();
        }

        uint256 amountIn = uint256(amountInI); // TODO: change when exactOut is supported

        if (params.zeroForOne) {
            // Normalize input amount
            uint256 normalizedIn = scaleAmount(amountIn, ERC20(currency0).decimals(), NORMALIZED_DECIMALS);
            
            // Calculate output in normalized decimals
            uint256 normalizedOut = binarySearchExactIn(k, reserve1, reserve0, normalizedIn);
            normalizedOut = applyFee(normalizedOut);
            
            // Convert output back to token decimals
            uint256 amountOut = scaleAmount(normalizedOut, NORMALIZED_DECIMALS, ERC20(currency1).decimals());

            ERC20(currency0).transferFrom(sender, address(this), amountIn);
            ERC20(currency1).transfer(sender, amountOut);

            poolToReserves[key.toId()].currency0Reserves += normalizedIn;
            poolToReserves[key.toId()].currency1Reserves -= normalizedOut;
        } else {
            // Similar logic for token1 to token0 swap
            uint256 normalizedIn = scaleAmount(amountIn, ERC20(currency1).decimals(), NORMALIZED_DECIMALS);
            
            uint256 normalizedOut = binarySearchExactIn(k, reserve0, reserve1, normalizedIn);
            normalizedOut = applyFee(normalizedOut);
            
            uint256 amountOut = scaleAmount(normalizedOut, NORMALIZED_DECIMALS, ERC20(currency0).decimals());

            ERC20(currency1).transferFrom(sender, address(this), amountIn);
            ERC20(currency0).transfer(sender, amountOut);

            poolToReserves[key.toId()].currency0Reserves -= normalizedOut;
            poolToReserves[key.toId()].currency1Reserves += normalizedIn;
        }

        return (BaseHook.beforeSwap.selector, toBeforeSwapDelta(amountIn.toInt128(), 0), 0);
    }

    /// @notice The disabled native Uniswap V4 add liquidity functionality
    function _beforeAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) internal override pure returns (bytes4) {
        revert AddLiquidityDirectlyToHook();
    }

    /// @notice The disabled native Uniswap V4 remove liquidity functionality
    function _beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) internal override pure returns (bytes4) {
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
        uint256 normalized0 = scaleAmount(amount0, ERC20(currency0).decimals(), NORMALIZED_DECIMALS);
        uint256 normalized1 = scaleAmount(amount1, ERC20(currency1).decimals(), NORMALIZED_DECIMALS);

        // depositing stablecoins to a pool with different normalized amounts is not allowed
        // TODO: this can actually be allowed, we can compute the correct amount here and return change, if any
        if (normalized0 != normalized1) {
            revert NormalizedDepositedLiquidityMismatch();
        }

        ERC20(currency0).transferFrom(sender, address(this), amount0);
        ERC20(currency1).transferFrom(sender, address(this), amount1);

        // Mint liquid tokens using normalized amounts
        tokenToLiquid[currency0].mint(sender, normalized0);
        tokenToLiquid[currency1].mint(sender, normalized1);

        // Store normalized reserves
        poolToReserves[key.toId()].currency0Reserves += normalized0;
        poolToReserves[key.toId()].currency1Reserves += normalized1;

        emit LiquidityAdded(currency0, currency1, amount0, amount1);
    }

    /// @notice Removes liquidity from the pool
    /// @param sender The address of the sender
    /// @param key The pool key
    /// @param currency0 The address of the first stablecoin
    /// @param currency1 The address of the second stablecoin
    /// @param amount The amount of each token to remove
    function removeLiquidity(address sender, PoolKey calldata key, address currency0, address currency1, uint256 amount)
        external
        onlyStablecoins(Currency.wrap(currency0), Currency.wrap(currency1))
        reentrancyGuard
    {
        tokenToLiquid[currency0].burn(sender, amount);
        tokenToLiquid[currency1].burn(sender, amount);

        uint256 fraction0Out = amount * 10 ** ERC20(currency0).decimals() / poolToReserves[key.toId()].currency0Reserves;
        uint256 fraction1Out = amount * 10 ** ERC20(currency1).decimals() / poolToReserves[key.toId()].currency1Reserves;

        uint256 amount0Out = fraction0Out * poolToReserves[key.toId()].currency0Reserves / 10 ** ERC20(currency0).decimals();
        uint256 amount1Out = fraction1Out * poolToReserves[key.toId()].currency1Reserves / 10 ** ERC20(currency1).decimals();

        ERC20(currency0).transfer(sender, amount0Out);
        ERC20(currency1).transfer(sender, amount1Out);

        poolToReserves[key.toId()].currency0Reserves -= amount0Out;
        poolToReserves[key.toId()].currency1Reserves -= amount1Out;

        emit LiquidityRemoved(currency0, currency1, amount0Out, amount1Out);
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

    /////////////////// Internal functions ///////////////////

    /// @notice Performs a binary search to find the exact amount of a token a user should receive from the swap
    /// @param k The CFMM constant
    /// @param reserveOut The reserve of the token being swapped out
    /// @param reserveIn The reserve of the token being swapped in
    /// @param addedIn The amount of the token being swapped in
    /// @return The amount of the token a user should receive from the swap
    function binarySearchExactIn(uint256 k, uint256 reserveOut, uint256 reserveIn, uint256 addedIn) internal pure returns (uint256) {
        uint256 reserveInNew = reserveIn + addedIn;
        // Set initial bounds for binary search
        uint256 left = 0;
        // Upper bound is twice the addedIn amount, because we are trading stablecoins
        uint256 right = addedIn * 2;

        uint256 computedK;
        uint256 guessOut = addedIn;

        for (uint256 i = 0; i < MAX_BINARY_ITERATIONS; ++i) {
            computedK = binK(reserveOut, guessOut, reserveInNew);

            // Simplified comparison logic
            if (computedK.within(ERROR_TOLERANCE, k)) {
                return guessOut;
            }
            
            uint256 mid = (left + right) / 2;
            if (computedK < k) {
                right = mid;
            } else {
                left = mid;
            }

            guessOut = (left + right) / 2;
        }

        // Return middle value after max iterations
        return (left + right) / 2;
    }

    /// @notice Applies a fee of 0.3% to the amount
    /// @param amount The amount to apply the fee to
    /// @return The amount after the fee is applied
    function applyFee(uint256 amount) internal pure returns (uint256) {
        return amount * (100000 - FEE_AMOUNT) / 100000;
    }

    /// @notice Computes k for the binary search guess iteration
    /// @dev k = (reserveOut - guessOut) * (reserveInNew) * ((reserveOut - guessOut)**2 + reserveInNew**2)
    /// @param reserveOut The reserve of the token being swapped out
    /// @param guessOut The guess (a binary search one) for the amount of the token being swapped out 
    /// @param reserveInNew The reserve of the token being swapped in after the swap
    /// @return The constant k
    function binK(uint256 reserveOut, uint256 guessOut, uint256 reserveInNew) internal pure returns (uint256) {
        uint256 reserveOutNew = reserveOut - guessOut;
        return reserveOutNew * reserveInNew * (reserveOutNew ** 2 + reserveInNew ** 2);
    }

    /// @notice Computes the constant k from reserves
    /// @dev k = reserve0 * reserve1 * (reserve0**2 + reserve1**2)
    /// @param reserve0 The amount of currency0 in the pool
    /// @param reserve1 The amount of currency1 in the pool
    /// @return The constant k
    function K(uint256 reserve0, uint256 reserve1) internal pure returns (uint256) {
        return reserve0 * reserve1 * (reserve0**2 + reserve1**2);
    }

    /// @notice Scales an amount from one decimal precision to another
    /// @param amount The amount to scale
    /// @param fromDecimals The current decimal precision
    /// @param toDecimals The target decimal precision
    /// @return The scaled amount
    function scaleAmount(uint256 amount, uint256 fromDecimals, uint256 toDecimals) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) {
            return amount;
        }
        
        if (fromDecimals > toDecimals) {
            return amount / (10 ** (fromDecimals - toDecimals));
        }
        
        return amount * (10 ** (toDecimals - fromDecimals));
    }
}
