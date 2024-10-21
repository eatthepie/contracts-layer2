// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "./mocks/mockLottery.sol";

contract LotteryClaimsTest is Test {
    MockLottery public lottery;
    VDFPietrzak public vdf;
    NFTPrize public nftPrize;
    address owner = address(this);
    address player = address(0x2);
    address player1 = address(0x456);
    address player2 = address(0x789);
    address player3 = address(0xABC);
    address feeRecipient = address(0x4);
    uint256 public constant TICKET_PRICE = 0.1 ether;

    function setUp() public {
        vm.startPrank(owner);
        vdf = new VDFPietrzak();
        nftPrize = new NFTPrize();
        lottery = new MockLottery(address(vdf), address(nftPrize), feeRecipient);
        nftPrize.setLotteryContract(address(lottery));
        vm.stopPrank();

        vm.deal(player, 100000 ether);
        vm.deal(player1, 100000 ether);
        vm.deal(player2, 100000 ether);
        vm.deal(player3, 100000 ether);
    }

    function fundLottery(uint256 ticketCount) internal {
        vm.startPrank(player);
        
        uint256 remainingTickets = ticketCount;
        while (remainingTickets > 0) {
            uint256 batchSize = remainingTickets > 100 ? 100 : remainingTickets;
            
            uint256[4][] memory tickets = new uint256[4][](batchSize);
            for (uint256 i = 0; i < batchSize; i++) {
                tickets[i] = [uint256(10), uint256(10), uint256(10), uint256(1)];
            }
            
            uint256 batchCost = TICKET_PRICE * batchSize;
            lottery.buyTickets{value: batchCost}(tickets);
            
            remainingTickets -= batchSize;
        }
        
        vm.stopPrank();
    }

    function setupDrawAndVDF() internal returns (uint256) {
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();
        uint256 gameNumber = lottery.currentGameNumber() - 1;
        uint256 targetBlock = lottery.gameRandomBlock(gameNumber);
        vm.roll(targetBlock);
        vm.prevrandao(bytes32(uint256(51049764388387882260001832746320922162275278963975484447753639501411130604681))); // make prevrandao non-zero
        lottery.setRandom(gameNumber);

        // Mock VDF verification
        vm.mockCall(
            address(vdf),
            abi.encodeWithSelector(VDFPietrzak.verifyPietrzak.selector),
            abi.encode(true)
        );

        BigNumber[] memory v = new BigNumber[](1);
        v[0] = BigNumbers.init(hex"1234");
        BigNumber memory y = BigNumbers.init(hex"5678");

        lottery.submitVDFProof(gameNumber, v, y);

        return gameNumber;
    }

    function testClaimPrizeWinner() public {
        fundLottery(5000);
        uint256 initialBalance = player1.balance;
        uint256 gameNumber = lottery.currentGameNumber();

        // Create and buy a winning ticket
        uint256[4][] memory winningTicket = new uint256[4][](1);
        winningTicket[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];
        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(winningTicket);

        // Setup draw and set winning numbers
        setupDrawAndVDF();
        lottery.setWinningNumbersForTesting(gameNumber, winningTicket[0]);
        lottery.calculatePayouts(gameNumber);

        // Claim prize
        vm.prank(player1);
        lottery.claimPrize(gameNumber);

        // Assert
        uint256 finalBalance = player1.balance;
        assertTrue(
            finalBalance > initialBalance,
            "Player balance should increase after claiming prize"
        );
        assertTrue(
            lottery.prizesClaimed(gameNumber, player1),
            "Prize should be marked as claimed for player1"
        );
    }

    function testClaimPrizeNonWinner() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        // Player buys a non-winning ticket
        uint256[4][] memory nonWinningTicket = new uint256[4][](1);
        nonWinningTicket[0] = [uint256(10), uint256(12), uint256(13), uint256(2)];
        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(nonWinningTicket);

        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        lottery.calculatePayouts(gameNumber);

        vm.prank(player1);
        vm.expectRevert("No prize to claim");
        lottery.claimPrize(gameNumber);
    }

    function testClaimPrizeTwice() public {
        fundLottery(5000);
        uint256 initialBalance = player1.balance;
        uint256 gameNumber = lottery.currentGameNumber();

        // Player buys a winning ticket
        uint256[4][] memory winningTicket = new uint256[4][](1);
        winningTicket[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];
        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(winningTicket);

        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        lottery.calculatePayouts(gameNumber);

        // First claim
        vm.prank(player1);
        lottery.claimPrize(gameNumber);

        // Check that the balance increased after the first claim
        uint256 balanceAfterClaim = player1.balance;
        assertTrue(balanceAfterClaim > initialBalance, "Balance should increase after claiming prize");

        vm.prank(player1);
        vm.expectRevert("Prize already claimed");
        lottery.claimPrize(gameNumber);
    }

    function testClaimPrizeBeforePayoutCalculation() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        // Player buys a winning ticket
        uint256[4][] memory winningTicket = new uint256[4][](1);
        winningTicket[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];
        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(winningTicket);

        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        vm.prank(player1);
        vm.expectRevert("Game draw not completed yet");
        lottery.claimPrize(gameNumber);
    }

    function testClaimMultipleWinners() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        // Create winning ticket
        uint256[4][] memory winningTicket = new uint256[4][](1);
        winningTicket[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];

        // Player1 buys winning ticket
        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(winningTicket);

        // Player2 buys winning ticket
        vm.prank(player2);
        lottery.buyTickets{value: TICKET_PRICE}(winningTicket);

        uint256 initialBalance1 = player1.balance;
        uint256 initialBalance2 = player2.balance;

        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        lottery.calculatePayouts(gameNumber);

        vm.prank(player1);
        lottery.claimPrize(gameNumber);

        vm.prank(player2);
        lottery.claimPrize(gameNumber);

        assertTrue(player1.balance > initialBalance1, "Player1 balance should increase after claiming prize");
        assertTrue(player2.balance > initialBalance2, "Player2 balance should increase after claiming prize");
        assertTrue(lottery.prizesClaimed(gameNumber, player1), "Prize should be marked as claimed for player1");
        assertTrue(lottery.prizesClaimed(gameNumber, player2), "Prize should be marked as claimed for player2");
    }

    // NFT minting
    function testMintWinningNFT() public {
        fundLottery(5000);

        uint256[4][] memory winningTicket = new uint256[4][](1);
        winningTicket[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];
        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(winningTicket);

        uint256 gameNumber = lottery.currentGameNumber();

        setupDrawAndVDF();
        lottery.setWinningNumbersForTesting(gameNumber, winningTicket[0]);
        lottery.calculatePayouts(gameNumber);

        vm.prank(player1);
        lottery.mintWinningNFT(gameNumber);

        assertTrue(lottery.hasClaimedNFT(gameNumber, player1), "Player1 should have claimed NFT");
        assertTrue(nftPrize.balanceOf(player1) > 0, "Player1 should have received an NFT");
    }

    function testMintWinningNFTNonWinner() public {
        fundLottery(5000);

        uint256[4][] memory winningTicket = new uint256[4][](1);
        winningTicket[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];

        uint256[4][] memory nonWinningTicket = new uint256[4][](1);
        nonWinningTicket[0] = [uint256(1), uint256(1), uint256(1), uint256(1)];

        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(nonWinningTicket);

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();
        lottery.setWinningNumbersForTesting(gameNumber, winningTicket[0]);
        lottery.calculatePayouts(gameNumber);

        vm.prank(player1);
        vm.expectRevert("Not a gold ticket winner");
        lottery.mintWinningNFT(gameNumber);
    }

    function testMintWinningNFTTwice() public {
        fundLottery(5000);

        uint256[4][] memory winningTicket = new uint256[4][](1);
        winningTicket[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];

        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(winningTicket);

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();
        lottery.setWinningNumbersForTesting(gameNumber, winningTicket[0]);
        lottery.calculatePayouts(gameNumber);

        vm.prank(player1);
        lottery.mintWinningNFT(gameNumber);

        vm.prank(player1);
        vm.expectRevert("NFT already claimed for this game");
        lottery.mintWinningNFT(gameNumber);
        vm.stopPrank();
    }
}