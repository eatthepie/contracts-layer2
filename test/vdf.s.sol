// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/VDFPietrzak.sol";

import "../test-vdf-files/valid/a.sol";
import "../test-vdf-files/invalid/a.sol";

contract VDFPietrzakTest is Test {
    VDFPietrzak public vdf;

    function setUp() public {
        vdf = new VDFPietrzak();
    }

    function testValidProof() public {
        BigNumber memory x = ValidVDF.getX();
        BigNumber memory y = ValidVDF.getY();
        BigNumber[] memory v = ValidVDF.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, string.concat("Valid proof failed"));
    }

    function testInvalidProof() public {
        BigNumber memory x = InvalidVDF.getX();
        BigNumber memory y = InvalidVDF.getY();
        BigNumber[] memory v = InvalidVDF.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, string.concat("Invalid proof succeeded"));
    }
}