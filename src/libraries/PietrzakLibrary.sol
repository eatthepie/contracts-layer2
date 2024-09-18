// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BigNumbers.sol";

library PietrzakLibrary {
    using BigNumbers for BigNumbers.BigNumber;

    function verify(
        BigNumbers.BigNumber[] memory v,
        BigNumbers.BigNumber memory x,
        BigNumbers.BigNumber memory y,
        BigNumber memory n,
        uint256 delta,
        uint256 T
    ) internal view returns (bool) {
        require(T > 0, "T must be greater than zero");
        require(delta < 256, "delta must be less than 256");

        require(n.val.length > 0 && n.bitlen > 0, "Modulus n must be valid");
        require(x.val.length > 0 && x.bitlen > 0, "x must be valid");
        require(y.val.length > 0 && y.bitlen > 0, "y must be valid");

        uint256 i;
        uint256 tau = log2(T);
        uint256 iMax = tau - delta;

        require(delta < tau, "delta must be less than tau");
        require(v.length >= iMax, "v array is too short for the number of iterations");

        BigNumbers.BigNumber memory _two = BigNumbers.BigNumber(
            BigNumbers.BYTESTWO,
            BigNumbers.UINTTWO
        );

        uint256 i = 0;
        while (i < iMax) {
            BigNumbers.BigNumber memory _r = _hash128(x.val, y.val, v[i].val);

            x = x.modexp(_r, n).modmul(v[i], n);

            if (T & 1 != 0) {
                y = y.modexp(_two, n);
            }

            y = v[i].modexp(_r, n).modmul(y, n);

            i++;
            T = T >> 1;
        }

        uint256 twoPowerOfDelta = 1 << delta;
        bytes memory twoPowerOfDeltaBytes = abi.encodePacked(twoPowerOfDelta);

        BigNumbers.BigNumber memory exponent = _two.modexp(
            BigNumbers.init(twoPowerOfDeltaBytes),
            BigNumbers._powModulus(_two, twoPowerOfDelta)
        );

        BigNumbers.BigNumber memory expectedY = x.modexp(exponent, n);

        if (!y.eq(expectedY)) {
            return false;
        }

        return true;
    }

    function log2(uint256 value) internal pure returns (uint256) {
        require(value > 0, "Value must be greater than zero");
        uint256 result = 0;

        if (value >= 2**128) {
            value >>= 128;
            result += 128;
        }
        if (value >= 2**64) {
            value >>= 64;
            result += 64;
        }
        if (value >= 2**32) {
            value >>= 32;
            result += 32;
        }
        if (value >= 2**16) {
            value >>= 16;
            result += 16;
        }
        if (value >= 2**8) {
            value >>= 8;
            result += 8;
        }
        if (value >= 2**4) {
            value >>= 4;
            result += 4;
        }
        if (value >= 2**2) {
            value >>= 2;
            result += 2;
        }
        if (value >= 2) {
            result += 1;
        }

        return result;
    }

    function _hash128(
        bytes memory a,
        bytes memory b,
        bytes memory c
    ) internal pure returns (BigNumbers.BigNumber memory) {
        bytes32 hash = keccak256(bytes.concat(a, b, c));
        uint128 lowerHash = uint128(uint256(hash)); // Extract lower 128 bits
        return BigNumbers.init(abi.encodePacked(lowerHash));
    }
}
