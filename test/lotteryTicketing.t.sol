// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Lottery.sol";

contract LotteryTicketingTest is Test {
    Lottery public lottery;
    VDFPietrzak public vdf;
    NFTPrize public nftPrize;
    address owner = address(this);
    address player = address(0x2);
    address feeRecipient = address(0x4);
    uint256 public constant TICKET_PRICE = 0.1 ether;

    function setUp() public {
        vm.startPrank(owner);
        vdf = new VDFPietrzak();
        nftPrize = new NFTPrize();
        lottery = new Lottery(address(vdf), address(nftPrize), feeRecipient);
        vm.stopPrank();
    }

    function packNumbers(uint256[4] memory numbers) internal pure returns (uint32) {
        return uint32(
            (numbers[0] << 24) |
            (numbers[1] << 16) |
            (numbers[2] << 8) |
            numbers[3]
        );
    }

    function testBuyTicket() public {
        uint256[4][] memory tickets = new uint256[4][](1);
        tickets[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];
        uint32 packedNumbers = packNumbers(tickets[0]);

        vm.deal(player, 1 ether);
        vm.startPrank(player);

        vm.expectEmit(true, true, true, true);
        emit Lottery.TicketPurchased(player, 1, [uint256(1), uint256(2), uint256(3)], uint256(4));

        vm.expectEmit(true, true, true, true);
        emit Lottery.TicketsPurchased(player, 1, 1);

        lottery.buyTickets{value: TICKET_PRICE}(tickets);

        vm.stopPrank();

        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, TICKET_PRICE, "Prize pool should increase by ticket price");
        assertEq(player.balance, 1 ether - TICKET_PRICE, "Player's balance should decrease by ticket price");
        assertEq(lottery.playerTicketCount(player, 1), 1, "Player should have 1 ticket for the current game");

        // Check if the ticket is properly recorded using packed numbers
        assertTrue(lottery.ticketOwners(1, packedNumbers, player), 
            "Player should own the gold ticket");
        assertEq(lottery.ticketCounts(1, packedNumbers), 1, 
            "Gold ticket count should be 1");

        assertTrue(lottery.ticketOwners(1, packedNumbers & 0xFFFFFF00, player), 
            "Player should own the silver ticket");
        assertEq(lottery.ticketCounts(1, packedNumbers & 0xFFFFFF00), 1, 
            "Silver ticket count should be 1");

        assertTrue(lottery.ticketOwners(1, packedNumbers & 0xFFFF0000, player), 
            "Player should own the bronze ticket");
        assertEq(lottery.ticketCounts(1, packedNumbers & 0xFFFF0000), 1, 
            "Bronze ticket count should be 1");
    }

    function testBuyTicketInvalidPrice() public {
        uint256[4][] memory tickets = new uint256[4][](1);
        tickets[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];

        vm.deal(player, 1 ether);
        vm.prank(player);
        vm.expectRevert("Incorrect total price");
        lottery.buyTickets{value: 0.05 ether}(tickets);

        // Check that no ticket was purchased
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0, "Prize pool should not increase");
    }

    function testBuyTicketInvalidNumbers() public {
        uint256[4][] memory tickets = new uint256[4][](1);
        tickets[0] = [uint256(0), uint256(2), uint256(3), uint256(4)];

        vm.deal(player, 1 ether);
        vm.prank(player);
        vm.expectRevert("Invalid numbers");
        lottery.buyTickets{value: TICKET_PRICE}(tickets);

        // Check that no ticket was purchased
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0, "Prize pool should not increase");
    }

    function testBuyTicketInvalidEtherball() public {
        uint256[4][] memory tickets = new uint256[4][](1);
        tickets[0] = [uint256(1), uint256(2), uint256(3), uint256(11)];

        vm.deal(player, 1 ether);
        vm.prank(player);
        vm.expectRevert("Invalid numbers");
        lottery.buyTickets{value: TICKET_PRICE}(tickets);

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
        vm.startPrank(player);

        // Expect events for each ticket purchase
        for (uint i = 0; i < tickets.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit Lottery.TicketPurchased(player, 1, [tickets[i][0], tickets[i][1], tickets[i][2]], tickets[i][3]);
        }

        // Expect bulk purchase event
        vm.expectEmit(true, true, true, true);
        emit Lottery.TicketsPurchased(player, 1, 3);

        lottery.buyTickets{value: TICKET_PRICE * 3}(tickets);

        vm.stopPrank();

        // Check prize pool increase
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, TICKET_PRICE * 3, "Prize pool should increase by total ticket price");

        // Check player's balance
        assertEq(player.balance, 1 ether - TICKET_PRICE * 3, "Player's balance should decrease by total ticket price");

        // Check player's ticket count
        assertEq(lottery.playerTicketCount(player, 1), 3, "Player should have 3 tickets for the current game");

        // Check if each ticket is properly recorded
        for (uint i = 0; i < tickets.length; i++) {
            uint32 packedNumbers = packNumbers(tickets[i]);

            assertTrue(lottery.ticketOwners(1, packedNumbers, player), 
                "Player should own the gold ticket");
            assertEq(lottery.ticketCounts(1, packedNumbers), 1, 
                "Gold ticket count should be 1");

            assertTrue(lottery.ticketOwners(1, packedNumbers & 0xFFFFFF00, player), 
                "Player should own the silver ticket");
            assertEq(lottery.ticketCounts(1, packedNumbers & 0xFFFFFF00), 1, 
                "Silver ticket count should be 1");

            assertTrue(lottery.ticketOwners(1, packedNumbers & 0xFFFF0000, player), 
                "Player should own the bronze ticket");
            assertEq(lottery.ticketCounts(1, packedNumbers & 0xFFFF0000), 1, 
                "Bronze ticket count should be 1");
        }
    }

    function testBuyBulkTicketsInvalidAmount() public {
        uint256[4][] memory tickets = new uint256[4][](3);
        tickets[0] = [uint256(1), uint256(2), uint256(3), uint256(1)];
        tickets[1] = [uint256(4), uint256(5), uint256(6), uint256(2)];
        tickets[2] = [uint256(7), uint256(8), uint256(9), uint256(3)];

        vm.deal(player, 1 ether);
        vm.prank(player);
        vm.expectRevert("Incorrect total price");
        lottery.buyTickets{value: TICKET_PRICE * 2}(tickets);

        // Check that no tickets were purchased
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0, "Prize pool should not increase");
    }

    function testBuyBulkTicketsExceedLimit() public {
        uint256[4][] memory tickets = new uint256[4][](101);
        for (uint i = 0; i < 101; i++) {
            tickets[i] = [uint256(1), uint256(2), uint256(3), uint256(1)];
        }

        vm.deal(player, 101 * TICKET_PRICE);
        vm.prank(player);
        vm.expectRevert("Invalid ticket count");
        lottery.buyTickets{value: 101 * TICKET_PRICE}(tickets);

        // Check that no tickets were purchased
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0, "Prize pool should not increase");
    }
}