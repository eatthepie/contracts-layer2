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

    function wrapTicket(uint256[4] memory ticket) internal pure returns (uint256[4][] memory) {
        uint256[4][] memory wrappedTicket = new uint256[4][](1);
        wrappedTicket[0] = ticket;
        return wrappedTicket;
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

    // incorrect payouts
    function testCalculatePayoutsTwice() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        lottery.calculatePayouts(gameNumber);
        vm.expectRevert("Payouts already calculated for this game");
        lottery.calculatePayouts(gameNumber);
    }

    function testCalculatePayoutsBeforeVDF() public {
        fundLottery(5000);

        // Initiate draw but do not submit VDF proof
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();
        uint256 gameNumber = lottery.currentGameNumber() - 1;
        uint256 targetBlock = lottery.gameRandomBlock(gameNumber);
        vm.roll(targetBlock);
        vm.prevrandao(bytes32(uint256(51049764388387882260001832746320922162275278963975484447753639501411130604681))); // make prevrandao non-zero
        lottery.setRandom(gameNumber);

        vm.expectRevert("VDF proof not yet validated for this game");
        lottery.calculatePayouts(gameNumber);
    }

    // fee payouts
    function testFeeCalculationUnderCapNoWinners() public {
        uint256 ticketsToBuy = 9900; // 990 ETH total, 1% fee would be 9.9 ETH
        fundLottery(ticketsToBuy);

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        uint256 initialFeeRecipientBalance = feeRecipient.balance;
        uint256 prizePool = lottery.gamePrizePool(gameNumber);
        lottery.calculatePayouts(gameNumber);

        uint256 feeReceived = feeRecipient.balance - initialFeeRecipientBalance;
        uint256 expectedFee = (ticketsToBuy * 0.1 ether * lottery.FEE_PERCENTAGE()) / 10000;

        assertEq(feeReceived, expectedFee, "Fee should be exactly 1% when under cap");
        assertEq(lottery.gamePrizePool(gameNumber + 1), prizePool - feeReceived, "Next game prize pool should be same prize pool minus fee");
    }

    function testFeeCalculationAtCapNoWinners() public {
        uint256 ticketsToBuy = 110000; // 11,000 ETH total, 1% fee would be 110 ETH, exceeding the 100 ETH cap
        vm.pauseGasMetering();
        fundLottery(ticketsToBuy);

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        uint256 initialFeeRecipientBalance = feeRecipient.balance;
        uint256 prizePool = lottery.gamePrizePool(gameNumber);
        lottery.calculatePayouts(gameNumber);

        uint256 feeReceived = feeRecipient.balance - initialFeeRecipientBalance;
        uint256 expectedFee = lottery.FEE_MAX_IN_ETH();
        uint256 expectedExcessFee = (ticketsToBuy * 0.1 ether * lottery.FEE_PERCENTAGE()) / 10000 - expectedFee;

        assertEq(feeReceived, expectedFee, "Fee should be capped at FEE_MAX_IN_ETH");
        assertEq(
            lottery.gamePrizePool(gameNumber + 1),
            (prizePool - feeReceived) + expectedExcessFee,
            "Excess fee should be added to next game's prize pool"
        );
    }

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

        assertEq(goldPayout, 0, "Gold prize should be zero");
        assertEq(silverPayout, 0, "Silver prize should be zero");
        assertEq(bronzePayout, 0, "Bronze prize should be zero");

        // Check that the prize pool is transferred to the next game
        uint256 nextGamePrizePool = lottery.gamePrizePool(lottery.currentGameNumber());
        uint256 expectedPrizePool = (lottery.DRAW_MIN_PRIZE_POOL() * 9900) / 10000; // Minus 1% fee
        assertApproxEqAbs(nextGamePrizePool, expectedPrizePool, 1e15, "Prize pool should be transferred to next game");
    }

    // 3 winners - 1 jackpot, 1 silver, 1 bronze
    // prize pool: 500.3ETH
    function testScenarioB() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        // Define ticket numbers
        uint256[4] memory goldNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        uint256[4] memory silverNumbers = [uint256(1), uint256(2), uint256(3), uint256(5)];
        uint256[4] memory bronzeNumbers = [uint256(1), uint256(2), uint256(4), uint256(5)];

        // Buy winning tickets
        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket(goldNumbers));
        vm.prank(player2);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket(silverNumbers));
        vm.prank(player3);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket(bronzeNumbers));

        // Record initial balances
        uint256 initialPlayer1Balance = player1.balance;
        uint256 initialPlayer2Balance = player2.balance;
        uint256 initialPlayer3Balance = player3.balance;
        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        // Run game and set winning numbers
        setupDrawAndVDF();
        lottery.setWinningNumbersForTesting(gameNumber, goldNumbers);
        lottery.calculatePayouts(gameNumber);

        // Calculate expected payouts
        uint256 totalPrizePool = 500 ether + (3 * TICKET_PRICE);
        uint256 expectedGoldPrize = (totalPrizePool * lottery.GOLD_PERCENTAGE()) / 10000;
        uint256 expectedSilverPrize = (totalPrizePool * lottery.SILVER_PLACE_PERCENTAGE()) / 10000;
        uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000;
        uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;
        if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
            expectedFee = lottery.FEE_MAX_IN_ETH();
        }

        // Verify winner counts
        bytes32 goldTicketHash = keccak256(abi.encodePacked(goldNumbers[0], goldNumbers[1], goldNumbers[2], goldNumbers[3]));
        bytes32 silverTicketHash = keccak256(abi.encodePacked(goldNumbers[0], goldNumbers[1], goldNumbers[2]));
        bytes32 bronzeTicketHash = keccak256(abi.encodePacked(goldNumbers[0], goldNumbers[1]));

        assertEq(lottery.goldTicketCounts(gameNumber, goldTicketHash), 1, "There should be exactly one gold ticket winner");
        assertEq(lottery.silverTicketCounts(gameNumber, silverTicketHash), 2, "There should be exactly two silver ticket winners");
        assertEq(lottery.bronzeTicketCounts(gameNumber, bronzeTicketHash), 3, "There should be exactly three bronze ticket winners");

        // Assert game state
        assertTrue(lottery.gameDrawCompleted(gameNumber), "Game draw should be marked as completed");

        // Verify payout information
        uint256 goldPayout = lottery.gamePayouts(gameNumber, 0);
        uint256 silverPayout = lottery.gamePayouts(gameNumber, 1);
        uint256 bronzePayout = lottery.gamePayouts(gameNumber, 2);

        assertEq(goldPayout, expectedGoldPrize, "Stored gold payout incorrect");
        assertEq(silverPayout, expectedSilverPrize / 2, "Stored silver payout incorrect");
        assertEq(bronzePayout, expectedBronzePrize / 3, "Stored bronze payout incorrect");

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
        assertEq(player3.balance - initialPlayer3Balance, bronzePayout, "Bronze prize payout incorrect");
        assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");
    }

    // 2 winners - 0 jackpot, 1 silver, 1 bronze
    function testScenarioC() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        // Define ticket numbers
        uint256[4] memory silverTicket = [uint256(1), uint256(2), uint256(3), uint256(5)];
        uint256[4] memory bronzeTicket = [uint256(1), uint256(2), uint256(4), uint256(5)];

        // Buy tickets for players
        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket(silverTicket)); // Silver winning ticket
        vm.prank(player2);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket(bronzeTicket)); // Bronze winning ticket

        // Record balances before payout
        uint256 initialPlayer1Balance = player1.balance;
        uint256 initialPlayer2Balance = player2.balance;
        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        // Run game and set winning numbers
        setupDrawAndVDF();
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
        lottery.calculatePayouts(gameNumber);

        // Calculate expected payouts
        uint256 totalPrizePool = 500 ether + (2 * TICKET_PRICE);
        uint256 expectedSilverPrize = (totalPrizePool * lottery.SILVER_PLACE_PERCENTAGE()) / 10000;
        uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000;
        uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

        if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
            expectedFee = lottery.FEE_MAX_IN_ETH();
        }

        // Verify payout information
        assertEq(lottery.gamePayouts(gameNumber, 0), 0, "Gold payout should be zero");
        assertEq(lottery.gamePayouts(gameNumber, 1), expectedSilverPrize, "Stored silver payout incorrect");
        assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize / 2, "Stored bronze payout incorrect");

        // Verify ticket counts
        assertEq(lottery.playerTicketCount(player1, gameNumber), 1, "Player 1 ticket count incorrect");
        assertEq(lottery.playerTicketCount(player2, gameNumber), 1, "Player 2 ticket count incorrect");

        // Claim prizes
        vm.prank(player1);
        lottery.claimPrize(gameNumber);
        vm.prank(player2);
        lottery.claimPrize(gameNumber);

        // Assert payouts
        assertEq(player1.balance - initialPlayer1Balance, expectedSilverPrize + expectedBronzePrize / 2, "Silver prize payout incorrect");
        assertEq(player2.balance - initialPlayer2Balance, expectedBronzePrize / 2, "Bronze prize payout incorrect");
        assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

        // Verify game state
        assertTrue(lottery.gameDrawCompleted(gameNumber), "Game draw should be marked as completed");
        assertTrue(lottery.prizesClaimed(gameNumber, player1), "Prize should be marked as claimed for player1");
        assertTrue(lottery.prizesClaimed(gameNumber, player2), "Prize should be marked as claimed for player2");
    }

    // 1 winner - 0 jackpot, 0 silver, 1 bronze
    function testScenarioD() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        // Define ticket numbers
        uint256[4] memory bronzeTicket = [uint256(1), uint256(2), uint256(4), uint256(5)];

        // Buy ticket for player
        vm.prank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket(bronzeTicket)); // Bronze winning ticket

        // Record balances before payout
        uint256 initialPlayer1Balance = player1.balance;
        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        // Set winning numbers for testing
        setupDrawAndVDF();
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
        lottery.calculatePayouts(gameNumber);

        // Calculate expected payouts
        uint256 totalPrizePool = 500 ether + TICKET_PRICE;
        uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000;
        uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

        if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
            expectedFee = lottery.FEE_MAX_IN_ETH();
        }

        // Verify payout information
        assertEq(lottery.gamePayouts(gameNumber, 0), 0, "Gold payout should be zero");
        assertEq(lottery.gamePayouts(gameNumber, 1), 0, "Silver payout should be zero");
        assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize, "Stored bronze payout incorrect");

        // Verify ticket count
        assertEq(lottery.playerTicketCount(player1, gameNumber), 1, "Player 1 ticket count incorrect");

        // Claim prize
        vm.prank(player1);
        lottery.claimPrize(gameNumber);

        // Assert payout
        assertEq(player1.balance - initialPlayer1Balance, expectedBronzePrize, "Bronze prize payout incorrect");
        assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

        // Verify game state
        assertTrue(lottery.gameDrawCompleted(gameNumber), "Game draw should be marked as completed");
        assertTrue(lottery.prizesClaimed(gameNumber, player1), "Prize should be marked as claimed for player1");
    }

    // 15 winners - 5 jackpot, 5 silver, 5 bronze
    function testScenarioE() public {
        vm.pauseGasMetering();
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        address[] memory players = new address[](15);
        for (uint256 i = 0; i < 15; i++) {
            players[i] = address(uint160(uint256(keccak256(abi.encodePacked("player", i)))));
        }

        // Prepare ticket data
        uint256[4][] memory jackpotTickets = new uint256[4][](1);
        jackpotTickets[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];

        uint256[4][] memory silverTickets = new uint256[4][](1);
        silverTickets[0] = [uint256(1), uint256(2), uint256(3), uint256(5)];

        uint256[4][] memory bronzeTickets = new uint256[4][](1);
        bronzeTickets[0] = [uint256(1), uint256(2), uint256(4), uint256(5)];

        // Simulate ticket purchases
        for (uint256 i = 0; i < 15; i++) {
            vm.deal(players[i], 100000 ether);
            vm.prank(players[i]);

            if (i < 5) {
                lottery.buyTickets{value: TICKET_PRICE}(jackpotTickets);
            } else if (i < 10) {
                lottery.buyTickets{value: TICKET_PRICE}(silverTickets);
            } else {
                lottery.buyTickets{value: TICKET_PRICE}(bronzeTickets);
            }
        }

        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        lottery.calculatePayouts(gameNumber);

        // Calculate expected payouts
        uint256 totalPrizePool = 500 ether + (15 * TICKET_PRICE);
        uint256 expectedGoldPrize = (totalPrizePool * lottery.GOLD_PERCENTAGE()) / 10000 / 5;
        uint256 expectedSilverPrize = (totalPrizePool * lottery.SILVER_PLACE_PERCENTAGE()) / 10000 / 10;
        uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000 / 15;
        uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

        if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
            expectedFee = lottery.FEE_MAX_IN_ETH();
        }

        // Verify payout information
        assertEq(lottery.gamePayouts(gameNumber, 0), expectedGoldPrize, "Stored gold payout incorrect");
        assertEq(lottery.gamePayouts(gameNumber, 1), expectedSilverPrize, "Stored silver payout incorrect");
        assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize, "Stored bronze payout incorrect");

        // Claim prizes for all winners and verify balances
        for (uint256 i = 0; i < 15; i++) {
            address player = players[i];
            uint256 initialBalance = player.balance;
            vm.prank(player);
            lottery.claimPrize(gameNumber);
            
            uint256 expectedPrize;
            if (i < 5) {
                expectedPrize = expectedGoldPrize + expectedSilverPrize + expectedBronzePrize;
            } else if (i < 10) {
                expectedPrize = expectedSilverPrize + expectedBronzePrize;
            } else {
                expectedPrize = expectedBronzePrize;
            }
            
            assertEq(player.balance - initialBalance, expectedPrize, "Prize payout incorrect for player");
        }

        // Assert fee transfer
        assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

        // Verify game state
        assertTrue(lottery.gameDrawCompleted(gameNumber), "Game draw should be marked as completed");
        for (uint256 i = 0; i < 15; i++) {
            address player = players[i];
            assertTrue(lottery.prizesClaimed(gameNumber, player), "Prize should be marked as claimed for player");
        }
    }

    // 100 winners - 0 jackpot, 50 silver, 50 bronze
    function testScenarioF() public {
        vm.pauseGasMetering();
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        address[] memory players = new address[](100);
        for (uint256 i = 0; i < 100; i++) {
            players[i] = address(uint160(uint256(keccak256(abi.encodePacked("player", i)))));
        }

        // Prepare ticket data
        uint256[4][] memory silverTickets = new uint256[4][](1);
        silverTickets[0] = [uint256(1), uint256(2), uint256(3), uint256(5)];

        uint256[4][] memory bronzeTickets = new uint256[4][](1);
        bronzeTickets[0] = [uint256(1), uint256(2), uint256(4), uint256(5)];

        // Simulate ticket purchases
        for (uint256 i = 0; i < 100; i++) {
            vm.deal(players[i], 100000 ether);
            vm.prank(players[i]);

            if (i < 50) {
                lottery.buyTickets{value: TICKET_PRICE}(silverTickets);
            } else {
                lottery.buyTickets{value: TICKET_PRICE}(bronzeTickets);
            }
        }

        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        lottery.calculatePayouts(gameNumber);

        // Calculate expected payouts
        uint256 totalPrizePool = 500 ether + (100 * TICKET_PRICE);
        uint256 expectedSilverPrize = (totalPrizePool * lottery.SILVER_PLACE_PERCENTAGE()) / 10000 / 50;
        uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000 / 100;
        uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

        if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
            expectedFee = lottery.FEE_MAX_IN_ETH();
        }

        // Verify payout information
        assertEq(lottery.gamePayouts(gameNumber, 0), 0, "Stored gold payout should be zero");
        assertEq(lottery.gamePayouts(gameNumber, 1), expectedSilverPrize, "Stored silver payout incorrect");
        assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize, "Stored bronze payout incorrect");

        // Claim prizes for all winners and verify balances
        for (uint256 i = 0; i < 100; i++) {
            address player = players[i];
            uint256 initialBalance = player.balance;
            vm.prank(player);
            lottery.claimPrize(gameNumber);
            
            uint256 expectedPrize;
            if (i < 50) {
                expectedPrize = expectedSilverPrize + expectedBronzePrize;
            } else {
                expectedPrize = expectedBronzePrize;
            }
            
            assertEq(player.balance - initialBalance, expectedPrize, "Prize payout incorrect for player");
        }

        // Assert fee transfer
        assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

        // Verify game state
        assertTrue(lottery.gameDrawCompleted(gameNumber), "Game draw should be marked as completed");
        for (uint256 i = 0; i < 100; i++) {
            address player = players[i];
            assertTrue(lottery.prizesClaimed(gameNumber, player), "Prize should be marked as claimed for player");
        }
    }

    // 150 winners - 0 jackpot, 0 silver, 150 bronze
    function testScenarioG() public {
        vm.pauseGasMetering();
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        address[] memory players = new address[](150);
        for (uint256 i = 0; i < 150; i++) {
            players[i] = address(uint160(uint256(keccak256(abi.encodePacked("player", i)))));
        }

        // Prepare ticket data
        uint256[4][] memory bronzeTickets = new uint256[4][](1);
        bronzeTickets[0] = [uint256(1), uint256(2), uint256(4), uint256(5)];

        // Simulate ticket purchases
        for (uint256 i = 0; i < 150; i++) {
            vm.deal(players[i], 100000 ether);
            vm.prank(players[i]);
            lottery.buyTickets{value: TICKET_PRICE}(bronzeTickets);
        }

        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        lottery.calculatePayouts(gameNumber);

        // Calculate expected payouts
        uint256 totalPrizePool = 500 ether + (150 * TICKET_PRICE);
        uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000 / 150;
        uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

        if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
            expectedFee = lottery.FEE_MAX_IN_ETH();
        }

        // Verify payout information
        assertEq(lottery.gamePayouts(gameNumber, 0), 0, "Stored gold payout should be zero");
        assertEq(lottery.gamePayouts(gameNumber, 1), 0, "Stored silver payout should be zero");
        assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize, "Stored bronze payout incorrect");

        // Claim prizes for all winners and verify balances
        for (uint256 i = 0; i < 150; i++) {
            address player = players[i];
            uint256 initialBalance = player.balance;
            vm.prank(player);
            lottery.claimPrize(gameNumber);
            
            assertEq(player.balance - initialBalance, expectedBronzePrize, "Prize payout incorrect for player");
        }

        // Assert fee transfer
        assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

        // Verify game state
        assertTrue(lottery.gameDrawCompleted(gameNumber), "Game draw should be marked as completed");
        for (uint256 i = 0; i < 150; i++) {
            address player = players[i];
            assertTrue(lottery.prizesClaimed(gameNumber, player), "Prize should be marked as claimed for player");
        }
    }

    // 100 winners - 1 jackpot, 0 silver, 99 bronze
    function testScenarioH() public {
        vm.pauseGasMetering();
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();

        address[] memory players = new address[](100);
        for (uint256 i = 0; i < 100; i++) {
            players[i] = address(uint160(uint256(keccak256(abi.encodePacked("player", i)))));
        }

        // Prepare ticket data
        uint256[4][] memory jackpotTicket = new uint256[4][](1);
        jackpotTicket[0] = [uint256(1), uint256(2), uint256(3), uint256(4)];

        uint256[4][] memory bronzeTickets = new uint256[4][](1);
        bronzeTickets[0] = [uint256(1), uint256(2), uint256(4), uint256(5)];

        // Simulate ticket purchases
        for (uint256 i = 0; i < 100; i++) {
            vm.deal(players[i], 100000 ether);
            vm.prank(players[i]);

            if (i == 0) {
                lottery.buyTickets{value: TICKET_PRICE}(jackpotTicket);
            } else {
                lottery.buyTickets{value: TICKET_PRICE}(bronzeTickets);
            }
        }

        setupDrawAndVDF();

        // Set winning numbers for testing
        uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
        lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);

        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        lottery.calculatePayouts(gameNumber);

        // Calculate expected payouts
        uint256 totalPrizePool = 500 ether + (100 * TICKET_PRICE);
        uint256 expectedGoldPrize = (totalPrizePool * lottery.GOLD_PERCENTAGE()) / 10000;
        uint256 expectedSilverPrize = (totalPrizePool * lottery.SILVER_PLACE_PERCENTAGE()) / 10000;
        uint256 expectedBronzePrize = (totalPrizePool * lottery.BRONZE_PLACE_PERCENTAGE()) / 10000 / 100;
        uint256 expectedFee = (totalPrizePool * lottery.FEE_PERCENTAGE()) / 10000;

        if (expectedFee > lottery.FEE_MAX_IN_ETH()) {
            expectedFee = lottery.FEE_MAX_IN_ETH();
        }

        // Verify payout information
        assertEq(lottery.gamePayouts(gameNumber, 0), expectedGoldPrize, "Stored gold payout incorrect");
        assertEq(lottery.gamePayouts(gameNumber, 1), expectedSilverPrize, "Stored silver payout incorrect");
        assertEq(lottery.gamePayouts(gameNumber, 2), expectedBronzePrize, "Stored bronze payout incorrect");

        // Claim prizes for all winners and verify balances
        for (uint256 i = 0; i < 100; i++) {
            address player = players[i];
            uint256 initialBalance = player.balance;
            vm.prank(player);
            lottery.claimPrize(gameNumber);
            
            uint256 expectedPrize;
            if (i == 0) {
                expectedPrize = expectedGoldPrize + expectedSilverPrize + expectedBronzePrize;
            } else {
                expectedPrize = expectedBronzePrize;
            }
            
            assertEq(player.balance - initialBalance, expectedPrize, "Prize payout incorrect for player");
        }

        // Assert fee transfer
        assertEq(feeRecipient.balance - initialFeeRecipientBalance, expectedFee, "Fee transfer incorrect");

        // Verify game state
        assertTrue(lottery.gameDrawCompleted(gameNumber), "Game draw should be marked as completed");
        for (uint256 i = 0; i < 100; i++) {
            address player = players[i];
            assertTrue(lottery.prizesClaimed(gameNumber, player), "Prize should be marked as claimed for player");
        }
    }
}