// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BigNumbers.sol";

/// @notice This contract code adapted from usgeeus/Pietrzak-VDF-solidity-verifier
/// @dev https://github.com/usgeeus/Pietrzak-VDF-solidity-verifier/blob/main/src/libraries/PietrzakLibrary.sol
library PietrzakLibrary {
    /**
     * @dev Verifies a Pietrzak VDF proof
     * @param v Array of intermediate values in the VDF computation
     * @param x Initial input to the VDF
     * @param y Purported output of the VDF
     * @param n Modulus for RSA operations
     * @param delta Number of iterations to skip in verification
     * @param T Total number of iterations in the VDF
     * @return bool True if the proof is valid, false otherwise
     */
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
        // Main verification loop
        do {
            // Compute a random challenge based on current state
            BigNumber memory _r = _hash128(x.val, y.val, v[i].val);

            // Update x and y based on the challenge and intermediate value
            x = BigNumbers.modmul(BigNumbers.modexp(x, _r, n), v[i], n);
            if (T & 1 != 0) y = BigNumbers.modexp(y, _two, n);
            y = BigNumbers.modmul(BigNumbers.modexp(v[i], _r, n), y, n);
            unchecked {
                ++i;
                T = T >> 1;
            }
        } while (i < iMax);

        // Compute 2^delta
        uint256 twoPowerOfDelta;
        unchecked {
            twoPowerOfDelta = 1 << delta;
        }
        bytes memory twoPowerOfDeltaBytes = new bytes(32);
        assembly ("memory-safe") {
            mstore(add(twoPowerOfDeltaBytes, 32), twoPowerOfDelta)
        }

        // Final verification step
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

    /**
     * @dev Computes the base-2 logarithm of a number
     * @param value The input value
     * @return The base-2 logarithm of the input
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        uint256 exp;
        unchecked {
            exp = 128 * toUint(value > (1 << 128) - 1);
            value >>= exp;
            result += exp;

            exp = 64 * toUint(value > (1 << 64) - 1);
            value >>= exp;
            result += exp;

            exp = 32 * toUint(value > (1 << 32) - 1);
            value >>= exp;
            result += exp;

            exp = 16 * toUint(value > (1 << 16) - 1);
            value >>= exp;
            result += exp;

            exp = 8 * toUint(value > (1 << 8) - 1);
            value >>= exp;
            result += exp;

            exp = 4 * toUint(value > (1 << 4) - 1);
            value >>= exp;
            result += exp;

            exp = 2 * toUint(value > (1 << 2) - 1);
            value >>= exp;
            result += exp;

            result += toUint(value > 1);
        }
        return result;
    }

    /**
     * @dev Converts a boolean to uint256
     * @param b The boolean value to convert
     * @return u The uint256 representation (0 or 1)
     */
    function toUint(bool b) internal pure returns (uint256 u) {
        /// @solidity memory-safe-assembly
        assembly {
            u := iszero(iszero(b))
        }
    }

    /**
        * @dev Computes a 128-bit hash of three byte arrays using keccak256
        * @param a First byte array to be hashed
        * @param b Second byte array to be hashed
        * @param c Third byte array to be hashed
        * @return BigNumber The 128-bit hash result as a BigNumber
        */
    function _hash128(
        bytes memory a,
        bytes memory b,
        bytes memory c
    ) internal pure returns (BigNumber memory) {
        return
            BigNumbers.init(
                abi.encodePacked(keccak256(bytes.concat(a, b, c)) >> 128)
            );
    }
}
