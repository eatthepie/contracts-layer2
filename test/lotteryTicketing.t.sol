// ALL PASSED
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Lottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";

contract LotteryTicketingTest is Test {
    Lottery public lottery;
    VDFPietrzak public vdf;
    NFTPrize public nftPrize;
    address owner = address(this);
    address player = address(0x2);
    address feeRecipient = address(0x4);

    function setUp() public {
        vm.startPrank(owner);
        vdf = new VDFPietrzak();
        nftPrize = new NFTPrize();
        lottery = new Lottery(address(vdf), address(nftPrize), feeRecipient);
        vm.stopPrank();
    }

    function testBuyTicket() public {
        uint256[3] memory numbers = [uint256(1), uint256(2), uint256(3)];
        uint256 etherball = 1;

        vm.deal(player, 1 ether);
        vm.prank(player);

        // Capture the event
        vm.expectEmit(true, true, true, true);
        emit Lottery.TicketPurchased(player, 1, numbers, etherball);

        lottery.buyTicket{value: 0.1 ether}(numbers, etherball);

        // Check prize pool increase
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0.1 ether, "Prize pool should increase by ticket price");

        // Check player's balance
        assertEq(player.balance, 0.9 ether, "Player's balance should decrease by ticket price");
    }

    function testBuyTicketInvalidPrice() public {
        uint256[3] memory numbers = [uint256(1), uint256(2), uint256(3)];
        uint256 etherball = 1;

        vm.deal(player, 1 ether);
        vm.prank(player);
        vm.expectRevert("Incorrect ticket price");
        lottery.buyTicket{value: 0.05 ether}(numbers, etherball);

        // Check that no ticket was purchased
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0, "Prize pool should not increase");
    }

    function testBuyTicketInvalidNumbers() public {
        uint256[3] memory numbers = [uint256(0), uint256(2), uint256(3)];
        uint256 etherball = 1;

        vm.deal(player, 1 ether);
        vm.prank(player);
        vm.expectRevert("Invalid numbers");
        lottery.buyTicket{value: 0.1 ether}(numbers, etherball);

        // Check that no ticket was purchased
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0, "Prize pool should not increase");
    }

    function testBuyTicketInvalidEtherball() public {
        uint256[3] memory numbers = [uint256(1), uint256(2), uint256(3)];
        uint256 etherball = 6; // Assuming max etherball is 5 for Easy difficulty

        vm.deal(player, 1 ether);
        vm.prank(player);
        vm.expectRevert("Invalid numbers");
        lottery.buyTicket{value: 0.1 ether}(numbers, etherball);

        // Check that no ticket was purchased
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0, "Prize pool should not increase");
    }

    function testBuyBulkTickets() public {
        uint256[4][] memory tickets = new uint256[4][](3);
        tickets[0] = [uint256(1), uint256(2), uint256(3), uint256(1)];
        tickets[1] = [uint256(4), uint256(5), uint256(6), uint256(2)];
        tickets[2] = [uint256(7), uint256(8), uint256(9), uint256(3)];

        vm.deal(player, 1 ether);
        vm.prank(player);

        lottery.buyBulkTickets{value: 0.3 ether}(tickets);

        // Check prize pool increase
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0.3 ether, "Prize pool should increase by total ticket price");

        // Check player's balance
        assertEq(player.balance, 0.7 ether, "Player's balance should decrease by total ticket price");
    }

    function testBuyBulkTicketsInvalidAmount() public {
        uint256[4][] memory tickets = new uint256[4][](3);
        tickets[0] = [uint256(1), uint256(2), uint256(3), uint256(1)];
        tickets[1] = [uint256(4), uint256(5), uint256(6), uint256(2)];
        tickets[2] = [uint256(7), uint256(8), uint256(9), uint256(3)];

        vm.deal(player, 1 ether);
        vm.prank(player);
        vm.expectRevert("Incorrect total price");
        lottery.buyBulkTickets{value: 0.2 ether}(tickets);

        // Check that no tickets were purchased
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0, "Prize pool should not increase");
    }

    function testBuyBulkTicketsExceedLimit() public {
        uint256[4][] memory tickets = new uint256[4][](1001); // Assuming max bulk purchase is 1000
        for (uint i = 0; i < 1001; i++) {
            tickets[i] = [uint256(1), uint256(2), uint256(3), uint256(1)];
        }

        vm.deal(player, 101 ether);
        vm.prank(player);
        vm.expectRevert("Invalid ticket count");
        lottery.buyBulkTickets{value: 100.1 ether}(tickets);

        // Check that no tickets were purchased
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0, "Prize pool should not increase");
    }
}
