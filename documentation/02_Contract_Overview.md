# Smart Contract Overview

## Allowed Stablecoins

Currently, the hook stores the list of allowed stablecoins in a mapping.

```solidity
mapping(address => ERC20) public allowedStablecoins;
```

which can be modified in a centralized fashion by the owner of the hook.

## Pool Initialization

When a pool is created, the hook checks if the pool is a stablecoin-to-stablecoin pool by checking if both assets are in `allowedStablecoins` mapping. If it is, the hook initializes the pool with the initial liquidity.

## Liquidity Provision

Liquidity is provided similarly to a regular Uniswap V2 pool, but with one key difference. LPs do not receive the pool tokens, but instead receive uniliquids in 1:1 proportion to the amount of liquidity they provide.

Example: if a user deposits 1000 USDC and 1000 USDT into the pool, the hook will mint 1000 uniliquid USDC (`1000 ulUSDC`) and 1000 uniliquid USDT (`1000 ulUSDT`) to the user.

## Liquidity Redemption

Uniliquids can be redeemed for the underlying stablecoins at any time. Without loss of generality, the amount of stablecoin `X_s` a user receives when redeeming `X_u` uniliquids is given by the following formula:

$$
X_s = \frac{X_u}{X}
$$

where `X_u` is the amount of uniliquids redeemed, and `X` is the amount of stablecoin in the pool.

Right now, a user can only redeem both stablecoins at the time. In the future, users can be allowed to redeem just a single stablecoin in a Curve-like fashion.

## Swapping

Swapping logic is different from the regular Uniswap V2 logic. Because we use a cubic curve, the isolation of `y` is a complex and floating-point-heavy formula.

Therefore, in order to compute the amount `dy` of stablecoins `Y` a user receives when swapping `dx` of stablecoins `X`, we are using the binary search algorithm to find the correct `dy`, such that the constant product is maintained.

The core logic is the following:

```solidity
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
```

where `computedK` is the currently computed `k` value, with `guessOut` being the current guess of the amount of stablecoins `Y` a user receives when swapping `dx` of stablecoins `X`. `binK` is a function that computes the `k` value according to the `CFMM` formula.

Currently, the `MAX_BINARY_ITERATIONS` is set to 30, and the `ERROR_TOLERANCE` is set to `0.01%`. This means that the constant `k` might deviate by `0.01%` from the actual `k` value, either up or down depending on the direction of the swap. This might sound extreme, but when you consider that constant `k` deviates from the actual `k` by `0.3%` in Uniswap V2 due to fees, it doesn't really matter.
