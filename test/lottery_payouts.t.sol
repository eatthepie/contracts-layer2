// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Lottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";
import "../src/libraries/BigNumbers.sol";

contract LotteryPayoutTest is Test {
    Lottery public lottery;
    VDFPietrzak public vdf;
    NFTPrize public nftPrize;
    address owner = address(this);
    address player = address(0x2);
    address player1 = address(0x456);
    address player2 = address(0x789);
    address player3 = address(0xABC);
    address feeRecipient = address(0x4);

    function setUp() public {
        vm.startPrank(owner);
        vdf = new VDFPietrzak();
        nftPrize = new NFTPrize();
        lottery = new Lottery(address(vdf), address(nftPrize), feeRecipient);
        vm.stopPrank();
    }

    function fundLottery() internal {
        vm.deal(player, 1000 ether);
        vm.startPrank(player);
        uint256[3] memory numbers = [uint256(1), uint256(2), uint256(3)];
        uint256 etherball = 1;
        for (uint i = 0; i < 5000; i++) {
            lottery.buyTicket{value: 0.1 ether}(numbers, etherball);
        }
        vm.stopPrank();
    }

    // Helper function to initiate a draw, set random, and submit VDF proof
    function setupDrawAndVDF() internal returns (uint256) {
        fundLottery();
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

    // Payout Calculation Tests
    function testCalculatePayouts() public {
        uint256 gameNumber = setupDrawAndVDF();

        uint256 initialPrizePool = lottery.gamePrizePool(gameNumber);
        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        lottery.calculatePayouts(gameNumber);

        assertTrue(lottery.gameDrawCompleted(gameNumber), "Game draw should be completed");

        uint256 goldPayout = lottery.gamePayouts(gameNumber, 0);
        uint256 silverPayout = lottery.gamePayouts(gameNumber, 1);
        uint256 bronzePayout = lottery.gamePayouts(gameNumber, 2);
        uint256 loyaltyPayout = lottery.gamePayouts(gameNumber, 3);
        uint256 totalPayout = goldPayout + silverPayout + bronzePayout + loyaltyPayout;

        console.log("Gold payout: ", goldPayout);
        console.log("Silver payout: ", silverPayout);
        console.log("Bronze payout: ", bronzePayout);
        console.log("Loyalty payout: ", loyaltyPayout);
        console.log("Total payout: ", totalPayout);

        console.log("Initial prize pool: ", initialPrizePool);
        console.log("Fee recipient balance: ", feeRecipient.balance);
        console.log("Initial fee recipient balance: ", initialFeeRecipientBalance);

        // Check that total payout plus fee equals initial prize pool
        uint256 fee = feeRecipient.balance - initialFeeRecipientBalance;

        console.log("Fee: ", fee);

        assertEq(totalPayout + fee, initialPrizePool, "Total payout plus fee should equal initial prize pool");

        // Check payout percentages
        assertApproxEqRel(goldPayout, initialPrizePool * lottery.GOLD_PERCENTAGE() / 10000, 1e15, "Gold payout should be correct");
        assertApproxEqRel(silverPayout, initialPrizePool * lottery.SILVER_PLACE_PERCENTAGE() / 10000, 1e15, "Silver payout should be correct");
        assertApproxEqRel(bronzePayout, initialPrizePool * lottery.BRONZE_PLACE_PERCENTAGE() / 10000, 1e15, "Bronze payout should be correct");
        assertApproxEqRel(loyaltyPayout, initialPrizePool * lottery.LOYALTY_PERCENTAGE() / 10000, 1e15, "Loyalty payout should be correct");
    }

    // function testCalculatePayoutsWithWinners() public {
    //     // Buy tickets for players
    //     vm.deal(player1, 1 ether);
    //     vm.deal(player2, 1 ether);
    //     vm.deal(player3, 1 ether);

    //     uint256[3] memory numbers = [uint256(1), uint256(2), uint256(3)];
    //     uint256 etherball = 1;

    //     vm.prank(player1);
    //     lottery.buyTicket{value: 0.1 ether}(numbers, etherball);
    //     vm.prank(player2);
    //     lottery.buyTicket{value: 0.1 ether}(numbers, etherball);
    //     vm.prank(player3);
    //     lottery.buyTicket{value: 0.1 ether}([uint256(4), uint256(5), uint256(6)], 2);

    //     uint256 gameNumber = setupDrawAndVDF();

    //     // Set winning numbers to match player1 and player2's tickets
    //     lottery.setWinningNumbers(gameNumber, abi.encodePacked(uint256(1), uint256(2), uint256(3), uint256(1)));

    //     lottery.calculatePayouts(gameNumber);

    //     uint256[4] memory payouts = lottery.gamePayouts(gameNumber);
    //     assertTrue(payouts[0] > 0, "Gold prize should be set");
    //     assertTrue(payouts[1] == 0, "Silver prize should be zero as all winners got gold");
    //     assertTrue(payouts[2] == 0, "Bronze prize should be zero as all winners got gold");
    //     assertTrue(payouts[3] > 0, "Loyalty prize should be set");

    //     // Check that the total payout is correct
    //     uint256 totalPayout = payouts[0] * 2 + payouts[3]; // 2 gold winners
    //     uint256 expectedTotal = (0.3 ether * 9900) / 10000; // Total prize pool minus 1% fee
    //     assertApproxEqAbs(totalPayout, expectedTotal, 1e15, "Total payout should be close to expected");
    // }

    // function testCalculatePayoutsNoWinners() public {
    //     uint256 gameNumber = setupDrawAndVDF();

    //     lottery.calculatePayouts(gameNumber);

    //     uint256[4] memory payouts = lottery.gamePayouts(gameNumber);
    //     assertEq(payouts[0], 0, "Gold prize should be zero");
    //     assertEq(payouts[1], 0, "Silver prize should be zero");
    //     assertEq(payouts[2], 0, "Bronze prize should be zero");
    //     assertEq(payouts[3], 0, "Loyalty prize should be zero");

    //     // Check that the prize pool is transferred to the next game
    //     uint256 nextGamePrizePool = lottery.gamePrizePool(lottery.currentGameNumber());
    //     uint256 expectedPrizePool = (lottery.DRAW_MIN_PRIZE_POOL() * 9900) / 10000; // Minus 1% fee
    //     assertApproxEqAbs(nextGamePrizePool, expectedPrizePool, 1e15, "Prize pool should be transferred to next game");
    // }

    // function testCalculatePayoutsTwice() public {
    //     uint256 gameNumber = setupDrawAndVDF();

    //     lottery.calculatePayouts(gameNumber);

    //     vm.expectRevert("Payouts already calculated for this game");
    //     lottery.calculatePayouts(gameNumber);
    // }

    // function testCalculatePayoutsBeforeVDF() public {
    //     fundLottery();
    //     vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
    //     lottery.initiateDraw();
    //     uint256 gameNumber = lottery.currentGameNumber() - 1;

    //     vm.expectRevert("VDF proof not yet validated for this game");
    //     lottery.calculatePayouts(gameNumber);
    // }

    // function testFeeCalculation() public {
    //     // Buy a large number of tickets to trigger the fee cap
    //     vm.deal(player1, 10000 ether);
    //     vm.startPrank(player1);
    //     for (uint i = 0; i < 100000; i++) {
    //         lottery.buyTicket{value: 0.1 ether}([uint256(1), uint256(2), uint256(3)], 1);
    //     }
    //     vm.stopPrank();

    //     uint256 gameNumber = setupDrawAndVDF();

    //     uint256 initialFeeRecipientBalance = feeRecipient.balance;
    //     lottery.calculatePayouts(gameNumber);

    //     uint256 feeReceived = feeRecipient.balance - initialFeeRecipientBalance;
    //     assertEq(feeReceived, lottery.FEE_MAX_IN_ETH(), "Fee should be capped at FEE_MAX_IN_ETH");
    // }
}