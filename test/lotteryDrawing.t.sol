// ALL PASSED
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Lottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";

contract LotteryDrawingTest is Test {
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

    function fundLottery() internal {
        vm.deal(player, 1000 ether);
        vm.startPrank(player);
        uint256 remainingTickets = 5000;

        while (remainingTickets > 0) {
            uint256 batchSize = remainingTickets > 100 ? 100 : remainingTickets;
            
            uint256[4][] memory tickets = new uint256[4][](batchSize);
            for (uint256 i = 0; i < batchSize; i++) {
                tickets[i] = [uint256(1), uint256(2), uint256(3), uint256(1)];
            }
            
            uint256 batchCost = TICKET_PRICE * batchSize;
            lottery.buyTickets{value: batchCost}(tickets);
            
            remainingTickets -= batchSize;
        }
        
        vm.stopPrank();
    }

    function testInitiateDraw() public {
        // Fund the lottery
        fundLottery();

        // Advance time
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);

        uint256 initialGameNumber = lottery.currentGameNumber();
        uint256 initialTimestamp = block.timestamp;

        vm.expectEmit(true, false, false, true);
        emit Lottery.DrawInitiated(initialGameNumber, block.number + lottery.DRAW_DELAY_SECURITY_BUFFER());

        lottery.initiateDraw();

        assertEq(lottery.currentGameNumber(), initialGameNumber + 1, "Game number should increment");
        assertTrue(lottery.gameDrawInitiated(initialGameNumber), "Draw should be initiated for previous game");
        assertEq(lottery.lastDrawTime(), initialTimestamp, "Last draw time should be updated");
        assertEq(lottery.gameRandomBlock(initialGameNumber), block.number + lottery.DRAW_DELAY_SECURITY_BUFFER(), "Random block should be set correctly");
    }

    function testInitiateDrawTooSoon() public {
        // Fund the lottery
        fundLottery();

        vm.expectRevert("Time interval not passed");
        lottery.initiateDraw();
    }

    function testInitiateDrawInsufficientPrizePool() public {
        // Advance time without funding the lottery
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);

        vm.expectRevert("Insufficient prize pool");
        lottery.initiateDraw();
    }

    function testInitiateDrawMultipleTimes() public {
        // Fund the lottery
        fundLottery();

        // Advance time
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);

        // First draw initiation
        lottery.initiateDraw();

        // Try to initiate draw again without waiting
        vm.expectRevert("Time interval not passed");
        lottery.initiateDraw();

        // Fund the lottery again
        fundLottery();

        // Advance time again
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);

        // Second draw initiation should succeed
        lottery.initiateDraw();
    }

    function testInitiateDrawTicketPriceChange() public {
        // Set a new ticket price
        uint256 newPrice = 0.2 ether;
        lottery.setTicketPrice(newPrice);

        // Fund the lottery and advance time
        fundLottery();
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);

        // Initiate draws until we reach the game where the new price should take effect
        uint256 targetGameNumber = lottery.newTicketPriceGameNumber();
        while (lottery.currentGameNumber() < targetGameNumber - 1) {
            lottery.initiateDraw();
            fundLottery();
            vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        }

        // Initiate one more draw to trigger the price change
        lottery.initiateDraw();

        // Check if the ticket price has changed
        assertEq(lottery.ticketPrice(), newPrice, "Ticket price should have changed");

        // Try to buy a ticket with the new price
        uint256[4][] memory tickets = new uint256[4][](1);
        tickets[0] = [uint256(1), uint256(2), uint256(3), uint256(1)];
        vm.deal(player, newPrice);
        vm.prank(player);
        lottery.buyTickets{value: newPrice}(tickets);

        // Verify the ticket was purchased successfully
        (,, uint256 prizePool,,) = lottery.getCurrentGameInfo();
        assertEq(prizePool, newPrice, "Prize pool should increase by new ticket price");
    }
}