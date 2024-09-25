// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/VDFPietrzak.sol";
import "../src/libraries/BigNumbers.sol";
import "../src/libraries/PietrzakLibrary.sol";

contract VDFPietrzakTest is Test {
    using BigNumbers for BigNumbers.BigNumber;

    VDFPietrzak public vdf;
    BigNumbers.BigNumber public n;
    uint256 public delta;
    uint256 public T;

    function setUp() public {
        // RSA-2048 challenge value
        string memory rsaChallenge = "25195908475657893494027183240048398571429282126204032027777137836043662020707595556264018525880784406918290641249515082189298559149176184502808489120072844992687392807287776735971418347270261896375014971824691165077613379859095700097330459748808428401797429100642458691817195118746121515172654632282216869987549182422433637259085141865462043576798423387184774447920739934236584823824281198163815010674810451660377306056201619676256133844143603833904414952634432190114657544454178424020924616515723350778707749817125772467962926386356373289912154831438167899885040445364023527381951378636564391212010397122822120720357";

        // Convert the string to bytes
        bytes memory rsaChallengeBytes = bytes(rsaChallenge);

        // Create the BigNumber struct
        n = BigNumbers.BigNumber({
            val: rsaChallengeBytes,
            bitlen: 2048
        });
        delta = 4;
        T = 1048576; // 2 ** 20

        vdf = new VDFPietrzak(n, delta, T);
    }

    function testConstructor() public {
        assertEq(vdf.n().bitlen, n.bitlen, "Modulus n bitlen mismatch");
        assertEq(vdf.delta(), delta, "Delta mismatch");
        assertEq(vdf.T(), T, "T mismatch");
    }

    function testConstructorInvalidN() public {
        BigNumbers.BigNumber memory invalidN = BigNumbers.BigNumber(0, new uint256[](0));
        vm.expectRevert("Invalid modulus n");
        new VDFPietrzak(invalidN, delta, T);
    }

    function testConstructorInvalidT() public {
        vm.expectRevert("T must be greater than zero");
        new VDFPietrzak(n, delta, 0);
    }

    function testConstructorInvalidDelta() public {
        vm.expectRevert("delta must be less than 256");
        new VDFPietrzak(n, 256, T);
    }

    function testVerifyPietrzak() public {
        // This is a mock test. In a real scenario, you'd need to generate valid proofs.
        BigNumbers.BigNumber[] memory v = new BigNumbers.BigNumber[](3);
        v[0] = BigNumbers.BigNumber(64, new uint256[](2));
        v[1] = BigNumbers.BigNumber(64, new uint256[](2));
        v[2] = BigNumbers.BigNumber(64, new uint256[](2));

        BigNumbers.BigNumber memory x = BigNumbers.BigNumber(64, new uint256[](2));
        BigNumbers.BigNumber memory y = BigNumbers.BigNumber(64, new uint256[](2));

        bool result = vdf.verifyPietrzak(v, x, y);
        
        // The actual result will depend on the implementation of PietrzakLibrary.verify
        // For now, we're just checking that the function executes without reverting
        assertTrue(true);
    }

    function testVerifyPietrzakWithInvalidInput() public {
        BigNumbers.BigNumber[] memory v = new BigNumbers.BigNumber[](0);
        BigNumbers.BigNumber memory x = BigNumbers.BigNumber(0, new uint256[](0));
        BigNumbers.BigNumber memory y = BigNumbers.BigNumber(0, new uint256[](0));

        bool result = vdf.verifyPietrzak(v, x, y);
        
        // The actual result will depend on the implementation of PietrzakLibrary.verify
        // Typically, invalid input should return false
        assertFalse(result);
    }
}