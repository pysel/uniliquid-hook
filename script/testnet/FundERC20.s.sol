// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

import {Config} from "../base/Config.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

/// @notice Mines the address and deploys the UniliquidHook.sol Hook contract
contract FundERC20Script is Script, Config {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        usdc.transfer(msg.sender, 10e18);
        usdt.transfer(msg.sender, 10e18);
        vm.stopBroadcast();
    }
}
