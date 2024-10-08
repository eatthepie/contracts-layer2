// SPDX-License-Identifier: MIT
import "../../src/Lottery.sol";

contract MockLottery is Lottery {
    constructor(address _vdfContractAddress, address _nftPrizeAddress, address _feeRecipient) 
        Lottery(_vdfContractAddress, _nftPrizeAddress, _feeRecipient) {}

    // function setGameJackpotWon(uint256 gameNumber, bool won) public {
    //     gameJackpotWon[gameNumber] = won;
    // }

    function setWinningNumbersForTesting(uint256 gameNumber, uint256[4] memory numbers) external {
        require(gameVDFValid[gameNumber], "VDF must be validated first");
        gameWinningNumbers[gameNumber] = numbers;
    }
}
