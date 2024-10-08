// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/VDFPietrzak.sol";

// valid proofs
import "../test-vdf-files/valid/block_20920622.sol";
import "../test-vdf-files/valid/block_20920632.sol";
import "../test-vdf-files/valid/block_20920642.sol";
import "../test-vdf-files/valid/block_20920652.sol";
import "../test-vdf-files/valid/block_20920662.sol";

// invalid proofs
import "../test-vdf-files/invalid/block_20920622.sol";
import "../test-vdf-files/invalid/block_20920632.sol";
import "../test-vdf-files/invalid/block_20920642.sol";
import "../test-vdf-files/invalid/block_20920652.sol";
import "../test-vdf-files/invalid/block_20920662.sol";

contract VDFPietrzakTest is Test {
    VDFPietrzak public vdf;

    function setUp() public {
        vdf = new VDFPietrzak();
    }

    /* valid proofs */
    function testValidProof_20920622() public {
        BigNumber memory x = ValidVDF_20920622.getX();
        BigNumber memory y = ValidVDF_20920622.getY();
        BigNumber[] memory v = ValidVDF_20920622.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, string.concat("Block 20920622 - Valid proof failed"));
    }

    function testValidProof_20920632() public {
        BigNumber memory x = ValidVDF_20920632.getX();
        BigNumber memory y = ValidVDF_20920632.getY();
        BigNumber[] memory v = ValidVDF_20920632.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, string.concat("Block 20920632 - Valid proof failed"));
    }

    function testValidProof_20920642() public {
        BigNumber memory x = ValidVDF_20920642.getX();
        BigNumber memory y = ValidVDF_20920642.getY();
        BigNumber[] memory v = ValidVDF_20920642.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, string.concat("Block 20920642 - Valid proof failed"));
    }

    function testValidProof_20920652() public {
        BigNumber memory x = ValidVDF_20920652.getX();
        BigNumber memory y = ValidVDF_20920652.getY();
        BigNumber[] memory v = ValidVDF_20920652.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, string.concat("Block 20920652 - Valid proof failed"));
    }

    function testValidProof_20920662() public {
        BigNumber memory x = ValidVDF_20920662.getX();
        BigNumber memory y = ValidVDF_20920662.getY();
        BigNumber[] memory v = ValidVDF_20920662.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, string.concat("Block 20920662 - Valid proof failed"));
    }

    /* invalid proofs */
    function testInvalidProof_20920622() public {
        BigNumber memory x = InvalidVDF_20920622.getX();
        BigNumber memory y = InvalidVDF_20920622.getY();
        BigNumber[] memory v = InvalidVDF_20920622.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, string.concat("20920622 - Invalid proof succeeded"));
    }

    function testInvalidProof_20920632() public {
        BigNumber memory x = InvalidVDF_20920632.getX();
        BigNumber memory y = InvalidVDF_20920632.getY();
        BigNumber[] memory v = InvalidVDF_20920632.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, string.concat("20920632 - Invalid proof succeeded"));
    }

    function testInvalidProof_20920642() public {
        BigNumber memory x = InvalidVDF_20920642.getX();
        BigNumber memory y = InvalidVDF_20920642.getY();
        BigNumber[] memory v = InvalidVDF_20920642.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, string.concat("20920642 - Invalid proof succeeded"));
    }

    function testInvalidProof_20920652() public {
        BigNumber memory x = InvalidVDF_20920652.getX();
        BigNumber memory y = InvalidVDF_20920652.getY();
        BigNumber[] memory v = InvalidVDF_20920652.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, string.concat("20920652 - Invalid proof succeeded"));
    }

    function testInvalidProof_20920662() public {
        BigNumber memory x = InvalidVDF_20920662.getX();
        BigNumber memory y = InvalidVDF_20920662.getY();
        BigNumber[] memory v = InvalidVDF_20920662.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, string.concat("20920662 - Invalid proof succeeded"));
    }
}