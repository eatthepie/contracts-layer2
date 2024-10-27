// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./libraries/PietrzakLibrary.sol";

/**
 * @title VDFPietrzak
 * @dev Implementation of Pietrzak's Verifiable Delay Function (VDF)
 * This contract uses the RSA-2048 challenge number as the modulus for VDF computations
 */
contract VDFPietrzak {
    using BigNumbers for BigNumber;

    /* 
        VDF parameters - using 2048 RSA Factoring Challenge as N modulus
        https://en.wikipedia.org/wiki/RSA_Factoring_Challenge
    */
    
    /**
     * @dev The RSA-2048 challenge number in bytes
     */
    bytes public constant nBytes = hex"c7970ceedcc3b0754490201a7aa613cd73911081c790f5f1a8726f463550bb5b7ff0db8e1ea1189ec72f93d1650011bd721aeeacc2acde32a04107f0648c2813a31f5b0b7765ff8b44b4b6ffc93384b646eb09c7cf5e8592d40ea33c80039f35b4f14a04b51f7bfd781be4d1673164ba8eb991c2c4d730bbbe35f592bdef524af7e8daefd26c66fc02c479af89d64d373f442709439de66ceb955f3ea37d5159f6135809f85334b5cb1813addc80cd05609f10ac6a95ad65872c909525bdad32bc729592642920f24c61dc5b3c3b7923e56b16a4d9d373d8721f24a3fc0f1b3131f55615172866bccc30f95054c824e733a5eb6817f7bc16399d48c6361cc7e5";

    /**
     * @dev The bit length of the RSA modulus (2048 bits)
     */
    uint256 public constant nBitLength = 2048;

    /**
     * @dev The number of iterations to skip in the verification process
     * This parameter affects the trade-off between prover and verifier computation time
     */
    uint256 public constant delta = 10;

    /**
     * @dev The total number of iterations in the VDF computation (2^20)
     * This determines the delay of the function
     */
    uint256 public constant T = 67108864; // 2^26

    /**
     * @dev Verifies a Pietrzak VDF proof
     * @param v Array of intermediate values in the VDF computation
     * @param x Initial input to the VDF
     * @param y Purported output of the VDF
     * @return bool True if the proof is valid, false otherwise
     */
    function verifyPietrzak(
        BigNumber[] memory v,
        BigNumber memory x,
        BigNumber memory y
    ) external view returns (bool) {
        BigNumber memory n = BigNumber({
            val: nBytes,
            bitlen: nBitLength
        });

        return PietrzakLibrary.verify(v, x, y, n, delta, T);
    }
}
