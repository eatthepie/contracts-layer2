// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./libraries/PietrzakLibrary.sol";
import "./libraries/BigNumbers.sol";

interface IMinimalPietrzak {
    function verifyPietrzak(
        BigNumber[] memory v,
        BigNumber memory x,
        BigNumber memory y
    ) external view returns (bool);
}

contract VDFPietrzak is IMinimalPietrzak {
    using BigNumbers for BigNumbers.BigNumber;

    BigNumbers.BigNumber public n;
    uint256 public immutable delta;
    uint256 public immutable T;

    constructor(
        BigNumbers.BigNumber memory _n,
        uint256 _delta,
        uint256 _T
    ) {
        require(_n.val.length > 0 && _n.bitlen > 0, "Invalid modulus n");
        require(_T > 0, "T must be greater than zero");
        require(_delta < 256, "delta must be less than 256");

        n = _n;
        delta = _delta;
        T = _T;
    }

    function verifyPietrzak(
        BigNumbers.BigNumber[] memory v,
        BigNumbers.BigNumber memory x,
        BigNumbers.BigNumber memory y
    ) external view override returns (bool) {
        return PietrzakLibrary.verify(v, x, y, n, delta, T);
    }
}
