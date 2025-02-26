// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {MockToken} from "../mocks/MockER20.s.sol";

import {Config} from "../base/Config.sol";

/// @notice Burns the ERC20 tokens from the sender
contract BurnERC20Script is Script, Config {
    function setUp() public {}

    function run() public {
        MockToken token1 = MockToken(0x36D2fb606C25A6787070a98184222045090F584C);
        MockToken token2 = MockToken(0x0C0D1983D6D59952bbaf2056980ACA72fb04B8cB);

        uint256 token1Balance = token1.balanceOf(msg.sender);
        uint256 token2Balance = token2.balanceOf(msg.sender);

        vm.startBroadcast();
        token1.transfer(0x00B036B58a818B1BC34d502D3fE730Db729e62AC, token1Balance);
        token2.transfer(0x00B036B58a818B1BC34d502D3fE730Db729e62AC, token2Balance);
        vm.stopBroadcast();
    }
}
