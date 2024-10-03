// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Lottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";

/*
contract LotteryBasicTest is Test {
    Lottery public lottery;
    VDFPietrzak public vdf;
    NFTPrize public nftPrize;
    address owner = address(this);
    address player = address(0x2);
    address feeRecipient = address(0x4);

    function setUp() public {
        vm.startPrank(owner);
        vdf = new VDFPietrzak();
        nftPrize = new NFTPrize();
        lottery = new Lottery(address(vdf), address(nftPrize), feeRecipient);
        vm.stopPrank();
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
    function testChangeDifficulty() public {
        // Simulate multiple games with no jackpot wins
        for (uint i = 0; i < 3; i++) {
            setupGameWithWinners();
            lottery.gameJackpotWon(lottery.currentGameNumber() - 1) = false;
        }

        Lottery.Difficulty initialDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());
        lottery.changeDifficulty();
        Lottery.Difficulty newDifficulty = lottery.gameDifficulty(lottery.currentGameNumber() + 1);

        assertTrue(uint(newDifficulty) < uint(initialDifficulty), "Difficulty should decrease after multiple games with no jackpot");
    }

    function testChangeDifficultyTooSoon() public {
        setupGameWithWinners();
        
        vm.expectRevert("Too soon to change difficulty");
        lottery.changeDifficulty();
    }

    function testChangeDifficultyNoChange() public {
        // Simulate multiple games with mixed results
        for (uint i = 0; i < 3; i++) {
            setupGameWithWinners();
            lottery.gameJackpotWon(lottery.currentGameNumber() - 1) = (i % 2 == 0);
        }

        Lottery.Difficulty initialDifficulty = lottery.gameDifficulty(lottery.currentGameNumber());
        lottery.changeDifficulty();
        Lottery.Difficulty newDifficulty = lottery.gameDifficulty(lottery.currentGameNumber() + 1);

        assertEq(uint(newDifficulty), uint(initialDifficulty), "Difficulty should not change with mixed results");
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
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.expectRevert("Ownable: caller is not the owner");
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
        payable(address(lottery)).transfer(1 ether);
        uint256 newPrizePool = lottery.gamePrizePool(lottery.currentGameNumber());

        assertEq(newPrizePool, initialPrizePool + 1 ether, "Prize pool should increase when receiving ether");
    }

    function testReleaseUnclaimedPrizes() public {
        // Setup a game with unclaimed prizes
        uint256 gameNumber = setupGameWithWinners();
        uint256 unclaimedAmount = lottery.gamePrizePool(gameNumber);

        // Advance time by more than a year
        vm.warp(block.timestamp + 53 weeks);

        uint256 initialNextGamePrizePool = lottery.gamePrizePool(lottery.currentGameNumber());
        lottery.releaseUnclaimedPrizes(gameNumber);
        uint256 newNextGamePrizePool = lottery.gamePrizePool(lottery.currentGameNumber());

        assertEq(newNextGamePrizePool, initialNextGamePrizePool + unclaimedAmount, "Unclaimed prizes should be added to the next game");
        assertEq(lottery.gamePrizePool(gameNumber), 0, "Original game prize pool should be emptied");
    }

    function testReleaseUnclaimedPrizesTooSoon() public {
        uint256 gameNumber = setupGameWithWinners();

        vm.expectRevert("Must wait 1 year after game");
        lottery.releaseUnclaimedPrizes(gameNumber);
    }

    function testMintWinningNFT() public {
        // Complete previous steps
        // testClaimPrize();

        // uint256 gameNumber = lottery.currentGameNumber() - 1;

        // vm.prank(user1);
        // lottery.mintWinningNFT(gameNumber);

        // bool nftClaimed = lottery.hasClaimedNFT(gameNumber, user1);
        // assertTrue(nftClaimed);

        // // Check that the NFT was minted
        // uint256 tokenId = uint256(keccak256(abi.encodePacked(gameNumber, user1)));
        // address ownerOfNFT = nftPrize.ownerOf(tokenId);
        // assertEq(ownerOfNFT, user1);
    }
}
*/