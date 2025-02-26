// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

/// @notice Shared constants used in scripts
contract Constants {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    /// @dev populated with deployments from sepolia unichain
    IPoolManager constant POOLMANAGER = IPoolManager(address(0x00B036B58a818B1BC34d502D3fE730Db729e62AC));
    PositionManager constant posm = PositionManager(payable(address(0xf969Aee60879C54bAAed9F3eD26147Db216Fd664)));
}
