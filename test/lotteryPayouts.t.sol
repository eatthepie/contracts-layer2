// TODO: need to take into account remainder scraps from loyalty distribution that goes to player A

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "./mocks/mockLottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";
import "../src/libraries/BigNumbers.sol";

contract LotteryPayoutTest is Test {
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

    // incorrect payouts
    // function testCalculatePayoutsTwice() public {
    //     fundLottery(5000);
    //     uint256 gameNumber = lottery.currentGameNumber();
    //     setupDrawAndVDF();

    //     lottery.calculatePayouts(gameNumber);
    //     vm.expectRevert("Payouts already calculated for this game");
    //     lottery.calculatePayouts(gameNumber);
    // }

    // function testCalculatePayoutsBeforeVDF() public {
    //     fundLottery(5000);

    //     // Initiate draw but do not submit VDF proof
    //     vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
    //     lottery.initiateDraw();
    //     uint256 gameNumber = lottery.currentGameNumber() - 1;
    //     uint256 targetBlock = lottery.gameRandomBlock(gameNumber);
    //     vm.roll(targetBlock);
    //     vm.prevrandao(bytes32(uint256(51049764388387882260001832746320922162275278963975484447753639501411130604681))); // make prevrandao non-zero
    //     lottery.setRandom(gameNumber);

    //     vm.expectRevert("VDF proof not yet validated for this game");
    //     lottery.calculatePayouts(gameNumber);
    // }

    // fee payouts
    // function testFeeCalculationUnderCapNoWinners() public {
    //     uint256 ticketsToBuy = 9900; // 990 ETH total, 1% fee would be 9.9 ETH
    //     fundLottery(ticketsToBuy);

    //     uint256 gameNumber = lottery.currentGameNumber();
    //     setupDrawAndVDF();

    //     // Set winning numbers for testing
    //     uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
    //     lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

    //     uint256 initialFeeRecipientBalance = feeRecipient.balance;
    //     uint256 prizePool = lottery.gamePrizePool(gameNumber);
    //     lottery.calculatePayouts(gameNumber);

    //     uint256 feeReceived = feeRecipient.balance - initialFeeRecipientBalance;
    //     uint256 expectedFee = (ticketsToBuy * 0.1 ether * lottery.FEE_PERCENTAGE()) / 10000;

    //     assertEq(feeReceived, expectedFee, "Fee should be exactly 1% when under cap");
    //     assertEq(lottery.gamePrizePool(gameNumber + 1), prizePool - feeReceived, "Next game prize pool should be same prize pool minus fee");
    // }

    // function testFeeCalculationAtCapNoWinners() public {
    //     uint256 ticketsToBuy = 110000; // 11,000 ETH total, 1% fee would be 110 ETH, exceeding the 100 ETH cap
    //     vm.pauseGasMetering();
    //     fundLottery(ticketsToBuy);

    //     uint256 gameNumber = lottery.currentGameNumber();
    //     setupDrawAndVDF();

    //     // Set winning numbers for testing
    //     uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
    //     lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

    //     uint256 initialFeeRecipientBalance = feeRecipient.balance;
    //     uint256 prizePool = lottery.gamePrizePool(gameNumber);
    //     lottery.calculatePayouts(gameNumber);

    //     uint256 feeReceived = feeRecipient.balance - initialFeeRecipientBalance;
    //     uint256 expectedFee = lottery.FEE_MAX_IN_ETH();
    //     uint256 expectedExcessFee = (ticketsToBuy * 0.1 ether * lottery.FEE_PERCENTAGE()) / 10000 - expectedFee;

    //     assertEq(feeReceived, expectedFee, "Fee should be capped at FEE_MAX_IN_ETH");
    //     assertEq(
    //         lottery.gamePrizePool(gameNumber + 1),
    //         (prizePool - feeReceived) + expectedExcessFee,
    //         "Excess fee should be added to next game's prize pool"
    //     );
    // }

    // loyalty prize pool payouts
    // function testSingleLoyaltyWinner() public {
    //     fundLottery(5000);
    //     uint256 gameNumber = lottery.currentGameNumber();

    //     // Simulate ticket purchases for bronze winners
    //     vm.prank(player1);
    //     lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));
    //     vm.prank(player2);
    //     lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(4)], uint256(5));
    //     vm.prank(player3);
    //     lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(5)], uint256(5));

    //     // Simulate VDF submission and validation
    //     setupDrawAndVDF();

    //     // Set winning numbers for testing (only first two matter for bronze)
    //     uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
    //     lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

    //     // Calculate payouts
    //     lottery.calculatePayouts(gameNumber);

    //     uint256 loyaltyPrize = lottery.gamePayouts(gameNumber, 3);

    //     // Set different total games played for players
    //     vm.prank(owner);
    //     lottery.setPlayerTotalGamesForTesting(player1, 10);
    //     vm.prank(owner);
    //     lottery.setPlayerTotalGamesForTesting(player2, 5);
    //     vm.prank(owner);
    //     lottery.setPlayerTotalGamesForTesting(player3, 3);

    //     address[] memory bronzeWinners = new address[](3);
    //     bronzeWinners[0] = player1;
    //     bronzeWinners[1] = player2;
    //     bronzeWinners[2] = player3;

    //     uint256 initialBalance1 = player1.balance;
    //     uint256 initialBalance2 = player2.balance;
    //     uint256 initialBalance3 = player3.balance;

    //     lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

    //     assertEq(player1.balance, initialBalance1 + loyaltyPrize, "Player 1 should receive full loyalty prize");
    //     assertEq(player2.balance, initialBalance2, "Player 2 should not receive any prize");
    //     assertEq(player3.balance, initialBalance3, "Player 3 should not receive any prize");
    //     assertTrue(lottery.prizesLoyaltyDistributed(gameNumber), "Loyalty prizes should be marked as distributed");
    // }

    // function testMultipleLoyaltyWinners() internal {
    //     fundLottery(5000);
    //     uint256 gameNumber = lottery.currentGameNumber();

    //     // Simulate ticket purchases for bronze winners
    //     vm.prank(player1);
    //     lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));
    //     vm.prank(player2);
    //     lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(4)], uint256(5));
    //     vm.prank(player3);
    //     lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(5)], uint256(5));

    //     // Simulate VDF submission and validation
    //     setupDrawAndVDF();

    //     // Set winning numbers for testing (only first two matter for bronze)
    //     uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
    //     lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

    //     // Calculate payouts
    //     lottery.calculatePayouts(gameNumber);

    //     uint256 loyaltyPrize = lottery.gamePayouts(gameNumber, 3);

    //     // Set different total games played for players
    //     vm.prank(owner);
    //     lottery.setPlayerTotalGamesForTesting(player1, 10);
    //     vm.prank(owner);
    //     lottery.setPlayerTotalGamesForTesting(player2, 10);
    //     vm.prank(owner);
    //     lottery.setPlayerTotalGamesForTesting(player3, 3);

    //     address[] memory bronzeWinners = new address[](3);
    //     bronzeWinners[0] = player1;
    //     bronzeWinners[1] = player2;
    //     bronzeWinners[2] = player3;

    //     uint256 initialBalance1 = player1.balance;
    //     uint256 initialBalance2 = player2.balance;
    //     uint256 initialBalance3 = player3.balance;

    //     lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

    //     assertEq(player1.balance, initialBalance1 + loyaltyPrize / 2, "Player 1 should receive half the loyalty prize");
    //     assertEq(player2.balance, initialBalance2 + loyaltyPrize / 2, "Player 2 should receive half the loyalty prize");
    //     assertEq(player3.balance, initialBalance3, "Player 3 should not receive any prize");
    //     assertTrue(lottery.prizesLoyaltyDistributed(gameNumber), "Loyalty prizes should be marked as distributed");
    // }

    // function testAllEqualLoyaltyWinners() internal {
    //     fundLottery(5000);
    //     uint256 gameNumber = lottery.currentGameNumber();

    //     // Simulate ticket purchases for bronze winners
    //     vm.prank(player1);
    //     lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4));
    //     vm.prank(player2);
    //     lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(4)], uint256(5));
    //     vm.prank(player3);
    //     lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(5)], uint256(5));

    //     // Simulate VDF submission and validation
    //     setupDrawAndVDF();

    //     // Set winning numbers for testing (only first two matter for bronze)
    //     uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
    //     lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

    //     // Calculate payouts
    //     lottery.calculatePayouts(gameNumber);

    //     uint256 loyaltyPrize = lottery.gamePayouts(gameNumber, 3);

    //     // Set different total games played for players
    //     vm.prank(owner);
    //     lottery.setPlayerTotalGamesForTesting(player1, 10);
    //     vm.prank(owner);
    //     lottery.setPlayerTotalGamesForTesting(player2, 10);
    //     vm.prank(owner);
    //     lottery.setPlayerTotalGamesForTesting(player3, 10);

    //     address[] memory bronzeWinners = new address[](3);
    //     bronzeWinners[0] = player1;
    //     bronzeWinners[1] = player2;
    //     bronzeWinners[2] = player3;

    //     uint256 initialBalance1 = player1.balance;
    //     uint256 initialBalance2 = player2.balance;
    //     uint256 initialBalance3 = player3.balance;

    //     lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

    //     assertEq(player1.balance, initialBalance1 + loyaltyPrize / 3, "Player 1 should receive 1/3 the loyalty prize");
    //     assertEq(player2.balance, initialBalance2 + loyaltyPrize / 3, "Player 2 should receive 1/3 the loyalty prize");
    //     assertEq(player3.balance, initialBalance3 + loyaltyPrize / 3, "Player 3 should receive 1/3 the loyalty prize");
    //     assertTrue(lottery.prizesLoyaltyDistributed(gameNumber), "Loyalty prizes should be marked as distributed");
    // }

    /* Scenario Testing */

    // no winners
    // prize pool - 500ETH
    function testScenarioA() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(12), uint256(12), uint256(13), uint256(14)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        lottery.calculatePayouts(gameNumber);

        // Verify payout information
        uint256 goldPayout = lottery.gamePayouts(gameNumber, 0);
        uint256 silverPayout = lottery.gamePayouts(gameNumber, 1);
        uint256 bronzePayout = lottery.gamePayouts(gameNumber, 2);
        uint256 loyaltyPayout = lottery.gamePayouts(gameNumber, 3);

        assertEq(goldPayout, 0, "Gold prize should be zero");
        assertEq(silverPayout, 0, "Silver prize should be zero");
        assertEq(bronzePayout, 0, "Bronze prize should be zero");
        assertEq(loyaltyPayout, 0, "Loyalty prize should be zero");

        // Check that the prize pool is transferred to the next game
        uint256 nextGamePrizePool = lottery.gamePrizePool(lottery.currentGameNumber());
        uint256 expectedPrizePool = (lottery.DRAW_MIN_PRIZE_POOL() * 9900) / 10000; // Minus 1% fee
        assertApproxEqAbs(nextGamePrizePool, expectedPrizePool, 1e15, "Prize pool should be transferred to next game");
    }

    // 3 winners - 1 jackpot, 1 silver, 1 bronze, 3 loyalty
    // prize pool: 500.3ETH
    function testScenarioB() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        // Simulate ticket purchases
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4)); // Jackpot winning ticket
        vm.prank(player2);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(5)); // Silver winning ticket
        vm.prank(player3);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(4)], uint256(5)); // Bronze winning ticket

        // Simulate VDF submission and validation
        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        // Record balances before payout
        uint256 initialPlayer1Balance = player1.balance;
        uint256 initialPlayer2Balance = player2.balance;
        uint256 initialPlayer3Balance = player3.balance;
        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        // Calculate payouts
        lottery.calculatePayouts(gameNumber);

        // Calculate expected payouts
        uint256 totalPrizePool = 500 ether + (3 * TICKET_PRICE);
        uint256 expectedGoldPrize = (totalPrizePool * lottery.GOLD_PERCENTAGE()) / 10000;
        uint256 expectedSilverPrize = (totalPrizePool * lottery.SILVER_PLACE_PERCENTAGE()) / 10000;
        uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000;
        uint256 expectedLoyaltyPrize = (totalPrizePool * lottery.LOYALTY_PERCENTAGE()) / 10000;
        uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

        if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
            expectedFee = lottery.FEE_MAX_IN_ETH();
        }

        bytes32 goldTicketHash = keccak256(abi.encodePacked(winningNumbers[0], winningNumbers[1], winningNumbers[2], winningNumbers[3]));
        uint256 goldWinners = lottery.goldTicketCounts(gameNumber, goldTicketHash);
        assertEq(goldWinners, 1, "There should be exactly one gold ticket winner");

        bytes32 silverTicketHash = keccak256(abi.encodePacked(winningNumbers[0], winningNumbers[1], winningNumbers[2]));
        uint256 silverWinners = lottery.silverTicketCounts(gameNumber, silverTicketHash);
        assertEq(silverWinners, 2, "There should be exactly two silver ticket winners");

        // Assert game state
        assertTrue(lottery.gameJackpotWon(gameNumber), "Jackpot should be marked as won");
        assertTrue(lottery.gameDrawCompleted(gameNumber), "Game draw should be marked as completed");

        // Verify payout information
        uint256 goldPayout = lottery.gamePayouts(gameNumber, 0);
        uint256 silverPayout = lottery.gamePayouts(gameNumber, 1);
        uint256 bronzePayout = lottery.gamePayouts(gameNumber, 2);
        uint256 loyaltyPayout = lottery.gamePayouts(gameNumber, 3);

        assertEq(goldPayout, expectedGoldPrize, "Stored gold payout incorrect");
        assertEq(silverPayout, expectedSilverPrize / 2, "Stored silver payout incorrect");
        assertEq(bronzePayout, expectedBronzePrize / 3, "Stored bronze payout incorrect");
        assertEq(loyaltyPayout, expectedLoyaltyPrize, "Stored loyalty payout incorrect");

        // Verify ticket counts
        assertEq(lottery.playerTicketCount(player1, gameNumber), 1, "Player 1 ticket count incorrect");
        assertEq(lottery.playerTicketCount(player2, gameNumber), 1, "Player 2 ticket count incorrect");
        assertEq(lottery.playerTicketCount(player3, gameNumber), 1, "Player 3 ticket count incorrect");

        // Claim prizes
        vm.prank(player1);
        lottery.claimPrize(gameNumber);
        vm.prank(player2);
        lottery.claimPrize(gameNumber);
        vm.prank(player3);
        lottery.claimPrize(gameNumber);

        // Assert payouts
        assertEq(player1.balance - initialPlayer1Balance, goldPayout + silverPayout + bronzePayout, "Gold prize payout incorrect");
        assertEq(player2.balance - initialPlayer2Balance, silverPayout + bronzePayout, "Silver prize payout incorrect");
        assertEq(player3.balance - initialPlayer3Balance, bronzePayout, "Bronze and Loyalty prize payout incorrect");
        assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");
        
        // Create an array of bronze winners
        address[] memory bronzeWinners = new address[](3);
        bronzeWinners[0] = player1;
        bronzeWinners[1] = player2;
        bronzeWinners[2] = player3;

        // Record balances before loyalty distribution
        uint256 loyaltyBalancePlayer1 = player1.balance;
        uint256 loyaltyBalancePlayer2 = player2.balance;
        uint256 loyaltyBalancePlayer3 = player3.balance;

        // Distribute loyalty prize
        lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

        // Check if loyalty prize was distributed
        assertTrue(lottery.prizesLoyaltyDistributed(gameNumber), "Loyalty prizes should be marked as distributed");

        // Calculate expected loyalty prize per winner (all should have the same loyalty count in this case)
        uint256 expectedLoyaltyPrizePerWinner = loyaltyPayout / 3;

        // Assert loyalty prize distribution
        assertEq(player1.balance - loyaltyBalancePlayer1, expectedLoyaltyPrizePerWinner, "Player 1 loyalty prize incorrect");
        assertEq(player2.balance - loyaltyBalancePlayer2, expectedLoyaltyPrizePerWinner, "Player 2 loyalty prize incorrect");
        assertEq(player3.balance - loyaltyBalancePlayer3, expectedLoyaltyPrizePerWinner, "Player 3 loyalty prize incorrect");
    }

    // 2 winners - 0 jackpot, 1 silver, 1 bronze, 2 loyalty
    function testScenarioC() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        // Simulate ticket purchases
        vm.prank(player1);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(5)); // Silver winning ticket
        vm.prank(player2);
        lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(4)], uint256(5)); // Bronze winning ticket

        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        // Record balances before payout
        uint256 initialPlayer1Balance = player1.balance;
        uint256 initialPlayer2Balance = player2.balance;
        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        lottery.calculatePayouts(gameNumber);

        // Calculate expected payouts
        uint256 totalPrizePool = 500 ether + (2 * TICKET_PRICE);
        uint256 expectedSilverPrize = (totalPrizePool * lottery.SILVER_PLACE_PERCENTAGE()) / 10000;
        uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000;
        uint256 expectedLoyaltyPrize = (totalPrizePool * lottery.LOYALTY_PERCENTAGE()) / 10000;
        uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

        if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
            expectedFee = lottery.FEE_MAX_IN_ETH();
        }

        // Verify payout information
        assertEq(lottery.gamePayouts(gameNumber, 0), 0, "Gold payout should be zero");
        assertEq(lottery.gamePayouts(gameNumber, 1), expectedSilverPrize, "Stored silver payout incorrect");
        assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize / 2, "Stored bronze payout incorrect");
        assertEq(lottery.gamePayouts(gameNumber, 3), expectedLoyaltyPrize, "Stored loyalty payout incorrect");

        // Claim prizes
        vm.prank(player1);
        lottery.claimPrize(gameNumber);
        vm.prank(player2);
        lottery.claimPrize(gameNumber);

        // Assert payouts
        assertEq(player1.balance - initialPlayer1Balance, expectedSilverPrize + expectedBronzePrize / 2, "Silver prize payout incorrect");
        assertEq(player2.balance - initialPlayer2Balance, expectedBronzePrize / 2, "Bronze prize payout incorrect");
        assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

        // Distribute loyalty prize
        address[] memory bronzeWinners = new address[](2);
        bronzeWinners[0] = player1;
        bronzeWinners[1] = player2;
        lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

        // Assert loyalty prize distribution
        assertEq(player1.balance - initialPlayer1Balance, expectedSilverPrize + expectedBronzePrize / 2 + expectedLoyaltyPrize / 2, "Player 1 total payout incorrect");
        assertEq(player2.balance - initialPlayer2Balance, expectedBronzePrize / 2 + expectedLoyaltyPrize / 2, "Player 2 total payout incorrect");
    }

    // 1 winner - 0 jackpot, 0 silver, 1 bronze, 1 loyalty
    // function testScenarioD() public {
    //     fundLottery(5000);
    //     uint256 gameNumber = lottery.currentGameNumber();

    //     // Simulate ticket purchase
    //     vm.prank(player1);
    //     lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(4)], uint256(5)); // Bronze winning ticket

    //     setupDrawAndVDF();

    //     // Set winning numbers for testing
    //     uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
    //     lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

    //     uint256 initialPlayer1Balance = player1.balance;
    //     uint256 initialFeeRecipientBalance = feeRecipient.balance;

    //     lottery.calculatePayouts(gameNumber);

    //     // Calculate expected payouts
    //     uint256 totalPrizePool = 500 ether + TICKET_PRICE;
    //     uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000;
    //     uint256 expectedLoyaltyPrize = (totalPrizePool * lottery.LOYALTY_PERCENTAGE()) / 10000;
    //     uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

    //     if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
    //         expectedFee = lottery.FEE_MAX_IN_ETH();
    //     }

    //     // Verify payout information
    //     assertEq(lottery.gamePayouts(gameNumber, 0), 0, "Gold payout should be zero");
    //     assertEq(lottery.gamePayouts(gameNumber, 1), 0, "Silver payout should be zero");
    //     assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize, "Stored bronze payout incorrect");
    //     assertEq(lottery.gamePayouts(gameNumber, 3), expectedLoyaltyPrize, "Stored loyalty payout incorrect");

    //     // Claim prize
    //     vm.prank(player1);
    //     lottery.claimPrize(gameNumber);

    //     // Assert payout
    //     assertEq(player1.balance - initialPlayer1Balance, expectedBronzePrize, "Bronze prize payout incorrect");
    //     assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

    //     // Distribute loyalty prize
    //     address[] memory bronzeWinners = new address[](1);
    //     bronzeWinners[0] = player1;
    //     lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

    //     // Assert loyalty prize distribution
    //     assertEq(player1.balance - initialPlayer1Balance, expectedBronzePrize + expectedLoyaltyPrize, "Player 1 total payout incorrect");
    // }

    // 30 winners - 10 jackpot, 10 silver, 10 bronze, 1 loyalty
    // function testScenarioE() public {
    //     fundLottery(5000);
    //     uint256 gameNumber = lottery.currentGameNumber();

    //     // Simulate ticket purchases
    //     for (uint256 i = 0; i < 10; i++) {
    //         vm.prank(address(uint160(i + 1)));
    //         lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(4)); // Jackpot winning ticket
    //     }
    //     for (uint256 i = 10; i < 20; i++) {
    //         vm.prank(address(uint160(i + 1)));
    //         lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(5)); // Silver winning ticket
    //     }
    //     for (uint256 i = 20; i < 30; i++) {
    //         vm.prank(address(uint160(i + 1)));
    //         lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(4)], uint256(5)); // Bronze winning ticket
    //     }

    //     setupDrawAndVDF();

    //     // Set winning numbers for testing
    //     uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
    //     lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

    //     uint256 initialFeeRecipientBalance = feeRecipient.balance;

    //     lottery.calculatePayouts(gameNumber);

    //     // Calculate expected payouts
    //     uint256 totalPrizePool = 500 ether + (30 * TICKET_PRICE);
    //     uint256 expectedGoldPrize = (totalPrizePool * lottery.GOLD_PERCENTAGE()) / 10000 / 10;
    //     uint256 expectedSilverPrize = (totalPrizePool * lottery.SILVER_PLACE_PERCENTAGE()) / 10000 / 10;
    //     uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000 / 10;
    //     uint256 expectedLoyaltyPrize = (totalPrizePool * lottery.LOYALTY_PERCENTAGE()) / 10000;
    //     uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

    //     if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
    //         expectedFee = lottery.FEE_MAX_IN_ETH();
    //     }

    //     // Verify payout information
    //     assertEq(lottery.gamePayouts(gameNumber, 0), expectedGoldPrize, "Stored gold payout incorrect");
    //     assertEq(lottery.gamePayouts(gameNumber, 1), expectedSilverPrize, "Stored silver payout incorrect");
    //     assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize, "Stored bronze payout incorrect");
    //     assertEq(lottery.gamePayouts(gameNumber, 3), expectedLoyaltyPrize, "Stored loyalty payout incorrect");

    //     // Claim prizes for all winners
    //     for (uint256 i = 0; i < 30; i++) {
    //         vm.prank(address(uint160(i + 1)));
    //         lottery.claimPrize(gameNumber);
    //     }

    //     // Assert fee transfer
    //     assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

    //     // Distribute loyalty prize
    //     address[] memory bronzeWinners = new address[](30);
    //     for (uint256 i = 0; i < 30; i++) {
    //         bronzeWinners[i] = address(uint160(i + 1));
    //     }
    //     lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

    //     // Assert loyalty prize distribution (assuming the first player wins the loyalty prize)
    //     assertEq(address(uint160(1)).balance, expectedGoldPrize + expectedSilverPrize + expectedBronzePrize + expectedLoyaltyPrize + TICKET_PRICE, "Loyalty winner payout incorrect");
    // }

    // 100 winners - 0 jackpot, 50 silver, 50 bronze, 3 loyalty
    // function testScenarioF() public {
    //     fundLottery(5000);
    //     uint256 gameNumber = lottery.currentGameNumber();

    //     // Simulate ticket purchases
    //     for (uint256 i = 0; i < 50; i++) {
    //         vm.prank(address(uint160(i + 1)));
    //         lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(3)], uint256(5)); // Silver winning ticket
    //     }
    //     for (uint256 i = 50; i < 100; i++) {
    //         vm.prank(address(uint160(i + 1)));
    //         lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(4)], uint256(5)); // Bronze winning ticket
    //     }

    //     setupDrawAndVDF();

    //     // Set winning numbers for testing
    //     uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
    //     lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

    //     uint256 initialFeeRecipientBalance = feeRecipient.balance;

    //     lottery.calculatePayouts(gameNumber);

    //     // Calculate expected payouts
    //     uint256 totalPrizePool = 500 ether + (100 * TICKET_PRICE);
    //     uint256 expectedSilverPrize = (totalPrizePool * lottery.SILVER_PLACE_PERCENTAGE()) / 10000 / 50;
    //     uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000 / 50;
    //     uint256 expectedLoyaltyPrize = (totalPrizePool * lottery.LOYALTY_PERCENTAGE()) / 10000 / 3;
    //     uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

    //     if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
    //         expectedFee = lottery.FEE_MAX_IN_ETH();
    //     }

    //     // Verify payout information
    //     assertEq(lottery.gamePayouts(gameNumber, 0), 0, "Gold payout should be zero");
    //     assertEq(lottery.gamePayouts(gameNumber, 1), expectedSilverPrize, "Stored silver payout incorrect");
    //     assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize, "Stored bronze payout incorrect");
    //     assertEq(lottery.gamePayouts(gameNumber, 3), expectedLoyaltyPrize * 3, "Stored loyalty payout incorrect");

    //     // Claim prizes for all winners
    //     for (uint256 i = 0; i < 100; i++) {
    //         vm.prank(address(uint160(i + 1)));
    //         lottery.claimPrize(gameNumber);
    //     }

    //     // Assert fee transfer
    //     assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

    //     // Distribute loyalty prize
    //     address[] memory bronzeWinners = new address[](100);
    //     for (uint256 i = 0; i < 100; i++) {
    //         bronzeWinners[i] = address(uint160(i + 1));
    //     }
    //     lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

    //     // Assert loyalty prize distribution (assuming the first 3 players win the loyalty prize)
    //     for (uint256 i = 0; i < 3; i++) {
    //         assertEq(address(uint160(i + 1)).balance, expectedSilverPrize + expectedBronzePrize + expectedLoyaltyPrize + TICKET_PRICE, "Loyalty winner payout incorrect");
    //     }
    // }

    // 150 winners - 0 jackpot, 0 silver, 150 bronze, 15 loyalty
    // function testScenarioG() public {
    //     fundLottery(5000);
    //     uint256 gameNumber = lottery.currentGameNumber();

    //     // Simulate ticket purchases
    //     for (uint256 i = 0; i < 150; i++) {
    //         vm.prank(address(uint160(i + 1)));
    //         lottery.buyTicket{value: TICKET_PRICE}([uint256(1), uint256(2), uint256(4)], uint256(5)); // Bronze winning ticket
    //     }

    //     setupDrawAndVDF();

    //     // Set winning numbers for testing
    //     uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
    //     lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

    //     uint256 initialFeeRecipientBalance = feeRecipient.balance;

    //     lottery.calculatePayouts(gameNumber);

    //     // Calculate expected payouts
    //     uint256 totalPrizePool = 500 ether + (150 * TICKET_PRICE);
    //     uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000 / 150;
    //     uint256 expectedLoyaltyPrize = (totalPrizePool * lottery.LOYALTY_PERCENTAGE()) / 10000 / 15;
    //     uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

    //     if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
    //         expectedFee = lottery.FEE_MAX_IN_ETH();
    //     }

    //     // Verify payout information
    //     assertEq(lottery.gamePayouts(gameNumber, 0), 0, "Gold payout should be zero");
    //     assertEq(lottery.gamePayouts(gameNumber, 1), 0, "Silver payout should be zero");
    //     assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize, "Stored bronze payout incorrect");
    //     assertEq(lottery.gamePayouts(gameNumber, 3), expectedLoyaltyPrize * 15, "Stored loyalty payout incorrect");

    //     // Claim prizes for all winners
    //     for (uint256 i = 0; i < 150; i++) {
    //         vm.prank(address(uint160(i + 1)));
    //         lottery.claimPrize(gameNumber);
    //     }

    //     // Assert fee transfer
    //     assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

    //     // Distribute loyalty prize
    //     address[] memory bronzeWinners = new address[](150);
    //     for (uint256 i = 0; i < 150; i++) {
    //         bronzeWinners[i] = address(uint160(i + 1));
    //     }
    //     lottery.distributeLoyaltyPrize(gameNumber, bronzeWinners);

    //     // Assert loyalty prize distribution (assuming the first 15 players win the loyalty prize)
    //     for (uint256 i = 0; i < 15; i++) {
    //         assertEq(address(uint160(i + 1)).balance, expectedBronzePrize + expectedLoyaltyPrize + TICKET_PRICE, "Loyalty winner payout incorrect");
    //     }

    //     // Assert non-loyalty winners only received bronze prize
    //     for (uint256 i = 15; i < 150; i++) {
    //         assertEq(address(uint160(i + 1)).balance, expectedBronzePrize + TICKET_PRICE, "Non-loyalty winner payout incorrect");
    //     }

    //     // Verify that the game is marked as completed and no jackpot was won
    //     assertTrue(lottery.gameDrawCompleted(gameNumber), "Game draw should be marked as completed");
    //     assertFalse(lottery.gameJackpotWon(gameNumber), "Jackpot should not be marked as won");
    // }
}