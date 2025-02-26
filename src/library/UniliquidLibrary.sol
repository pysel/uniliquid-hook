// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library UniliquidLibrary {
    /// @notice Checks if two numbers are within a tolerance of each other
    /// @param first The first number
    /// @param tolerance The tolerance
    /// @param second The second number
    /// @return True if the numbers are within the tolerance, false otherwise
    function within(uint256 first, uint256 tolerance, uint256 second) internal pure returns (bool) {
        if (first > second) {
            return first - second <= tolerance;
        } else {
            return second - first <= tolerance;
        }
    }

    /// @notice Applies a fee to the amount
    /// @param amount The amount to apply the fee to
    /// @param fee The fee to apply
    /// @return The amount after the fee is applied
    function applyFee(uint256 amount, uint256 fee) internal pure returns (uint256) {
        return (amount * (1000000 - fee)) / 1000000;
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

library CFMMLibrary {
    using UniliquidLibrary for uint256;
    /// @notice Maximum number of binary search iterations for finding the amount out of a swap
    /// @dev Each iteration is worthapproximately 3000 gas (0.0009 USD)

    uint256 public constant MAX_BINARY_ITERATIONS = 30;
    /// @notice Error tolerance for the constant k from the guessed amount out to the true amount out (0.0001%)
    uint256 public constant ERROR_TOLERANCE = 1e12;
    /// @notice Base decimals for internal calculations (in case when stablecoins have different decimals)
    uint256 public constant NORMALIZED_DECIMALS = 18;

    /// @notice Performs a binary search to find the exact amount of a token a user should receive from the swap
    /// @param k The CFMM constant
    /// @param reserveOut The reserve of the token being swapped out
    /// @param reserveIn The reserve of the token being swapped in
    /// @param addedIn The amount of the token being swapped in
    /// @return The amount of the token a user should receive from the swap
    function binarySearchExactIn(uint256 k, uint256 reserveOut, uint256 reserveIn, uint256 addedIn)
        internal
        pure
        returns (uint256)
    {
        uint256 reserveInNew = reserveIn + addedIn;
        // Set initial bounds for binary search
        uint256 left = 0;
        // Upper bound is twice the addedIn amount, because we are trading stablecoins
        uint256 right = addedIn * 2;

        uint256 computedK;
        uint256 guessOut = addedIn;

        for (uint256 i = 0; i < MAX_BINARY_ITERATIONS; ++i) {
            computedK = CFMMLibrary.binK(reserveOut, guessOut, reserveInNew);

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

    /// @notice Computes k for the binary search guess iteration
    /// @dev k = (reserveOut - guessOut) * (reserveInNew) * ((reserveOut - guessOut)**2 + reserveInNew**2)
    /// @param reserveOut The reserve of the token being swapped out
    /// @param guessOut The guess (a binary search one) for the amount of the token being swapped out
    /// @param reserveInNew The reserve of the token being swapped in after the swap
    /// @return The constant k
    function binK(uint256 reserveOut, uint256 guessOut, uint256 reserveInNew) internal pure returns (uint256) {
        uint256 reserveOutNew = reserveOut - guessOut;
        return K(reserveOutNew, reserveInNew);
    }

    /// @notice Computes the constant k from reserves
    /// @dev k = reserveOut * reserveIn
    /// @param reserveOut The amount of currency0 in the pool
    /// @param reserveIn The amount of currency1 in the pool
    /// @return The constant k
    function K(uint256 reserveOut, uint256 reserveIn) internal pure returns (uint256) {
        uint256 denominator = 10 ** NORMALIZED_DECIMALS;

        uint256 xy = (reserveOut * reserveIn) / denominator;
        uint256 x2y2 = (reserveOut * reserveOut + reserveIn * reserveIn) / denominator;

        return xy * x2y2;
    }
}
