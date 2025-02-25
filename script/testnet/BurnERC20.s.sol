// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

import {Config} from "../base/Config.sol";

/// @notice Burns the ERC20 tokens from the sender
contract BurnERC20Script is Script, Config {
    function setUp() public {}

    function run() public {
        uint256 usdcBalance = usdc.balanceOf(msg.sender);
        uint256 usdtBalance = usdt.balanceOf(msg.sender);

        vm.startBroadcast();
        usdc.transfer(address(0), usdcBalance);
        usdt.transfer(address(0), usdtBalance);
        vm.stopBroadcast();
    }
}
