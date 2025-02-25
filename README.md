# Uniliquid Hook

![Banner!](assets/uniliquids-img.png)

## Table of Contents

- [Introduction](#introduction)
- [Testnet Deployments](#testnet-deployments)
  - [Unichain Sepolia](#unichain-sepolia)
- [Why Stablecoins?](#why-stablecoins)
- [Smart Contract Overview](#smart-contract-overview)
  - [Allowed Stablecoins](#allowed-stablecoins)
  - [Pool Initialization](#pool-initialization)
  - [Liquidity Provision](#liquidity-provision)
  - [Liquidity Redemption](#liquidity-redemption)
  - [Swapping](#swapping)
- [Deploying the Hook](#deploying-the-hook)
- [Future Tasks](#future-tasks)

## Introduction

This is a hook for Uniswap V4 that allows LPs to liquidize their liquidity deposited into stablecoin-to-stablecoin pools. These liquid tokens are called "Uniliquids". The objective of this hook is to provide a way for LPs to provide liquidity to stablecoin-to-stablecoin pools, earning the yield, without losing the access to their liquidity.

Example: if a user deposits 1000 USDC into the pool, the hook will mint a uniliquid USDC (`1000 ulUSDC`) token to this user.

Uniliquids are ERC20 tokens that are pegged to the stablecoin in the pool, thus essentially preserving LPs' liquidity. The price of the uniliquid token is determined by the price of the stablecoin in the pool.

Uniliquids are minted in the ratio of 1:1 with the stablecoin in the pool.

## Testnet Deployments

### Unichain Sepolia

Deployment artifacts:

- Hook: `0x9a67De9e4ac09f3E09C1B7827D333B364a946A80` ([Explorer](https://unichain-sepolia.blockscout.com/address/0x9a67De9e4ac09f3E09C1B7827D333B364a946A80))
- Mock USDC: `0xd6d150D27095Adce6f84FB1CeEc6A00C5F2645F6` ([Explorer](https://unichain-sepolia.blockscout.com/token/0xd6d150D27095Adce6f84FB1CeEc6A00C5F2645F6))
- Mock USDT: `0x92d32Daf42A0B08b275A2D7cbed1CEA2D086a122` ([Explorer](https://unichain-sepolia.blockscout.com/token/0x92d32Daf42A0B08b275A2D7cbed1CEA2D086a122))
- Uniliquid USDC / USDC (see `tokens` section): [Explorer](https://unichain-sepolia.blockscout.com/address/0x2767D3d7A6A266CEEA60C6f603E114F95476D8bB?tab=tokens)
- Swap Example: [Explorer](https://unichain-sepolia.blockscout.com/tx/0x23e6be00f9a7febc57834f60ac0c11b28bc62c979e7ee3a91462e0cde41ab272)

These can also be found in the `broadcast-sepolia` folder.

Example wallet:

![Example wallet](assets/example-wallet.png)

## Why Stablecoins?

Uniswap V4 is built on top of Uniswap V3. Uniswap V3 is a concentrated liquidity protocol that allows LPs to concentrate their liquidity into specific price ranges.

When users deposit liquidity into a V3 pool, they receive an NFT representing their position in the pool. Because each liquidity position is a unique NFT, it is not possible to issue fungible liquid tokens out of these positions.

Therefore, uniliquids are only possible on V2-like pools, where traditionally LPs get pool tokens, which are themselves ERC20 tokens, representing their share of the pool.

As a result, in order for this hook to be competitive, it has to enable a V3-like deepened liquidity experience. In order to do so, this hook operates on a custom `StableSwap`-like curve, which is suitable for trading assets that are expected to have the same price (stablecoins).

The following curve is used:

$$
xy(x^2 + y^2) = k
$$

where `x` is the amount of stablecoin X in the pool, `y` is the amount of stablecoin Y in the pool, and `k` is a constant.

This curve is similar to the `StableSwap` curve, but it is modified to be a cubic curve, which allows for easier trading logic.

A visual representation of the curve can be viewed [here](https://www.desmos.com/calculator/kbo1rjbalx).

The curve acts as a Constant Sum Market Maker (CSMM) when the price of the two assets are close to each other.

When the price of one asset is much lower than the other, the curve acts as a Constant Product Market Maker (CPMM).

## Smart Contract Overview

### Allowed Stablecoins

Currently, the hook stores the list of allowed stablecoins in a mapping.

```solidity
mapping(address => ERC20) public allowedStablecoins;
```

which can be modified in a centralized fashion by the owner of the hook.

### Pool Initialization

When a pool is created, the hook checks if the pool is a stablecoin-to-stablecoin pool by checking if both assets are in `allowedStablecoins` mapping. If it is, the hook initializes the pool with the initial liquidity.

### Liquidity Provision

Liquidity is provided similarly to a regular Uniswap V2 pool, but with one key difference. LPs do not receive the pool tokens, but instead receive uniliquids in 1:1 proportion to the amount of liquidity they provide.

Example: if a user deposits 1000 USDC and 1000 USDT into the pool, the hook will mint 1000 uniliquid USDC (`1000 ulUSDC`) and 1000 uniliquid USDT (`1000 ulUSDT`) to the user.

### Liquidity Redemption

Uniliquids can be redeemed for the underlying stablecoins at any time. Without loss of generality, the amount of stablecoin `X_s` a user receives when redeeming `X_u` uniliquids is given by the following formula:

$$
X_s = \frac{X_u}{X}
$$

where `X_u` is the amount of uniliquids redeemed, and `X` is the amount of stablecoin in the pool.

Right now, a user can only redeem both stablecoins at the time. In the future, users can be allowed to redeem just a single stablecoin in a Curve-like fashion.

### Swapping

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

## Deploying the Hook

First, set all the required `.env` and `script/base` variables. Then, there are two ways to deploy the hook:

1. The quick way: `make deploy-all` (make sure `script/base` is set correctly)
2. The manual way:
    - Deploy the mock tokens: `make deploy-mock-tokens` (Optional)
    - Deploy the hook: `make deploy-hook`
    - Deploy the pool with initial liquidity: `make deploy-pool-with-initial-liquidity`

### Funding the Sender (Optional, only for testing)

To fund the sender with USDC and USDT on Unichain Sepolia, run the following command:

```bash
make fund-me
```

### Basic Swap

To perform a basic swap, run the following command:

```bash
make swap
```

This will perform a swap of 1 USDC to USDT.

## Future Tasks

- [X] Adapt the contract for tokens with different decimals.
- [ ] Add support for exact out swaps.
- [ ] Add support for single-asset redeem.
- [ ] Refactor the code so that there is no need to provide sender address as hook data (swap deltas).
- [ ] Implement slippage protection.
- [X] Fix the bug with the `k` value computation overflow.
