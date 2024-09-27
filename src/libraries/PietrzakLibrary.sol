// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BigNumbers.sol";

library PietrzakLibrary {
    function verify(
        BigNumber[] memory v,
        BigNumber memory x,
        BigNumber memory y,
        BigNumber memory n,
        uint256 delta,
        uint256 T
    ) internal view returns (bool) {
        uint256 i;
        uint256 tau = log2(T);
        uint256 iMax = tau - delta;
        BigNumber memory _two = BigNumber(
            BigNumbers.BYTESTWO,
            BigNumbers.UINTTWO
        );
        do {
            BigNumber memory _r = _hash128(x.val, y.val, v[i].val);
            x = BigNumbers.modmul(BigNumbers.modexp(x, _r, n), v[i], n);
            if (T & 1 != 0) y = BigNumbers.modexp(y, _two, n);
            y = BigNumbers.modmul(BigNumbers.modexp(v[i], _r, n), y, n);
            unchecked {
                ++i;
                T = T >> 1;
            }
        } while (i < iMax);
        uint256 twoPowerOfDelta;
        unchecked {
            twoPowerOfDelta = 1 << delta;
        }
        bytes memory twoPowerOfDeltaBytes = new bytes(32);
        assembly ("memory-safe") {
            mstore(add(twoPowerOfDeltaBytes, 32), twoPowerOfDelta)
        }

        if (
            !BigNumbers.eq(
                y,
                BigNumbers.modexp(
                    x,
                    BigNumbers.modexp(
                        _two,
                        BigNumbers.init(twoPowerOfDeltaBytes),
                        BigNumbers._powModulus(_two, twoPowerOfDelta)
                    ),
                    n
                )
            )
        ) return false;
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
    ) internal pure returns (BigNumber memory) {
        bytes32 hash = keccak256(bytes.concat(a, b, c));
        uint128 lowerHash = uint128(uint256(hash)); // Extract lower 128 bits
        return BigNumbers.init(abi.encodePacked(lowerHash));
    }
}
