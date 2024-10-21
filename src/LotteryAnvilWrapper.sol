/* Wrapper to use valid block.prevrandao values */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./Lottery.sol";

contract LotteryAnvilWrapper is Lottery {
    Lottery private immutable lottery;

    constructor(address _lotteryAddress, uint256[] memory _prevrandaoValues) {
        lottery = Lottery(_lotteryAddress);
        prevrandaoValues = _prevrandaoValues;
    }

    function setRandom(uint256 gameNumber) external override {
        require(gameDrawInitiated[gameNumber], "Draw not initiated for this game");
        require(block.number >= gameRandomBlock[gameNumber], "Buffer period not yet passed");
        require(gameRandomValue[gameNumber] == 0, "Random has already been set");
        
        uint256 randomValue = prevrandaoValues[currentIndex];
        gameRandomValue[gameNumber] = randomValue;
        emit RandomSet(gameNumber, randomValue);

        currentIndex = (currentIndex + 1) % prevrandaoValues.length;
    }

    function resetIndex() external {
        currentIndex = 0;
    }

    // Fallback function to delegate all other calls to the original Lottery contract
    fallback() external payable {
        address _target = address(_lottery);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

// IMPORTANT: About the LotteryAnvilWrapper
// ------------------------------------------------------
// The LotteryAnvilWrapper is for local testing on Anvil because:
//
// 1. Anvil Limitation: 
//    Anvil doesn't fully support block.prevrandao, which is used in the 
//    main Lottery contract for randomness generation. 
//    On Anvil, block.prevrandao always returns 0, which would break 
//    the Lottery's randomness mechanism.
//
// 2. Wrapper Solution:
//    The wrapper uses a list of values taken from Ethereum mainnet for testing.