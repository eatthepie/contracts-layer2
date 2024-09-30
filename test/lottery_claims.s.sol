// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Lottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";
import "../src/libraries/BigNumbers.sol";

contract LotteryClaimsTest is Test {
    Lottery public lottery;
    VDFPietrzak public vdf;
    NFTPrize public nftPrize;
    address public owner;
    address public feeRecipient;
    address public player1;
    address public player2;
    address public player3;

    function setUp() public {
        owner = address(this);
        feeRecipient = address(0x123);
        player1 = address(0x456);
        player2 = address(0x789);
        player3 = address(0xABC);
        vdf = new VDFPietrzak();
        nftPrize = new NFTPrize();
        lottery = new Lottery(address(vdf), address(nftPrize), feeRecipient);
    }

    // Helper function to setup a game with winners
    function setupGameWithWinners() internal returns (uint256) {
        // Buy tickets for players
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
        vm.deal(player3, 1 ether);

        vm.prank(player1);
        lottery.buyTicket{value: 0.1 ether}([uint256(1), uint256(2), uint256(3)], 1);
        vm.prank(player2);
        lottery.buyTicket{value: 0.1 ether}([uint256(1), uint256(2), uint256(4)], 1);
        vm.prank(player3);
        lottery.buyTicket{value: 0.1 ether}([uint256(1), uint256(2), uint256(5)], 2);

        uint256 gameNumber = setupDrawAndVDF();

        // Set winning numbers
        lottery.setWinningNumbers(gameNumber, abi.encodePacked(uint256(1), uint256(2), uint256(3), uint256(1)));

        lottery.calculatePayouts(gameNumber);

        return gameNumber;
    }

    // Prize Claiming Tests
    function testClaimPrize() public {
        uint256 gameNumber = setupGameWithWinners();

        uint256 initialBalance = player1.balance;

        vm.prank(player1);
        lottery.claimPrize(gameNumber);

        assertTrue(player1.balance > initialBalance, "Player balance should increase after claiming prize");
        assertTrue(lottery.prizesClaimed(gameNumber, player1), "Prize should be marked as claimed for player1");
    }

    function testClaimPrizeNonWinner() public {
        uint256 gameNumber = setupGameWithWinners();

        vm.prank(player3);
        vm.expectRevert("No prize to claim");
        lottery.claimPrize(gameNumber);
    }

    function testClaimPrizeTwice() public {
        uint256 gameNumber = setupGameWithWinners();

        vm.startPrank(player1);
        lottery.claimPrize(gameNumber);

        vm.expectRevert("Prize already claimed");
        lottery.claimPrize(gameNumber);
        vm.stopPrank();
    }

    function testClaimPrizeBeforeDrawCompleted() public {
        fundLottery();
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();
        uint256 gameNumber = lottery.currentGameNumber() - 1;

        vm.prank(player1);
        vm.expectRevert("Game draw not completed yet");
        lottery.claimPrize(gameNumber);
    }

    function testClaimMultiplePrizes() public {
        uint256 gameNumber = setupGameWithWinners();

        uint256 initialBalance1 = player1.balance;
        uint256 initialBalance2 = player2.balance;

        vm.prank(player1);
        lottery.claimPrize(gameNumber);

        vm.prank(player2);
        lottery.claimPrize(gameNumber);

        assertTrue(player1.balance > initialBalance1, "Player1 balance should increase after claiming prize");
        assertTrue(player2.balance > initialBalance2, "Player2 balance should increase after claiming prize");
        assertTrue(lottery.prizesClaimed(gameNumber, player1), "Prize should be marked as claimed for player1");
        assertTrue(lottery.prizesClaimed(gameNumber, player2), "Prize should be marked as claimed for player2");
    }

    function testDistributeLoyaltyPrize() public {
        uint256 gameNumber = setupGameWithWinners();

        address[] memory winners = new address[](3);
        winners[0] = player1;
        winners[1] = player2;
        winners[2] = player3;

        uint256 initialBalance1 = player1.balance;
        uint256 initialBalance2 = player2.balance;
        uint256 initialBalance3 = player3.balance;

        lottery.distributeLoyaltyPrize(gameNumber, winners);

        assertTrue(player1.balance > initialBalance1, "Player1 balance should increase after loyalty prize distribution");
        assertTrue(player2.balance > initialBalance2, "Player2 balance should increase after loyalty prize distribution");
        assertTrue(player3.balance > initialBalance3, "Player3 balance should increase after loyalty prize distribution");
        assertTrue(lottery.prizesLoyaltyDistributed(gameNumber), "Loyalty prizes should be marked as distributed");
    }

    function testDistributeLoyaltyPrizeTwice() public {
        uint256 gameNumber = setupGameWithWinners();

        address[] memory winners = new address[](3);
        winners[0] = player1;
        winners[1] = player2;
        winners[2] = player3;

        lottery.distributeLoyaltyPrize(gameNumber, winners);

        vm.expectRevert("Loyalty prizes already distributed for this game");
        lottery.distributeLoyaltyPrize(gameNumber, winners);
    }

    function testMintWinningNFT() public {
        uint256 gameNumber = setupGameWithWinners();

        vm.prank(player1);
        lottery.mintWinningNFT(gameNumber);

        assertTrue(lottery.hasClaimedNFT(gameNumber, player1), "Player1 should have claimed NFT");
        assertTrue(nftPrize.balanceOf(player1) > 0, "Player1 should have received an NFT");
    }

    function testMintWinningNFTNonWinner() public {
        uint256 gameNumber = setupGameWithWinners();

        vm.prank(player3);
        vm.expectRevert("Not a gold ticket winner");
        lottery.mintWinningNFT(gameNumber);
    }

    function testMintWinningNFTTwice() public {
        uint256 gameNumber = setupGameWithWinners();

        vm.startPrank(player1);
        lottery.mintWinningNFT(gameNumber);

        vm.expectRevert("NFT already claimed for this game");
        lottery.mintWinningNFT(gameNumber);
        vm.stopPrank();
    }
}