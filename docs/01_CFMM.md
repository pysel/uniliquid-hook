# CFMM Custom Curve

To facilitate the trading of stablecoins, the hooks uses a variant of the `StableSwap` curve.

The curve is defined by the following formula:

$$
xy(x^2 + y^2) = k
$$

where `x` is the amount of stablecoin X in the pool, `y` is the amount of stablecoin Y in the pool, and `k` is a constant from swap to swap.

This curve is similar to the `StableSwap` curve, but it is modified to be a cubic curve, which allows for easier trading logic. A visual representation of the curve can be viewed [here](https://www.desmos.com/calculator/kbo1rjbalx).

The curve acts as a Constant Sum Market Maker (CSMM) when the price of the two assets are close to each other. When the price of one asset is much lower than the other, the curve acts as a Constant Product Market Maker (CPMM).
