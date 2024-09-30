// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./libraries/PietrzakLibrary.sol";

interface IMinimalPietrzak {
    function verifyPietrzak(
        BigNumber[] memory v,
        BigNumber memory x,
        BigNumber memory y
    ) external view returns (bool);
}

contract VDFPietrzak is IMinimalPietrzak {
    /* 
        VDF params - using 2048 RSA Factoring Challenge as N modulus
        https://en.wikipedia.org/wiki/RSA_Factoring_Challenge
    */
    bytes public constant nBytes = hex"c7970ceedcc3b0754490201a7aa613cd73911081c790f5f1a8726f463550bb5b7ff0db8e1ea1189ec72f93d1650011bd721aeeacc2acde32a04107f0648c2813a31f5b0b7765ff8b44b4b6ffc93384b646eb09c7cf5e8592d40ea33c80039f35b4f14a04b51f7bfd781be4d1673164ba8eb991c2c4d730bbbe35f592bdef524af7e8daefd26c66fc02c479af89d64d373f442709439de66ceb955f3ea37d5159f6135809f85334b5cb1813addc80cd05609f10ac6a95ad65872c909525bdad32bc729592642920f24c61dc5b3c3b7923e56b16a4d9d373d8721f24a3fc0f1b3131f55615172866bccc30f95054c824e733a5eb6817f7bc16399d48c6361cc7e5";
    uint256 public constant nBitLength = 2048;
    uint256 public constant delta = 4;
    uint256 public constant T = 1048576; // 2^20

    function verifyPietrzak(
        BigNumber[] memory v,
        BigNumber memory x,
        BigNumber memory y
    ) external view override returns (bool) {
        BigNumber memory n = BigNumber({
            val: nBytes,
            bitlen: nBitLength
        });
        return PietrzakLibrary.verify(v, x, y, n, delta, T);
    }
}