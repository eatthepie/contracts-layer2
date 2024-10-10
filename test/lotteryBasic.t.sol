// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "./mocks/mockLottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";
import "../src/libraries/BigNumbers.sol";

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

    function fundLottery(uint256 ticketCount) internal {
        vm.startPrank(player);
        uint256[3] memory numbers = [uint256(10), uint256(10), uint256(10)];
        uint256 etherball = 1;
        for (uint i = 0; i < ticketCount; i++) {
            lottery.buyTicket{value: TICKET_PRICE}(numbers, etherball);
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

    // Initial State Tests
    function testInitialState() public {
        assertEq(lottery.currentGameNumber(), 1, "Initial game number should be 1");
        assertEq(lottery.ticketPrice(), 0.1 ether, "Initial ticket price should be 0.1 ether");
        assertEq(lottery.feeRecipient(), feeRecipient, "Fee recipient should be set correctly");
        assertEq(address(lottery.vdfContract()), address(vdf), "VDF contract should be set correctly");
        assertEq(address(lottery.nftPrize()), address(nftPrize), "NFT Prize contract should be set correctly");
        
        (uint256 gameNumber, Lottery.Difficulty difficulty, uint256 prizePool, , ) = lottery.getCurrentGameInfo();
        assertEq(gameNumber, 1, "Current game number should be 1");
        assertEq(uint(difficulty), uint(Lottery.Difficulty.Easy), "Initial difficulty should be Easy");
        assertEq(prizePool, 0, "Initial prize pool should be 0");
    }


    // Difficulty Change Tests
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

    // Admin Function Tests
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

    // Additional Basic Tests
    function testGetCurrentGameInfo() public {
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

    function testReceiveEther() public {
        uint256 initialPrizePool = lottery.gamePrizePool(lottery.currentGameNumber());

        (bool success, ) = payable(address(lottery)).call{value: 1 ether}("");
        require(success, "Failed to send Ether");

        uint256 newPrizePool = lottery.gamePrizePool(lottery.currentGameNumber());

        assertEq(newPrizePool, initialPrizePool + 1 ether, "Prize pool should increase when receiving ether");
    }

    function testReleaseUnclaimedPrizes() public {
        // Setup a game with unclaimed prizes
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();
        lottery.calculatePayouts(gameNumber);

        // Advance block by BLOCKS_CLAIM_PERIOD()
        vm.roll(block.number + lottery.BLOCKS_CLAIM_PERIOD());
        uint256 unclaimedAmount = lottery.gamePrizePool(gameNumber);

        uint256 initialNextGamePrizePool = lottery.gamePrizePool(lottery.currentGameNumber());
        lottery.releaseUnclaimedPrizes(gameNumber);
        uint256 newNextGamePrizePool = lottery.gamePrizePool(lottery.currentGameNumber());

        assertEq(newNextGamePrizePool, initialNextGamePrizePool + unclaimedAmount, "Unclaimed prizes should be added to the next game");
        assertEq(lottery.gamePrizePool(gameNumber), 0, "Original game prize pool should be emptied");
    }

    function testReleaseUnclaimedPrizesTooSoon() public {
        fundLottery(5000);
        uint256 gameNumber = lottery.currentGameNumber();
        setupDrawAndVDF();
        lottery.calculatePayouts(gameNumber);

        vm.expectRevert("Must wait BLOCKS_CLAIM_PERIOD period before releasing unclaimed prizes");
        lottery.releaseUnclaimedPrizes(gameNumber);
    }
}