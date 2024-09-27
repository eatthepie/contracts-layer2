// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/EatThePieLottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTGenerator.sol";
import "../src/libraries/BigNumbers.sol";

contract EatThePieLotteryTest is Test {
    EatThePieLottery private lottery;
    VDFPietrzak private vdf;
    NFTGenerator private nftGenerator;
    address private feeRecipient;

    address private player1;
    address private player2;
    address private player3;

    function setUp() public {
        // Deploy mock contracts
        vdf = new VDFPietrzak(BigNumber(hex"00c7970ceedcc3b0754490201a7aa613cd73911081c790f5f1a8726f463550bb5b9fd7ccb65812631a5cf503078400000000000000000001def1", 256), 8, 1024);
        nftGenerator = new NFTGenerator();
        feeRecipient = address(0x123);

        // Deploy main contract
        lottery = new EatThePieLottery(address(vdf), hex"00c7970ceedcc3b0754490201a7aa613cd73911081c790f5f1a8726f463550bb5b9fd7ccb65812631a5cf503078400000000000000000001def1", address(nftGenerator), feeRecipient);

        // Setup test accounts
        player1 = address(0x1);
        player2 = address(0x2);
        player3 = address(0x3);

        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);
        vm.deal(player3, 100 ether);
    }

    function testBuyTicket() public {
        vm.prank(player1);
        lottery.buyTicket{value: 0.1 ether}([uint256(1), 2, 3], 4);

        (uint256 gameNumber, , uint256 prizePool, , ) = lottery.getCurrentGameInfo();
        assertEq(gameNumber, 1, "Game number should be 1");
        assertEq(prizePool, 0.1 ether, "Prize pool should be 0.1 ether");
    }

    function testBuyBulkTickets() public {
        uint256[4][] memory tickets = new uint256[4][](3);
        tickets[0] = [uint256(1), 2, 3, 4];
        tickets[1] = [uint256(5), 6, 7, 3];
        tickets[2] = [uint256(8), 9, 10, 2];

        vm.prank(player1);
        lottery.buyBulkTickets{value: 0.3 ether}(tickets);

        (, , uint256 prizePool, , ) = lottery.getCurrentGameInfo();
        assertEq(prizePool, 0.3 ether, "Prize pool should be 0.3 ether");
    }

    function testInitiateDraw() public {
        // Buy some tickets to meet the minimum prize pool
        vm.prank(player1);
        lottery.buyBulkTickets{value: 50 ether}(new uint256[4][](500));

        // Warp time to meet the minimum time period
        vm.warp(block.timestamp + 1 weeks + 1);

        lottery.initiateDraw();

        (uint256 gameNumber, , , , ) = lottery.getCurrentGameInfo();
        assertEq(gameNumber, 2, "Game number should be 2 after draw initiation");
    }

    function testSetRandomAndSubmitVDFProof() public {
        // Setup: Buy tickets and initiate draw
        vm.prank(player1);
        lottery.buyBulkTickets{value: 50 ether}(new uint256[4][](500));
        vm.warp(block.timestamp + 1 weeks + 1);
        lottery.initiateDraw();

        // Set random value
        vm.roll(block.number + 129); // Simulate passing the buffer period
        lottery.setRandom(1);

        // Submit VDF proof (mocked for this test)
        BigNumber[] memory v = new BigNumber[](1);
        v[0] = BigNumber(hex"1234", 16);
        BigNumber memory y = BigNumber(hex"5678", 16);

        // Mock VDF verification to always return true
        vm.mockCall(
            address(vdf),
            abi.encodeWithSelector(VDFPietrzak.verifyPietrzak.selector),
            abi.encode(true)
        );

        lottery.submitVDFProof(1, v, y);

        assertTrue(lottery.gameVDFValid(1), "VDF should be valid for game 1");
    }

    function testCalculatePayouts() public {
        // Setup: Buy tickets, initiate draw, set random, and submit VDF proof
        vm.prank(player1);
        lottery.buyBulkTickets{value: 50 ether}(new uint256[4][](500));
        vm.warp(block.timestamp + 1 weeks + 1);
        lottery.initiateDraw();
        vm.roll(block.number + 129);
        lottery.setRandom(1);

        BigNumber[] memory v = new BigNumber[](1);
        v[0] = BigNumber(hex"1234", 16);
        BigNumber memory y = BigNumber(hex"5678", 16);

        vm.mockCall(
            address(vdf),
            abi.encodeWithSelector(VDFPietrzak.verifyPietrzak.selector),
            abi.encode(true)
        );

        lottery.submitVDFProof(1, v, y);

        // Calculate payouts
        lottery.calculatePayouts(1);

        assertTrue(lottery.gameDrawCompleted(1), "Game 1 draw should be completed");
    }

    function testClaimPrize() public {
        // Setup: Buy tickets, complete a game
        vm.prank(player1);
        lottery.buyBulkTickets{value: 50 ether}(new uint256[4][](500));
        vm.warp(block.timestamp + 1 weeks + 1);
        lottery.initiateDraw();
        vm.roll(block.number + 129);
        lottery.setRandom(1);

        BigNumber[] memory v = new BigNumber[](1);
        v[0] = BigNumber(hex"1234", 16);
        BigNumber memory y = BigNumber(hex"5678", 16);

        vm.mockCall(
            address(vdf),
            abi.encodeWithSelector(VDFPietrzak.verifyPietrzak.selector),
            abi.encode(true)
        );

        lottery.submitVDFProof(1, v, y);
        lottery.calculatePayouts(1);

        // Assume player1 has a winning ticket (you might need to adjust the winning numbers to match a ticket)
        vm.prank(player1);
        lottery.claimPrize(1);

        assertTrue(lottery.prizesClaimed(1, player1), "Player1 should have claimed their prize for game 1");
    }

    function testChangeDifficulty() public {
        // Run multiple games
        for (uint i = 0; i < 4; i++) {
            runOneGame(i % 2 == 0);  // Alternate between games with and without jackpot wins
        }

        // Try to change difficulty for game 5
        lottery.changeDifficulty(5);

        (,EatThePieLottery.Difficulty difficulty,,,) = lottery.getCurrentGameInfo();
        assertTrue(difficulty != EatThePieLottery.Difficulty.Easy, "Difficulty should have changed from Easy");
    }

    function runOneGame(bool shouldHaveJackpotWin) private {
        // Buy tickets
        uint256[4][] memory tickets = new uint256[4][](500);
        for (uint j = 0; j < 500; j++) {
            tickets[j] = [uint256(1), 2, 3, 4];  // All tickets are the same for simplicity
        }
        vm.prank(player1);
        lottery.buyBulkTickets{value: 50 ether}(tickets);

        // If we want a jackpot win, buy one more ticket that will definitely win
        if (shouldHaveJackpotWin) {
            uint256[4][] memory winningTicket = new uint256[4][](1);
            winningTicket[0] = [uint256(5), 6, 7, 8];  // This will be our "winning" ticket
            vm.prank(player2);
            lottery.buyBulkTickets{value: 0.1 ether}(winningTicket);
        }

        // Initiate draw
        vm.warp(block.timestamp + 1 weeks + 1);
        lottery.initiateDraw();

        // Set random
        vm.roll(block.number + 129);
        lottery.setRandom(lottery.currentGameNumber() - 1);

        // Submit VDF proof
        BigNumber[] memory v = new BigNumber[](1);
        v[0] = BigNumber(hex"1234", 16);
        BigNumber memory y = BigNumber(hex"5678", 16);

        vm.mockCall(
            address(vdf),
            abi.encodeWithSelector(VDFPietrzak.verifyPietrzak.selector),
            abi.encode(true)
        );

        // If we want a jackpot win, make sure the "random" output matches our winning ticket
        if (shouldHaveJackpotWin) {
            y = BigNumber(abi.encodePacked(uint256(5), uint256(6), uint256(7), uint256(8)), 128);
        }

        lottery.submitVDFProof(lottery.currentGameNumber() - 1, v, y);

        // Calculate payouts
        lottery.calculatePayouts(lottery.currentGameNumber() - 1);
    }
}