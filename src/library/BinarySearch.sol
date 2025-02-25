// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library BinarySearch {
    function within(uint256 first, uint256 tolerance, uint256 second) internal pure returns (bool) {
        if (first > second) {
            return first - second <= tolerance;
        } else {
            return second - first <= tolerance;
        }
    }
}