// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Lottery.sol";

// valid proofs
import "../test-vdf-files/valid/a.sol";
import "../test-vdf-files/valid/b.sol";
import "../test-vdf-files/valid/c.sol";
import "../test-vdf-files/valid/d.sol";

// invalid proofs
import "../test-vdf-files/invalid/a.sol";
import "../test-vdf-files/invalid/b.sol";
import "../test-vdf-files/invalid/c.sol";
import "../test-vdf-files/invalid/d.sol";

contract LotteryVDFTest is Test {
    Lottery public lottery;
    VDFPietrzak public vdf;
    NFTPrize public nftPrize;
    address owner = address(this);
    address player = address(0x2);
    address feeRecipient = address(0x4);
    uint256 public constant TICKET_PRICE = 0.1 ether;

    VDFProofData[] public vdfProofs;

    struct VDFProofData {
        bytes32 prevrandao;
        uint8 vdfIndex;
    }

    function setUp() public {
        vm.startPrank(owner);
        vdf = new VDFPietrzak();
        nftPrize = new NFTPrize();
        lottery = new Lottery(address(vdf), address(nftPrize), feeRecipient);
        vm.stopPrank();

        // load valid proofs
        vdfProofs.push(VDFProofData({
            prevrandao: bytes32(uint256(65305838511507767948894108466576998214933764930710580223742911944647654807690)),
            vdfIndex: 0
        }));

        vdfProofs.push(VDFProofData({
            prevrandao: bytes32(uint256(51049764388387882260001832746320922162275278963975484447753639501411130604681)),
            vdfIndex: 1
        }));

        vdfProofs.push(VDFProofData({
            prevrandao: bytes32(uint256(2656751508725187512486344122081204096368588122458517885621621007542366135775)),
            vdfIndex: 2
        }));

        vdfProofs.push(VDFProofData({
            prevrandao: bytes32(uint256(96618837226557606533137319610808329371780981598490822395441686749465502125142)),
            vdfIndex: 3
        }));
    }

    function fundLottery() internal {
        vm.deal(player, 1000 ether);
        vm.startPrank(player);
        uint256 remainingTickets = 5000;

        while (remainingTickets > 0) {
            uint256 batchSize = remainingTickets > 100 ? 100 : remainingTickets;
            
            uint256[4][] memory tickets = new uint256[4][](batchSize);
            for (uint256 i = 0; i < batchSize; i++) {
                tickets[i] = [uint256(1), uint256(2), uint256(3), uint256(1)];
            }
            
            uint256 batchCost = TICKET_PRICE * batchSize;
            lottery.buyTickets{value: batchCost}(tickets);
            
            remainingTickets -= batchSize;
        }
        
        vm.stopPrank();
    }

    function initiateDrawAndSetRandom() internal returns (uint256) {
        fundLottery();
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();
        uint256 gameNumber = lottery.currentGameNumber() - 1;
        uint256 targetBlock = lottery.gameRandomBlock(gameNumber);
        vm.roll(targetBlock);
        vm.prevrandao(bytes32(uint256(51049764388387882260001832746320922162275278963975484447753639501411130604681))); // make prevrandao non-zero
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
    function testSubmitValidVDFProofs() public {
        for (uint i = 0; i < vdfProofs.length; i++) {
            VDFProofData memory proofData = vdfProofs[i];

            // begin lottery
            fundLottery();

            // initiate draw
            vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
            lottery.initiateDraw();

            // wait for buffer period
            uint256 targetBlock = block.number + lottery.DRAW_DELAY_SECURITY_BUFFER();
            vm.roll(targetBlock);
            
            // get the random number
            vm.prevrandao(proofData.prevrandao);
            uint256 gameNumber = lottery.currentGameNumber() - 1;
            lottery.setRandom(gameNumber);
            
            // submit vdf proof
            BigNumber memory y = getValidY(proofData.vdfIndex);
            BigNumber[] memory v = getValidV(proofData.vdfIndex);
            
            vm.expectEmit(true, false, false, false);
            emit Lottery.VDFProofSubmitted(address(this), gameNumber);
            
            lottery.submitVDFProof(gameNumber, v, y);
            
            assertTrue(lottery.gameVDFValid(gameNumber), "VDF should be marked as valid");

            // verify the winning numbers
            bytes32 randomSeed = keccak256(y.val);
            Lottery.Difficulty difficulty = lottery.gameDifficulty(gameNumber);
            (uint256 maxNumber, uint256 maxEtherball) = getDifficultyParams(difficulty);
            
            for (uint j = 0; j < 4; j++) {
                uint256 maxValue = j < 3 ? maxNumber : maxEtherball;
                uint256 expectedNumber = generateUnbiasedRandomNumber(randomSeed, j, maxValue);
                uint256 actualNumber = lottery.gameWinningNumbers(gameNumber, j);
                assertEq(actualNumber, expectedNumber, "Winning number should match expected value");
            }
        }
    }

    function testSubmitInvalidVDFProofs() public {
        for (uint i = 0; i < vdfProofs.length; i++) {
            VDFProofData memory proofData = vdfProofs[i];

            // begin lottery
            fundLottery();

            // initiate draw
            vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
            lottery.initiateDraw();

            // wait for buffer period
            uint256 targetBlock = block.number + lottery.DRAW_DELAY_SECURITY_BUFFER();
            vm.roll(targetBlock);
            
            // get the random number
            vm.prevrandao(proofData.prevrandao);
            uint256 gameNumber = lottery.currentGameNumber() - 1;
            lottery.setRandom(gameNumber);
            
            // submit vdf proof
            BigNumber memory y = getInvalidY(proofData.vdfIndex);
            BigNumber[] memory v = getInvalidV(proofData.vdfIndex);
            
            vm.expectRevert("Invalid VDF proof");
            lottery.submitVDFProof(gameNumber, v, y);
        }
    }

    function testSubmitVDFProofBeforeRandomSet() public {
        fundLottery();
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();

        uint256 targetBlock = block.number + lottery.DRAW_DELAY_SECURITY_BUFFER();
        vm.roll(targetBlock);

        uint256 gameNumber = lottery.currentGameNumber() - 1;

        BigNumber memory y = getValidY(0);
        BigNumber[] memory v = getValidV(0);

        vm.expectRevert("Random value not set for this game");
        lottery.submitVDFProof(gameNumber, v, y);
    }

    function testSubmitVDFProofTwice() public {
        VDFProofData memory proofData = vdfProofs[0];

        // begin lottery
        fundLottery();

        // initiate draw
        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();

        // wait for buffer period
        uint256 targetBlock = block.number + lottery.DRAW_DELAY_SECURITY_BUFFER();
        vm.roll(targetBlock);
        
        // get the random number
        vm.prevrandao(proofData.prevrandao);
        uint256 gameNumber = lottery.currentGameNumber() - 1;
        lottery.setRandom(gameNumber);
        
        // submit vdf proof
        BigNumber memory y = getValidY(proofData.vdfIndex);
        BigNumber[] memory v = getValidV(proofData.vdfIndex);
        
        vm.expectEmit(true, false, false, false);
        emit Lottery.VDFProofSubmitted(address(this), gameNumber);
        
        lottery.submitVDFProof(gameNumber, v, y);
        
        assertTrue(lottery.gameVDFValid(gameNumber), "VDF should be marked as valid");

        vm.expectRevert("VDF proof already submitted for this game");
        lottery.submitVDFProof(gameNumber, v, y);
    }

    function testVerifyPastGameVDF() public {
        VDFProofData memory proofData = vdfProofs[0];

        // begin lottery
        fundLottery();

        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();

        uint256 targetBlock = block.number + lottery.DRAW_DELAY_SECURITY_BUFFER();
        vm.roll(targetBlock);

        vm.prevrandao(proofData.prevrandao);
        uint256 gameNumber = lottery.currentGameNumber() - 1;
        lottery.setRandom(gameNumber);

        // Get VDF proof data using wrapper functions
        BigNumber memory y = getValidY(proofData.vdfIndex);
        BigNumber[] memory v = getValidV(proofData.vdfIndex);

        // Submit the VDF proof
        lottery.submitVDFProof(gameNumber, v, y);
        assertTrue(lottery.gameVDFValid(gameNumber), "VDF should be marked as valid");

        // Move to the next game
        // begin lottery
        fundLottery();

        vm.warp(block.timestamp + lottery.DRAW_MIN_TIME_PERIOD() + 1);
        lottery.initiateDraw();
        
        // Now verify the past game VDF
        (uint256[4] memory calculatedNumbers, bool isValid) = lottery.verifyPastGameVDF(gameNumber, v, y);
        
        // Assert that the verification is valid
        assertTrue(isValid, "Past game VDF should be valid");
        
        // Verify the calculated numbers match the stored winning numbers
        for (uint256 i = 0; i < 4; i++) {
            uint256 storedNumber = lottery.gameWinningNumbers(gameNumber, i);
            assertEq(calculatedNumbers[i], storedNumber, "Calculated number should match the stored winning number");
        }

        // Test with slightly modified (invalid) proof
        BigNumber[] memory invalidV = v;
        if (invalidV.length > 0) {
            invalidV[0].val = bytes("invalid_proof_data");
        }
        (, bool invalidIsValid) = lottery.verifyPastGameVDF(gameNumber, invalidV, y);

        // Assert that the verification fails for invalid proof
        assertFalse(invalidIsValid, "Verification should fail for invalid proof");
    }

    // helper functions
    function getValidY(uint8 index) internal pure returns (BigNumber memory) {
        if (index == 0) return Valid_VDF_A.getY();
        if (index == 1) return Valid_VDF_B.getY();
        if (index == 2) return Valid_VDF_C.getY();
        if (index == 3) return Valid_VDF_D.getY();
        revert("Invalid VDF index");
    }

    function getValidV(uint8 index) internal pure returns (BigNumber[] memory) {
        if (index == 0) return Valid_VDF_A.getV();
        if (index == 1) return Valid_VDF_B.getV();
        if (index == 2) return Valid_VDF_C.getV();
        if (index == 3) return Valid_VDF_D.getV();
        revert("Invalid VDF index");
    }

    function getInvalidY(uint8 index) internal pure returns (BigNumber memory) {
        if (index == 0) return Invalid_VDF_A.getY();
        if (index == 1) return Invalid_VDF_B.getY();
        if (index == 2) return Invalid_VDF_C.getY();
        if (index == 3) return Invalid_VDF_D.getY();
        revert("Invalid VDF index");
    }

    function getInvalidV(uint8 index) internal pure returns (BigNumber[] memory) {
        if (index == 0) return Invalid_VDF_A.getV();
        if (index == 1) return Invalid_VDF_B.getV();
        if (index == 2) return Invalid_VDF_C.getV();
        if (index == 3) return Invalid_VDF_D.getV();
        revert("Invalid VDF index");
    }

    function generateUnbiasedRandomNumber(bytes32 seed, uint256 nonce, uint256 maxValue) internal pure returns (uint256 result) {
        uint256 maxAllowed = type(uint256).max - (type(uint256).max % maxValue);
        
        while (true) {
            uint256 randomNumber = uint256(keccak256(abi.encodePacked(seed, nonce)));
            if (randomNumber < maxAllowed) {
                result = (randomNumber % maxValue) + 1;
                break;
            }
            nonce++;
        }
        
        return result;
    }

    function getDifficultyParams(Lottery.Difficulty difficulty) internal pure returns (uint256 maxNumber, uint256 maxEtherball) {
        if (difficulty == Lottery.Difficulty.Easy) {
            return (25, 10);
        } else if (difficulty == Lottery.Difficulty.Medium) {
            return (50, 10);
        } else {
            return (75, 10);
        }
    }
}
