// used to overwrite the Lottery contract for testing purposes
// SPDX-License-Identifier: MIT
import "../../src/Lottery.sol";

contract MockLottery is Lottery {
    constructor(address _vdfContractAddress, address _nftPrizeAddress, address _feeRecipient) 
        Lottery(_vdfContractAddress, _nftPrizeAddress, _feeRecipient) {}

    function setWinningNumbersForTesting(uint256 gameNumber, uint256[4] memory numbers) external {
        require(gameVDFValid[gameNumber], "VDF must be validated first");
        gameWinningNumbers[gameNumber] = numbers;
    }

    function setInitialDifficultyForTesting(Difficulty _difficulty) external {
        gameDifficulty[currentGameNumber] = _difficulty;
    }
}
