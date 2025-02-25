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

    error OnlyStablecoins(address currency0, address currency1);
    error AddLiquidityDirectlyToHook();
    error RemoveLiquidityDirectlyFromHook();
    error InsufficientReserves(address currency0, address currency1);
    error ExactOutSwapsNotYetSupported();

    event LiquidityAdded(address indexed currency0, address indexed currency1, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(address indexed currency0, address indexed currency1, uint256 amount0Out, uint256 amount1Out);

    struct PoolReserves {
        uint256 currency0Reserves;
        uint256 currency1Reserves;
    }

    /// @notice Naming convention for uniliquid erc-20 stablecoins
    /// @notice Symbol: ul<stablecoin_symbol>
    /// @notice Name: uniliquid <stablecoin_name>
    /// @notice Example:
    /// @notice     Symbol: ulUSDC
    /// @notice     Name: uniliquidUSDC
    /// @dev the uniliquid erc-20 stablecoin is created if it is allowed, but non-existent yet
    string public constant LIQUID_TOKEN_SYMBOL_PREFIX = "ul";
    string public constant LIQUID_TOKEN_NAME_PREFIX = "Uniliquid";

    /// @notice Initially added amount of both stablecoins to create k. Initial k is thus 100e18
    uint256 public constant AMOUNT_ADDED_INITIALLY = 10e18;
    uint256 public constant NORMALIZED_DECIMALS = 18; // Base decimals for internal calculations
    uint256 public constant FEE_AMOUNT = 3000; // 0.3%

    uint256 private constant MAX_BINARY_ITERATIONS = 30; // a single binary search iteration is approximately 3000 gas (0.0009 USD)
    uint256 private constant ERROR_TOLERANCE = 1e69; // TODO: find out an appropriate tolerance (now k can deviate by 0.01%)

    mapping(address => ERC20) public allowedStablecoins;
    mapping(address => Uniliquid) public tokenToLiquid;
    mapping(PoolId => PoolReserves) public poolToReserves;
    // mapping(PoolId => uint256) public poolToFee;

    bool private reentrancyGuard_ = false;

    modifier onlyStablecoins(Currency currency0, Currency currency1) {
        address currency0Address = Currency.unwrap(currency0);
        address currency1Address = Currency.unwrap(currency1);

        if (allowedStablecoins[currency0Address] == ERC20(address(0)) || allowedStablecoins[currency1Address] == ERC20(address(0))) {
            revert OnlyStablecoins(currency0Address, currency1Address);
        }
        _;
    }   

    modifier reentrancyGuard() {
        if (reentrancyGuard_) {
            revert();
        }
        reentrancyGuard_ = true;
        _;
        reentrancyGuard_ = false;
    }

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

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

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

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

    function _beforeAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) internal override pure returns (bytes4) {
        revert AddLiquidityDirectlyToHook();
    }

    function _beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) internal override pure returns (bytes4) {
        revert RemoveLiquidityDirectlyFromHook();
    }

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

    function addAllowedStablecoin(address currency) external {
        allowedStablecoins[currency] = ERC20(currency);
    }

    function removeAllowedStablecoin(address currency) external {
        allowedStablecoins[currency] = ERC20(address(0));
    }

    /////////////////// Internal functions ///////////////////

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

    function applyFee(uint256 amount) internal pure returns (uint256) {
        return amount * (100000 - FEE_AMOUNT) / 100000;
    }

    /// @notice Computes k for the binary search guess iteration
    function binK(uint256 reserveOut, uint256 guessOut, uint256 reserveInNew) internal pure returns (uint256) {
        uint256 reserveOutNew = reserveOut - guessOut;
        return reserveOutNew * reserveInNew * (reserveOutNew ** 2 + reserveInNew ** 2);
    }

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
