// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "./mocks/mockLottery.sol";

contract LotteryBasicTest is Test {
    enum Difficulty { Easy, Medium, Hard }

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
        vm.prevrandao(bytes32(uint256(51049764388387882260001832746320922162275278963975484447753639501411130604681)));
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

    // Basic
    function testInitialState() public view {
        assertEq(lottery.currentGameNumber(), 1, "Initial game number should be 1");
        assertEq(lottery.ticketPrice(), TICKET_PRICE, "Initial ticket price should be 0.1 ether");
        assertEq(lottery.feeRecipient(), feeRecipient, "Fee recipient should be set correctly");
        assertEq(address(lottery.vdfContract()), address(vdf), "VDF contract should be set correctly");
        assertEq(address(lottery.nftPrize()), address(nftPrize), "NFT Prize contract should be set correctly");
        
        (uint256 gameNumber, Lottery.Difficulty difficulty, uint256 prizePool, , ) = lottery.getCurrentGameInfo();
        assertEq(gameNumber, 1, "Current game number should be 1");
        assertEq(uint(difficulty), uint(Lottery.Difficulty.Easy), "Initial difficulty should be Easy");
        assertEq(prizePool, 0, "Initial prize pool should be 0");
    }

    function testGetCurrentGameInfo() public view {
        (
            uint256 gameNumber,
            Lottery.Difficulty difficulty,
            uint256 prizePool,
            uint256 drawTime,
            uint256 timeUntilDraw
        ) = lottery.getCurrentGameInfo();

        assertEq(gameNumber, 1, "Initial game number should be 1");
        assertEq(uint(difficulty), uint(Lottery.Difficulty.Easy), "Initial difficulty should be Easy");
        assertEq(prizePool, 0, "Initial prize pool should be 0");
        assertTrue(drawTime > block.timestamp, "Draw time should be in the future");
        assertTrue(timeUntilDraw > 0, "Time until draw should be positive");
    }

    function testGetBasicGameInfo() public {
        // Game 1 starts
        fundLottery(5000);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket([uint256(1), uint256(1), uint256(1), uint256(1)]));
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();
        // Game 2 starts
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket([uint256(2), uint256(2), uint256(2), uint256(2)]));

        (Lottery.GameBasicInfo[] memory gameInfos) = lottery.getBasicGameInfo(1, 2);

        // Assertions
        assertEq(gameInfos.length, 2, "Should return info for 2 games");

        // Check Game 1
        assertEq(gameInfos[0].gameId, 1, "First game ID should be 1");
        assertEq(uint(gameInfos[0].status), uint(Lottery.GameStatus.Drawing), "Game 1 should be in Drawing state");
        assertEq(gameInfos[0].prizePool, 500 ether + TICKET_PRICE, "Game 1 prize pool should be 0.1 ether");
        assertEq(gameInfos[0].numberOfWinners, 0, "Game 1 should have no winners yet");

        // Check Game 2
        assertEq(gameInfos[1].gameId, 2, "Second game ID should be 2");
        assertEq(uint(gameInfos[1].status), uint(Lottery.GameStatus.InPlay), "Game 2 should be in InPlay state");
        assertEq(gameInfos[1].prizePool, TICKET_PRICE, "Game 2 prize pool should be 0.2 ether");
        assertEq(gameInfos[1].numberOfWinners, 0, "Game 2 should have no winners");

        // Test pagination
        (gameInfos) = lottery.getBasicGameInfo(2, 2);
        assertEq(gameInfos.length, 1, "Should return info for 1 game");
    }

    function testGetDetailedGameInfo() public {
        // Setup: Create a game and progress it to Completed state
        fundLottery(5000);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket([uint256(3), uint256(3), uint256(3), uint256(3)]));
        setupDrawAndVDF();
        lottery.calculatePayouts(1);
        Lottery.GameDetailedInfo memory gameInfo = lottery.getDetailedGameInfo(1);

        // Assertions
        assertEq(uint(gameInfo.status), uint(Lottery.GameStatus.Completed), "Game should be in Completed state");
        assertEq(gameInfo.prizePool, 500 ether + TICKET_PRICE, "Prize pool should be 0.3 ether");
        assertEq(gameInfo.numberOfWinners, 0, "Should have no winners"); // Assuming no winning tickets
        assertEq(uint(gameInfo.difficulty), uint(Lottery.Difficulty.Easy), "Difficulty should be Easy");
        assertTrue(gameInfo.drawInitiatedBlock > 0, "Draw initiated block should be set");
        assertTrue(gameInfo.randaoBlock > gameInfo.drawInitiatedBlock, "RANDAO block should be after draw initiated");
        assertTrue(gameInfo.randaoValue != 0, "RANDAO value should be set");

        // Test for non-existent game
        vm.expectRevert("Game ID exceeds current game");
        lottery.getDetailedGameInfo(3);
    }

    function testHasUserWon() public {
        fundLottery(5000);

        vm.startPrank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket([uint256(1), uint256(2), uint256(3), uint256(4)]));
        vm.stopPrank();

        vm.startPrank(player2);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket([uint256(1), uint256(2), uint256(5), uint256(1)]));
        vm.stopPrank();

        vm.startPrank(player3);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket([uint256(5), uint256(6), uint256(7), uint256(3)]));
        vm.stopPrank();

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set winning numbers
        lottery.setWinningNumbersForTesting(gameNumber, [uint256(1), uint256(2), uint256(3), uint256(4)]);
        lottery.calculatePayouts(gameNumber);

        // Check if users have won
        assertTrue(lottery.hasUserWon(gameNumber, player1), "Player1 should have won");
        assertTrue(lottery.hasUserWon(gameNumber, player2), "Player2 should have won");
        assertFalse(lottery.hasUserWon(gameNumber, player3), "Player3 should not have won");
        assertFalse(lottery.hasUserWon(gameNumber, address(0x1234)), "Random address should not have won");

        // Check for non-existent game
        vm.expectRevert("Game draw not completed yet"); // should be invalid game number?
        lottery.hasUserWon(gameNumber + 1, player1);

        // Check for game that hasn't completed the draw
        uint256 nextGameNumber = lottery.currentGameNumber();
        vm.expectRevert("Game draw not completed yet");
        lottery.hasUserWon(nextGameNumber, player1);
    }

    function testGetUserGameWinnings() public {
        fundLottery(5000);

        vm.startPrank(player1);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket([uint256(1), uint256(2), uint256(3), uint256(4)])); // Gold winner
        vm.stopPrank();

        vm.startPrank(player2);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket([uint256(1), uint256(2), uint256(3), uint256(5)])); // Silver winner
        vm.stopPrank();

        vm.startPrank(player3);
        lottery.buyTickets{value: TICKET_PRICE}(wrapTicket([uint256(1), uint256(2), uint256(4), uint256(5)])); // Bronze winner
        vm.stopPrank();

        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();

        // Set winning numbers
        lottery.setWinningNumbersForTesting(gameNumber, [uint256(1), uint256(2), uint256(3), uint256(4)]);
        lottery.calculatePayouts(gameNumber);

        // Check winnings for gold winner (player1)
        (bool goldWin, bool silverWin, bool bronzeWin, uint256 totalPrize, bool claimed) = lottery.getUserGameWinnings(gameNumber, player1);
        assertTrue(goldWin, "Player1 should have won gold");
        assertTrue(silverWin, "Player1 should have won silver");
        assertTrue(bronzeWin, "Player1 should have won bronze");
        assertEq(totalPrize, lottery.gamePayouts(gameNumber, 0) + lottery.gamePayouts(gameNumber, 1) + lottery.gamePayouts(gameNumber, 2), "Player1's prize should match gold + silver + bronze payout");
        assertFalse(claimed, "Player1's prize should not be claimed yet");

        // Check winnings for silver winner (player2)
        (goldWin, silverWin, bronzeWin, totalPrize, claimed) = lottery.getUserGameWinnings(gameNumber, player2);
        assertFalse(goldWin, "Player2 should not have won gold");
        assertTrue(silverWin, "Player2 should have won silver");
        assertTrue(bronzeWin, "Player2 should have won bronze");
        assertEq(totalPrize, lottery.gamePayouts(gameNumber, 1) + lottery.gamePayouts(gameNumber, 2), "Player2's prize should match silver + bronze payout");
        assertFalse(claimed, "Player2's prize should not be claimed yet");

        // Check winnings for bronze winner (player3)
        (goldWin, silverWin, bronzeWin, totalPrize, claimed) = lottery.getUserGameWinnings(gameNumber, player3);
        assertFalse(goldWin, "Player3 should not have won gold");
        assertFalse(silverWin, "Player3 should not have won silver");
        assertTrue(bronzeWin, "Player3 should have won bronze");
        assertEq(totalPrize, lottery.gamePayouts(gameNumber, 2), "Player3's prize should match bronze payout");
        assertFalse(claimed, "Player3's prize should not be claimed yet");

        // Check for non-winner
        (goldWin, silverWin, bronzeWin, totalPrize, claimed) = lottery.getUserGameWinnings(gameNumber, address(0x1234));
        assertFalse(goldWin, "Non-winner should not have won gold");
        assertFalse(silverWin, "Non-winner should not have won silver");
        assertFalse(bronzeWin, "Non-winner should not have won bronze");
        assertEq(totalPrize, 0, "Non-winner's prize should be zero");
        assertFalse(claimed, "Non-winner's prize should not be claimed");

        // Check for non-existent game
        uint256 currentGameNumber = lottery.currentGameNumber();

        vm.expectRevert("Game draw not completed yet");
        lottery.getUserGameWinnings(currentGameNumber, player1);

        vm.expectRevert("Invalid game number");
        lottery.getUserGameWinnings(currentGameNumber + 1, player1);
    }

    function testReceiveEther() public {
        uint256 initialPrizePool = lottery.gamePrizePool(lottery.currentGameNumber());

        (bool success, ) = payable(address(lottery)).call{value: 1 ether}("");
        require(success, "Failed to send Ether");

        uint256 newPrizePool = lottery.gamePrizePool(lottery.currentGameNumber());

        assertEq(newPrizePool, initialPrizePool + 1 ether, "Prize pool should increase when receiving ether");
    }

    // Game difficulty changes
    function testChangeDifficultyDown() public {
        lottery.setInitialDifficultyForTesting(Lottery.Difficulty.Medium);

        // Simulate multiple games with no jackpot wins
        for (uint i = 0; i < 3; i++) {
            fundLottery(5000);
            uint256 gameNumber = setupDrawAndVDF();

            uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
            lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
            lottery.calculatePayouts(gameNumber);
        }

        fundLottery(5000);

        assertEq(lottery.consecutiveNonJackpotGames(), 3, "consecutiveNonJackpotGames should be 3");

        lottery.changeDifficulty();

        setupDrawAndVDF(); // initiate next game
        Lottery.Difficulty newDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());

        assertTrue(uint(newDifficulty) < uint(Lottery.Difficulty.Medium), "Difficulty should decrease after multiple games with no jackpot");
    }
    
    function testChangeDifficultyUp() public {
        lottery.setInitialDifficultyForTesting(Lottery.Difficulty.Medium);

        // Simulate multiple games with jackpot wins
        for (uint i = 0; i < 3; i++) {
            fundLottery(5000);
            uint256 gameNumber = setupDrawAndVDF();

            uint256[4] memory winningNumbers = [uint256(10), uint256(10), uint256(10), uint256(1)];
            lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
            lottery.calculatePayouts(gameNumber);
        }

        fundLottery(5000);

        assertEq(lottery.consecutiveJackpotGames(), 3, "consecutiveJackpotGames should be 3");

        lottery.changeDifficulty();

        setupDrawAndVDF(); // initiate next game
        Lottery.Difficulty newDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());

        assertTrue(uint(newDifficulty) > uint(Lottery.Difficulty.Medium), "Difficulty should increase after multiple games with jackpot wins");
    }

    function testChangeDifficultyMinimum() public {
        lottery.setInitialDifficultyForTesting(Lottery.Difficulty.Easy);

        // Simulate multiple games with no jackpot wins
        for (uint i = 0; i < 3; i++) {
            fundLottery(5000);
            uint256 gameNumber = setupDrawAndVDF();

            uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
            lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
            lottery.calculatePayouts(gameNumber);
        }

        fundLottery(5000);

        assertEq(lottery.consecutiveNonJackpotGames(), 3, "consecutiveNonJackpotGames should be 3");

        lottery.changeDifficulty();

        setupDrawAndVDF(); // initiate next game
        Lottery.Difficulty newDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());

        assertEq(uint(newDifficulty), uint(Lottery.Difficulty.Easy), "Difficulty should not decrease below Easy");
    }

    function testChangeDifficultyMaximum() public {
        lottery.setInitialDifficultyForTesting(Lottery.Difficulty.Hard);

        // Simulate multiple games with jackpot wins
        for (uint i = 0; i < 3; i++) {
            fundLottery(5000);
            uint256 gameNumber = setupDrawAndVDF();

            uint256[4] memory winningNumbers = [uint256(10), uint256(10), uint256(10), uint256(1)];
            lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
            lottery.calculatePayouts(gameNumber);
        }

        fundLottery(5000);

        assertEq(lottery.consecutiveJackpotGames(), 3, "consecutiveJackpotGames should be 3");

        lottery.changeDifficulty();

        setupDrawAndVDF(); // initiate next game
        Lottery.Difficulty newDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());

        assertEq(uint(newDifficulty), uint(Lottery.Difficulty.Hard), "Difficulty should not increase above Hard");
    }

    function testChangeDifficultyTooSoon() public {
        lottery.setInitialDifficultyForTesting(Lottery.Difficulty.Medium);

        // Simulate 3 games with jackpot wins
        for (uint i = 0; i < 3; i++) {
            fundLottery(5000);
            uint256 gameNumber = setupDrawAndVDF();
            uint256[4] memory winningNumbers = [uint256(10), uint256(10), uint256(10), uint256(1)];
            lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
            lottery.calculatePayouts(gameNumber);
        }

        fundLottery(5000);
        lottery.changeDifficulty();
        
        // Try to change difficulty again immediately
        vm.expectRevert("Too soon to change difficulty");
        lottery.changeDifficulty();

        // Simulate one more game
        setupDrawAndVDF();

        // Try to change difficulty again, should still be too soon
        vm.expectRevert("Too soon to change difficulty");
        lottery.changeDifficulty();
    }

    function testChangeDifficultyNoChange() public {
        lottery.setInitialDifficultyForTesting(Lottery.Difficulty.Medium);

        // Jackpot, no jackpot, jackpot
        for (uint i = 0; i < 3; i++) {
            fundLottery(5000);
            uint256 gameNumber = setupDrawAndVDF();
            uint256[4] memory winningNumbers;
            if (i % 2 == 0) {
                winningNumbers = [uint256(10), uint256(10), uint256(10), uint256(1)]; // Jackpot
            } else {
                winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)]; // No jackpot
            }
            lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
            lottery.calculatePayouts(gameNumber);
        }

        fundLottery(5000);

        assertEq(lottery.consecutiveJackpotGames(), 1, "consecutiveJackpotGames should be 1");
        assertEq(lottery.consecutiveNonJackpotGames(), 0, "consecutiveNonJackpotGames should be 0");

        lottery.changeDifficulty();
        setupDrawAndVDF(); // initiate next game
        Lottery.Difficulty newDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());

        assertEq(uint(newDifficulty), uint(Lottery.Difficulty.Medium), "Difficulty should not change");
    }

    function testChangeDifficultyTwice() public {
        lottery.setInitialDifficultyForTesting(Lottery.Difficulty.Medium);

        // First set of 3 games with jackpot wins
        for (uint i = 0; i < 3; i++) {
            fundLottery(5000);
            uint256 gameNumber = setupDrawAndVDF();
            uint256[4] memory winningNumbers = [uint256(10), uint256(10), uint256(10), uint256(1)];
            lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
            lottery.calculatePayouts(gameNumber);
        }

        fundLottery(5000);
        lottery.changeDifficulty();
        setupDrawAndVDF(); // initiate next game
        Lottery.Difficulty firstNewDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());
        assertTrue(uint(firstNewDifficulty) > uint(Lottery.Difficulty.Medium), "Difficulty should increase after first change");

        // Simulate 4 more games with no jackpot wins (to pass the "too soon" check)
        for (uint i = 0; i < 4; i++) {
            fundLottery(5000);
            uint256 gameNumber = setupDrawAndVDF();
            uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
            lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
            lottery.calculatePayouts(gameNumber);
        }

        fundLottery(5000);
        lottery.changeDifficulty();
        setupDrawAndVDF(); // initiate next game
        Lottery.Difficulty secondNewDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());
        assertTrue(uint(secondNewDifficulty) < uint(firstNewDifficulty), "Difficulty should decrease after second change");
    }

    function testDifficultyResetAfterChange() public {
        // Start with Medium difficulty
        lottery.setInitialDifficultyForTesting(Lottery.Difficulty.Medium);

        // Simulate 3 games with jackpot wins to trigger a difficulty increase
        for (uint i = 0; i < 3; i++) {
            fundLottery(5000);
            uint256 gameNumber = setupDrawAndVDF();
            uint256[4] memory winningNumbers = [uint256(10), uint256(10), uint256(10), uint256(1)];
            lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
            lottery.calculatePayouts(gameNumber);
        }

        // Change difficulty
        fundLottery(5000);
        lottery.changeDifficulty();
        
        // Setup next game and check that difficulty has increased
        uint256 difficultyChangeGame = setupDrawAndVDF();
        Lottery.Difficulty newDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());
        assertEq(uint(newDifficulty), uint(Lottery.Difficulty.Hard), "Difficulty should have increased to Hard");

        // Now simulate 3 games without jackpot wins
        for (uint i = 0; i < 3; i++) {
            fundLottery(5000);
            uint256 gameNumber = setupDrawAndVDF();
            uint256[4] memory winningNumbers = [uint256(1), uint256(2), uint256(3), uint256(4)];
            lottery.setWinningNumbersForTesting(gameNumber, winningNumbers);
            lottery.calculatePayouts(gameNumber);
        }

        // Ensure we're past the minimum games required for another difficulty change
        while (lottery.currentGameNumber() <= difficultyChangeGame + 3) {
            fundLottery(5000);
            setupDrawAndVDF();
        }

        // Change difficulty again
        lottery.changeDifficulty();

        // Setup next game and check that difficulty has decreased
        setupDrawAndVDF();
        Lottery.Difficulty resetDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());
        assertEq(uint(resetDifficulty), uint(Lottery.Difficulty.Medium), "Difficulty should have reset to Medium");

        // Check that consecutive game counters have been reset
        assertEq(lottery.consecutiveJackpotGames(), 0, "Consecutive jackpot games should be reset to 0");
        assertEq(lottery.consecutiveNonJackpotGames(), 0, "Consecutive non-jackpot games should be reset to 0");
    }

    // Admin functions
    function testSetTicketPrice() public {
        uint256 newPrice = 0.2 ether;
        lottery.setTicketPrice(newPrice);

        assertEq(lottery.newTicketPrice(), newPrice, "New ticket price should be set");
        assertEq(lottery.newTicketPriceGameNumber(), lottery.currentGameNumber() + 10, "New ticket price game number should be set");
    }

    function testSetTicketPriceNonOwner() public {
        uint256 newPrice = 0.2 ether;
        vm.prank(player);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", player));
        lottery.setTicketPrice(newPrice);
    }

    function testSetNewVDFContract() public {
        address newVDFAddress = address(0x789);
        lottery.setNewVDFContract(newVDFAddress);

        assertEq(lottery.newVDFContract(), newVDFAddress, "New VDF contract address should be set");
        assertEq(lottery.newVDFContractGameNumber(), lottery.currentGameNumber() + 10, "New VDF contract game number should be set");
    }

    function testSetNewVDFContractNonOwner() public {
        address newVDFAddress = address(0x789);
        vm.prank(player);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", player));
        lottery.setNewVDFContract(newVDFAddress);
    }

    function testSetFeeRecipient() public {
        address newFeeRecipient = address(0xDEF);
        lottery.setFeeRecipient(newFeeRecipient);

        assertEq(lottery.feeRecipient(), newFeeRecipient, "Fee recipient should be updated");
    }

    function testSetFeeRecipientNonOwner() public {
        address newFeeRecipient = address(0xDEF);
        vm.prank(player);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", player));
        lottery.setFeeRecipient(newFeeRecipient);
    }
}