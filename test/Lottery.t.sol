// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/EatThePieLottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTGenerator.sol";

contract EatThePieLotteryTest is Test {
    EatThePieLottery public lottery;
    VDFPietrzak public vdf;
    NFTGenerator public nftGenerator;
    address public owner;
    address public player1;
    address public player2;

    function setUp() public {
        owner = address(this);
        player1 = address(0x1);
        player2 = address(0x2);

        vdf = new VDFPietrzak();
        nftGenerator = new NFTGenerator();
        lottery = new EatThePieLottery(address(vdf), 123456789, address(nftGenerator), owner);

        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);
    }

    function testBuyTicket() public {
        uint256[3] memory numbers = [uint256(1), uint256(2), uint256(3)];
        uint256 etherball = 1;

        vm.prank(player1);
        lottery.buyTicket{value: 1 ether}(numbers, etherball);

        // Assuming you've added a getter function to check ticket ownership
        assertTrue(lottery.isTicketOwner(1, player1, numbers, etherball));
    }

    function testInitiateDraw() public {
        // Buy some tickets first
        testBuyTicket();

        // Move time forward to meet the draw interval condition
        vm.warp(block.timestamp + lottery.DRAW_INTERVAL());

        lottery.initiateDraw();

        assertTrue(lottery.gameDrawInitiated(1));
        assertEq(lottery.gameDrawnBlock(1), block.number + lottery.DRAW_BLOCK_OFFSET());
    }

    function testSetRandom() public {
        // First initiate a draw
        testInitiateDraw();

        // Move block number forward
        uint256 targetBlock = lottery.gameDrawnBlock(1);
        vm.roll(targetBlock);

        lottery.setRandom(1);

        assertTrue(lottery.gameRandom(1) != 0);
        assertEq(lottery.gameRandomBlock(1), targetBlock);
    }

    function testSubmitVDFProof() public {
        // Set up the game state for VDF proof submission
        testSetRandom();

        // Create a mock VDF proof (you'll need to implement this based on your VDF logic)
        BigNumbers.BigNumber[] memory v = new BigNumbers.BigNumber[](1);
        v[0] = BigNumbers.BigNumber(1, new uint256[](1));
        BigNumbers.BigNumber memory y = BigNumbers.BigNumber(1, new uint256[](1));

        lottery.submitVDFProof(1, v, y);

        assertTrue(lottery.gameVDFValid(1));
    }

    function testClaimPrize() public {
        // Set up a complete game cycle
        testSubmitVDFProof();

        // Assume player1 won (you might need to manipulate the winning numbers)
        vm.prank(player1);
        uint256 initialBalance = player1.balance;
        lottery.claimPrize(1);

        assertTrue(player1.balance > initialBalance);
        assertTrue(lottery.prizesClaimed(1, player1));
    }

    function testChangeDifficulty() public {
        // Simulate multiple games with no jackpot
        for (uint256 i = 0; i < 10; i++) {
            lottery.initiateDraw();
            vm.warp(block.timestamp + lottery.DRAW_INTERVAL());
            lottery.setRandom(lottery.currentGameNumber());
            // Assume no jackpot won
            lottery.calculatePayouts(lottery.currentGameNumber());
        }

        Difficulty initialDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());
        lottery.changeDifficulty(lottery.currentGameNumber());
        Difficulty newDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());

        assertTrue(uint(newDifficulty) < uint(initialDifficulty));
    }
}