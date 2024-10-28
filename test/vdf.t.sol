// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/VDFPietrzak.sol";

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

contract VDFPietrzakTest is Test {
    VDFPietrzak public vdf;

    function setUp() public {
        vdf = new VDFPietrzak();
    }

    /* valid proofs */
    function testValidProof_A() public view {
        BigNumber memory x = Valid_VDF_A.getX();
        BigNumber memory y = Valid_VDF_A.getY();
        BigNumber[] memory v = Valid_VDF_A.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, string.concat("VDF A - Valid proof failed"));
    }

    function testValidProof_B() public view {
        BigNumber memory x = Valid_VDF_B.getX();
        BigNumber memory y = Valid_VDF_B.getY();
        BigNumber[] memory v = Valid_VDF_B.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, string.concat("VDF B - Valid proof failed"));
    }

    function testValidProof_C() public view {
        BigNumber memory x = Valid_VDF_C.getX();
        BigNumber memory y = Valid_VDF_C.getY();
        BigNumber[] memory v = Valid_VDF_C.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, string.concat("VDF C - Valid proof failed"));
    }

    function testValidProof_D() public view {
        BigNumber memory x = Valid_VDF_D.getX();
        BigNumber memory y = Valid_VDF_D.getY();
        BigNumber[] memory v = Valid_VDF_D.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, string.concat("VDF D - Valid proof failed"));
    }

    /* invalid proofs */
    function testInvalidProof_A() public view {
        BigNumber memory x = Invalid_VDF_A.getX();
        BigNumber memory y = Invalid_VDF_A.getY();
        BigNumber[] memory v = Invalid_VDF_A.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, string.concat("VDF A - Invalid proof succeeded"));
    }

    function testInvalidProof_B() public view {
        BigNumber memory x = Invalid_VDF_B.getX();
        BigNumber memory y = Invalid_VDF_B.getY();
        BigNumber[] memory v = Invalid_VDF_B.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, string.concat("VDF B - Invalid proof succeeded"));
    }

    function testInvalidProof_C() public view {
        BigNumber memory x = Invalid_VDF_C.getX();
        BigNumber memory y = Invalid_VDF_C.getY();
        BigNumber[] memory v = Invalid_VDF_C.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, string.concat("VDF C - Invalid proof succeeded"));
    }

    function testInvalidProof_D() public view {
        BigNumber memory x = Invalid_VDF_D.getX();
        BigNumber memory y = Invalid_VDF_D.getY();
        BigNumber[] memory v = Invalid_VDF_D.getV();
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, string.concat("VDF D - Invalid proof succeeded"));
    }
}