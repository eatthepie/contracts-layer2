// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/VDFPietrzak.sol";
import "../src/libraries/BigNumbers.sol";
import "../src/libraries/PietrzakLibrary.sol";

contract VDFPietrzakTest is Test {
    VDFPietrzak private vdf;
    BigNumber private n;
    uint256 private delta;
    uint256 private T;

    function setUp() public {
        // Initialize parameters
        n = BigNumber(hex"00c7970ceedcc3b0754490201a7aa613cd73911081c790f5f1a8726f463550bb5b9fd7ccb65812631a5cf503078400000000000000000001def1", 256);
        delta = 8;
        T = 1024;

        // Deploy the VDFPietrzak contract
        vdf = new VDFPietrzak(n, delta, T);
    }

    function testConstructor() public {
        assertEq(vdf.delta(), delta, "Delta should be set correctly");
        assertEq(vdf.T(), T, "T should be set correctly");
    }

    function testVerifyValidProof() public {
        // Generate a valid proof (this should be done off-chain in practice)
        (BigNumber[] memory v, BigNumber memory x, BigNumber memory y) = generateValidProof();

        // Verify the proof
        bool result = vdf.verifyPietrzak(v, x, y);
        assertTrue(result, "Valid proof should be verified");
    }

    function testVerifyInvalidProof() public {
        // Generate an invalid proof
        (BigNumber[] memory v, BigNumber memory x, BigNumber memory y) = generateInvalidProof();

        // Verify the proof
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, "Invalid proof should not be verified");
    }

    function testVerifyWithInvalidParameters() public {
        // Generate a valid proof
        (BigNumber[] memory v, BigNumber memory x, BigNumber memory y) = generateValidProof();

        // Modify x to make it invalid
        x = BigNumbers.add(x, BigNumber(BigNumbers.BYTESONE, BigNumbers.UINTONE));

        // Verify the proof
        bool result = vdf.verifyPietrzak(v, x, y);
        assertFalse(result, "Proof with invalid x should not be verified");
    }

    // Helper function to generate a valid proof (simplified for testing purposes)
    function generateValidProof() internal view returns (BigNumber[] memory v, BigNumber memory x, BigNumber memory y) {
        // This is a simplified proof generation for testing purposes
        // In a real scenario, this would be computed off-chain
        x = BigNumber(hex"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", 256);
        y = BigNumbers.modexp(x, BigNumbers.init(abi.encodePacked(T)), n);

        uint256 tau = PietrzakLibrary.log2(T);
        v = new BigNumber[](tau - delta);
        for (uint256 i = 0; i < tau - delta; i++) {
            v[i] = BigNumbers.modexp(x, BigNumbers.init(abi.encodePacked(uint256(1) << (tau - i - 1))), n);
        }
    }

    // Helper function to generate an invalid proof
    function generateInvalidProof() internal view returns (BigNumber[] memory v, BigNumber memory x, BigNumber memory y) {
        // Generate a valid proof first
        (v, x, y) = generateValidProof();
        // Then modify y to make it invalid
        y = BigNumbers.add(y, BigNumber(BigNumbers.BYTESONE, BigNumbers.UINTONE));
    }
}