//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";

contract counter is Test {
    uint256 public count = 0;

    function setUp() external {
        count = 0;
    }
}