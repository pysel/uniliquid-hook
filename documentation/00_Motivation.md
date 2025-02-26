# Motivation

In this document, we will discuss the motivation for having a hook that allows LPs to liquidize their liquidity in Uniswap V4.

## Problem

Right now, when users deposit liquidity into the Uniswap Protocol, their liquidity remains locked in the pool until they decide to remove it. As a result, it is not usable outside of the protocol, making LPs illiquid. If an LP decides to withdraw their liquidity from the pool, they are subject to paying the network gas fees for the removal.

## Solution

In order to mitigate the problem of illiquidity and withdrawal costs, this hooks introduces a new concept of "Uniliquids". Uniliquids are tokens that represent a user's liquidity in a stablecoin-to-stablecoin pool. They are minted by depositing the stablecoin pair into the pool and receiving the Uniliquid tokens 1:1 in return.

Normally, if a user wishes to withdraw their liquidity from the pool, they would first need to initiate a withdrawal transaction to unlock their liquidity, and then transact with the unlocked liquidity. For example, if a user has liquidity locked in a USDC-USDT pool, they would first need to convert their LP tokens into the underlying stablecoins, and then initiate further transactions with the unlocked liquidity (for example, by buying some ETH).

With uniliquids, the process is much simpler. If a user wishes to withdraw their liquidity from the pool, they can simply swap their Uniliquid tokens for the ETH, directly, without the withdrawal transaction. This simplifies both the process and the costs of managing LP liquidity.

## Stablecoin Resemblance

Uniliquids are "almost" stablecoins themselves. They are not fully pegged to the price of the stablecoin only because their prices reflect not only the price of the underlying stablecoin, but also the current and future value of the LPs' fees. The most similar concept to Uniliquids is Rocket Pool's rETH. rETH is not pegged to the price of ETH, because its price is constanty updated due to the staking rewards.

## Possible FAQs

1.**Normal LP tokens in protocols as Uniswap V2 and Curve are liquid, why is this any different?**

Normal LP tokens are pool specific. If there exist two pools with USDT in it, for example USDT-DAI and USDT-USDC, there exist two different LP tokens, USDT-DAI-LP and USDT-USDC-LP. It would be possible to convert between them, but because of the fact that they are tightly coupled to the specific pool, the conversion can become complex, and the process can be costly.

Uniliquids from two different pools are exactly the same token. If you have deposit 100 USDT into USDT-DAI pool and 100 USDT into USDT-USDC pool, you will receive 200 ulUSDT in total, which is a huge composability advantage.

2.**Why only stablecoin-to-stablecoin pools?**

Uniswap V4 is built on top of Uniswap V3. Uniswap V3 is a concentrated liquidity protocol that allows LPs to concentrate their liquidity into specific price ranges.

When users deposit liquidity into a V3 pool, they receive an NFT representing their position in the pool. Because each liquidity position is a unique NFT, it is not possible to issue fungible liquid tokens out of these positions.

Therefore, uniliquids are only possible on V2-like pools, where traditionally LPs get pool tokens, which are themselves ERC20 tokens, representing their share of the pool.

As a result, in order for this hook to be competitive with the deep liquidity of Uniswap V3, it has to introduce a V3-like deepened liquidity experience. In order to do so, this hook operates on a custom `StableSwap`-like curve, which is suitable for trading assets that are expected to have the same price (stablecoins).

3.**So, is it possible to create Uniliquids for non-stablecoin pairs?**

Yes, it is possible to create Uniliquids for non-stablecoin pairs. The only difference is the underlying curve that is used, because you should not use a `StableSwap`-like curve for non-stablecoin pairs.
