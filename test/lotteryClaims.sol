// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "./mocks/mockLottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";
import "../src/libraries/BigNumbers.sol";

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
        uint256[3] memory numbers = [uint256(10), uint256(10), uint256(10)];
        uint256 etherball = 1;
        for (uint i = 0; i < ticketCount; i++) {
            lottery.buyTicket{value: 0.1 ether}(numbers, etherball);
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

    // Prize Claiming Tests
    function testClaimPrizeWinner() public {
        fundLottery(5000);
        uint256 initialBalance = player1.balance;

        // Player a buy winning ticket
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        lottery.calculatePayouts(gameNumber);

        vm.prank(player1);
        lottery.claimPrize(gameNumber);

        assertTrue(player1.balance > initialBalance, "Player balance should increase after claiming prize");
        assertTrue(lottery.prizesClaimed(gameNumber, player1), "Prize should be marked as claimed for player1");
    }

    function testClaimPrizeNonWinner() public {
        fundLottery(5000);
        uint256 initialBalance = player1.balance;

        // Player buys a non-winning ticket
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(10), uint256(12), uint256(13)], uint256(2));

        uint256 gameNumber = lottery.currentGameNumber();
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

        // Player a buy winning ticket
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        uint256 gameNumber = lottery.currentGameNumber();
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
        vm.stopPrank();
    }

    function testClaimPrizeBeforePayoutCalculation() public {
        fundLottery(5000);
        uint256 initialBalance = player1.balance;

        // Player a buy winning ticket
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        uint256 gameNumber = lottery.currentGameNumber();
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
        uint256 initialBalance = player1.balance;

        // Player a buy winning ticket
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        // Player b buy winning ticket
        vm.prank(player2);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        uint256 initialBalance1 = player1.balance;
        uint256 initialBalance2 = player2.balance;

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

    function testDistributeLoyaltyPrize() public {
        fundLottery(5000);
        uint256 initialBalance = player1.balance;

        // Player a buy winning ticket
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        // Player b buy winning ticket
        vm.prank(player2);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        // Player b buy winning ticket
        vm.prank(player3);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        lottery.calculatePayouts(gameNumber);

        uint256 initialBalance1 = player1.balance;
        uint256 initialBalance2 = player2.balance;
        uint256 initialBalance3 = player3.balance;

        address[] memory bronzeWinners = new address[](3);
        bronzeWinners[0] = player1;
        bronzeWinners[1] = player2;
        bronzeWinners[2] = player3;

        lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

        assertTrue(player1.balance > initialBalance1, "Player1 balance should increase after loyalty prize distribution");
        assertTrue(player2.balance > initialBalance2, "Player2 balance should increase after loyalty prize distribution");
        assertTrue(player3.balance > initialBalance3, "Player3 balance should increase after loyalty prize distribution");
        assertTrue(lottery.prizesLoyaltyDistributed(gameNumber), "Loyalty prizes should be marked as distributed");
    }

    function testDistributeLoyaltyPrizeTwice() public {
        fundLottery(5000);
        uint256 initialBalance = player1.balance;

        // Player a buy winning ticket
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        // Player b buy winning ticket
        vm.prank(player2);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        // Player b buy winning ticket
        vm.prank(player3);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        lottery.calculatePayouts(gameNumber);

        address[] memory bronzeWinners = new address[](3);
        bronzeWinners[0] = player1;
        bronzeWinners[1] = player2;
        bronzeWinners[2] = player3;

        lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

        vm.expectRevert("Loyalty prizes already distributed for this game");
        lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);
    }

    function testMintWinningNFT() public {
        fundLottery(5000);
        uint256 initialBalance = player1.balance;

        // Player a buy winning ticket
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        lottery.calculatePayouts(gameNumber);

        vm.prank(player1);
        lottery.mintWinningNFT(gameNumber);

        assertTrue(lottery.hasClaimedNFT(gameNumber, player1), "Player1 should have claimed NFT");
        assertTrue(nftPrize.balanceOf(player1) > 0, "Player1 should have received an NFT");
    }

    function testMintWinningNFTNonWinner() public {
        fundLottery(5000);
        uint256 initialBalance = player1.balance;

        // Player a buy winning ticket
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set non-winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(4), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        lottery.calculatePayouts(gameNumber);

        vm.prank(player1);
        vm.expectRevert("Not a gold ticket winner");
        lottery.mintWinningNFT(gameNumber);
    }

    function testMintWinningNFTTwice() public {
        fundLottery(5000);
        uint256 initialBalance = player1.balance;

        // Player a buy winning ticket
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        lottery.calculatePayouts(gameNumber);

        vm.prank(player1);
        lottery.mintWinningNFT(gameNumber);

        vm.prank(player1);
        vm.expectRevert("NFT already claimed for this game");
        lottery.mintWinningNFT(gameNumber);
        vm.stopPrank();
    }
}