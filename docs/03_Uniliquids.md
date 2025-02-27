# Uniliquids and Fee Tokens

In V2, when a user deposits liquidity into a pool, they receive LP tokens in return. These LP tokens represent a user's share of the pool.

This hook takes a different approach to liquidity provision. Now, when a user deposits liquidity into a pool, they receive uniliquid tokens in return. But in addition to the uniliquids, the user also receives a special per-pool fee token that represents a user's share of the pool's fees.

As a result, the value of an LP token from V2 is now split into three distinct tokens:

1. Uniliquid token X - represents user's stablecoins X in the pool.
2. Uniliquid token Y - represents user's stablecoins Y in the pool.
3. Fee token - represents a user's share of the pool's accrued fees.

## Why fee tokens?

Fee tokens help mitigate a specific attack vector on uniliquid pools. If uniliquids encoded the value of the liquidity in the pool, in addition to the fees, an attacker could create a dummy pool with the same underlying assets as a normal pool, take the uniliquids that represent the value of the dummy pool's liquidity, and due to the composability of the uniliquid token, swap them for the real pool's uniliquids. This would allow the attacker to take the fees from the real pool without providing any liquidity.

By having a separate fee token, the value of the liquidity in the pool is now separated from the value of the fees, mitigating this attack vector.
