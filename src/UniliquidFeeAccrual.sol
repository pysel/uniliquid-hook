// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";

contract UniliquidFeeAccrual {
    /// @notice Per-pool fee accrual
    struct PoolFeeAccrual {
        uint256 currency0FeeAccrual;
        uint256 currency1FeeAccrual;
    }

    /// @notice Mapping of pool fee accruals
    mapping(PoolId => PoolFeeAccrual) public poolToFeeAccrual;

    function updateFeeAccrual(PoolId poolId, bool zero, uint256 delta) internal {
        PoolFeeAccrual storage poolFeeAccrual = poolToFeeAccrual[poolId];
        if (zero) {
            poolFeeAccrual.currency0FeeAccrual += delta;
        } else {
            poolFeeAccrual.currency1FeeAccrual += delta;
        }
    }

    function nullifyFeeAccrual(PoolId poolId) internal {
        PoolFeeAccrual storage poolFeeAccrual = poolToFeeAccrual[poolId];
        poolFeeAccrual.currency0FeeAccrual = 0;
        poolFeeAccrual.currency1FeeAccrual = 0;
    }
}