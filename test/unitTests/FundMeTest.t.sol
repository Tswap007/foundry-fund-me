//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("Tswap"); // Make a user address to run txs so as to make kowing what address calls the tx easier.

    uint256 SEND_VALUE = 1 ether;

    uint256 STARTING_BALANCE = 10 ether;

    uint256 GAS_PRICE = 1;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    receive() external payable {}

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        console.log("owner of the contract is", fundMe.i_owner());
        console.log("Message sender is", msg.sender);
        console.log("contract address is", address(fundMe));
        assertEq(fundMe.i_owner(), msg.sender);
    }

    function testDeal() public {
        vm.deal(address(fundMe), SEND_VALUE); // sending ether to the deployed contract
        uint256 contractBalance = address(fundMe).balance;
        assertEq(contractBalance, SEND_VALUE);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4); //version for mainnet Ethereum is 6 so this test will fail on forkedMainnet
    }

    function testFund() public {
        uint256 balanceOfSender = msg.sender.balance;
        uint256 balanceOfContract = address(fundMe).balance;
        vm.prank(msg.sender);
        fundMe.fund{value: SEND_VALUE}();
        assertEq(
            msg.sender.balance,
            balanceOfSender - SEND_VALUE,
            "Sender balance should decrease by funded amount"
        );
        assertEq(
            address(fundMe).balance,
            balanceOfContract + SEND_VALUE,
            "Contract balance should increase by funded amount"
        );
    }

    function testFundBelowMinimum() public {
        // Simulate the owner calling the fund function
        vm.prank(fundMe.getOwner());

        // Expect revert when funding with below minimum amount
        vm.expectRevert("You need to spend more ETH!");

        // Act: This should revert
        fundMe.fund();
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdraw() public funded {
        uint256 startingOwnerBalance = address(fundMe.getOwner()).balance;
        uint256 startingContractBalance = address(fundMe).balance;

        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        uint256 endingOwnerBalance = address(fundMe.getOwner()).balance;
        uint256 endingContractBalance = address(fundMe).balance;
        assertEq(
            endingOwnerBalance,
            startingOwnerBalance + startingContractBalance
        );
        assertEq(endingContractBalance, 0);
    }

    function testCheaperWithdraw() public funded {
        uint256 startingOwnerBalance = address(fundMe.getOwner()).balance;
        uint256 startingContractBalance = address(fundMe).balance;

        vm.prank(fundMe.getOwner());
        fundMe.cheaperWithdraw();

        uint256 endingOwnerBalance = address(fundMe.getOwner()).balance;
        uint256 endingContractBalance = address(fundMe).balance;
        assertEq(
            endingOwnerBalance,
            startingOwnerBalance + startingContractBalance
        );
        assertEq(endingContractBalance, 0);
    }

    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = address(fundMe.getOwner()).balance;
        uint256 startingContractBalance = address(fundMe).balance;

        // vm.startPrank and stoPrank is just like prank except that it will 
        // exert all txs in the nest as the address put to the start prank 
        vm.startPrank(fundMe.getOwner()); 
        fundMe.withdraw();
        vm.stopPrank();

        uint256 endingOwnerBalance = address(fundMe.getOwner()).balance;
        uint256 endingContractBalance = address(fundMe).balance;
        assertEq(
            endingOwnerBalance,
            startingOwnerBalance + startingContractBalance
        );
        assertEq(endingContractBalance, 0);
    }

    function testFundUpdatesFundedStructure() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        uint256 fundedAmount = fundMe.getAddressToAmountFunded(USER);
        assertEq(fundedAmount, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }
}
