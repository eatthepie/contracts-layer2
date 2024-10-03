// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Lottery.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";
import "../src/libraries/BigNumbers.sol";

/*
contract LotteryVDFTest is Test {
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

    // Helper function to initiate a draw and set random
    function initiateDrawAndSetRandom() internal returns (uint256) {
        fundLottery();
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();
        uint256 gameNumber = lottery.currentGameNumber() - 1;
        uint256 targetBlock = lottery.gameRandomBlock(gameNumber);
        vm.roll(targetBlock);
        lottery.setRandom(gameNumber);
        return gameNumber;
    }

    // Random Number Generation Tests
    function testSetRandom() public {
        uint256 gameNumber = initiateDrawAndSetRandom();

        assertTrue(lottery.gameRandomValue(gameNumber) != 0, "Random value should be set");
        assertEq(lottery.gameRandomValue(gameNumber), block.prevrandao, "Random value should be set to prevrandao");
    }

    function testSetRandomTooEarly() public {
        fundLottery();
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();
        uint256 gameNumber = lottery.currentGameNumber() - 1;

        vm.expectRevert("Buffer period not yet passed");
        lottery.setRandom(gameNumber);
    }

    function testSetRandomTwice() public {
        uint256 gameNumber = initiateDrawAndSetRandom();

        vm.expectRevert("Random has already been set");
        lottery.setRandom(gameNumber);
    }

    // VDF Tests
    function testSubmitVDFProof() public {
        uint256 gameNumber = initiateDrawAndSetRandom();

        // Mock VDF verification
        vm.mockCall(
            address(vdf),
            abi.encodeWithSelector(VDFPietrzak.verifyPietrzak.selector),
            abi.encode(true)
        );

        BigNumber[] memory v = new BigNumber[](1);
        v[0] = BigNumbers.init(hex"1234");
        BigNumber memory y = BigNumbers.init(hex"5678");

        vm.expectEmit(true, false, false, false);
        emit Lottery.VDFProofSubmitted(address(this), gameNumber);

        lottery.submitVDFProof(gameNumber, v, y);

        assertTrue(lottery.gameVDFValid(gameNumber), "VDF should be marked as valid");
    }

    function testSubmitVDFProofBeforeRandomSet() public {
        fundLottery();
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();
        uint256 gameNumber = lottery.currentGameNumber() - 1;

        BigNumber[] memory v = new BigNumber[](1);
        v[0] = BigNumbers.init(hex"1234");
        BigNumber memory y = BigNumbers.init(hex"5678");

        vm.expectRevert("Random value not set for this game");
        lottery.submitVDFProof(gameNumber, v, y);
    }

    function testSubmitVDFProofInvalidProof() public {
        uint256 gameNumber = initiateDrawAndSetRandom();

        // Mock VDF verification to return false
        vm.mockCall(
            address(vdf),
            abi.encodeWithSelector(VDFPietrzak.verifyPietrzak.selector),
            abi.encode(false)
        );

        BigNumber[] memory v = new BigNumber[](1);
        v[0] = BigNumbers.init(hex"1234");
        BigNumber memory y = BigNumbers.init(hex"5678");

        vm.expectRevert("Invalid VDF proof");
        lottery.submitVDFProof(gameNumber, v, y);
    }

    function testSubmitVDFProofTwice() public {
        uint256 gameNumber = initiateDrawAndSetRandom();

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

        vm.expectRevert("VDF proof already submitted for this game");
        lottery.submitVDFProof(gameNumber, v, y);
    }

    function testVerifyPastGameVDF() public {
        uint256 gameNumber = initiateDrawAndSetRandom();

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

        // Advance to next game
        initiateDrawAndSetRandom();

        (uint256[4] memory calculatedNumbers, bool isValid) = lottery.verifyPastGameVDF(gameNumber, v, y);

        assertTrue(isValid, "Past game VDF should be valid");
        assertEq(calculatedNumbers, lottery.gameWinningNumbers(gameNumber), "Calculated numbers should match winning numbers");
    }
}
*/