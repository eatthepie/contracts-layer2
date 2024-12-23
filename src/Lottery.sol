// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "witnet-solidity-bridge/contracts/interfaces/IWitnetRandomness.sol";
import "./NFTPrize.sol";

/**
    ███████╗ █████╗ ████████╗    ████████╗██╗  ██╗███████╗    ██████╗ ██╗███████╗
    ██╔════╝██╔══██╗╚══██╔══╝    ╚══██╔══╝██║  ██║██╔════╝    ██╔══██╗██║██╔════╝
    █████╗  ███████║   ██║          ██║   ███████║█████╗      ██████╔╝██║█████╗
    ██╔══╝  ██╔══██║   ██║          ██║   ██╔══██║██╔══╝      ██╔═══╝ ██║██╔══╝
    ███████╗██║  ██║   ██║          ██║   ██║  ██║███████╗    ██║     ██║███████╗
    ╚══════╝╚═╝  ╚═╝   ╚═╝          ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝     ╚═╝╚══════╝

 * @title EatThePie Layer 2 Lottery V2
 * @dev Implements a decentralized lottery system with witnet randomness and NFT prizes
 *
 */

// Permit2 interfaces
interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

contract Lottery is Ownable, ReentrancyGuard {
    // Enums
    enum Difficulty { Easy, Medium, Hard }
    enum GameStatus { InPlay, Drawing, Completed }

    /**
     * @dev Struct containing basic game information
     */
    struct GameBasicInfo {
        uint256 gameId;
        GameStatus status;
        uint256 prizePool;
        uint256 numberOfWinners;
        uint256[4] winningNumbers;
    }

    /**
     * @dev Struct containing detailed game information
     */
    struct GameDetailedInfo {
        uint256 gameId;
        GameStatus status;
        uint256 prizePool;
        uint256 numberOfWinners;
        uint256 goldWinners;
        uint256 silverWinners;
        uint256 bronzeWinners;
        uint256[4] winningNumbers;
        Difficulty difficulty;
        uint256 drawInitiatedBlock;
        uint256 randomSeed;
        uint256[3] payouts;
    }

    // L2 Specific - ERC20 token for payments
    IERC20 public immutable paymentToken;
    IPermit2 public immutable permit2;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Contracts
    NFTPrize public immutable nftPrize;

    // Constants
    uint256 private constant BASIS_POINTS = 10000;
    uint256 public constant GOLD_PERCENTAGE = 6000;
    uint256 public constant SILVER_PLACE_PERCENTAGE = 2500;
    uint256 public constant BRONZE_PLACE_PERCENTAGE = 1400;
    uint256 public constant FEE_PERCENTAGE = 100;
    uint256 public constant FEE_MAX_IN_TOKENS = 1000000 * 1e18;
    uint256 public constant EASY_MAX = 25;
    uint256 public constant EASY_ETHERBALL_MAX = 10;
    uint256 public constant MEDIUM_MAX = 50;
    uint256 public constant MEDIUM_ETHERBALL_MAX = 10;
    uint256 public constant HARD_MAX = 75;
    uint256 public constant HARD_ETHERBALL_MAX = 10;
    // uint256 public constant DRAW_MIN_TIME_PERIOD = 4 days;
    uint256 public constant DRAW_MIN_TIME_PERIOD = 1 minutes;

    // State variables
    address public feeRecipient;
    uint256 public ticketPrice;
    uint256 public currentGameNumber;
    uint256 public lastDrawTime;
    uint256 public consecutiveJackpotGames;
    uint256 public consecutiveNonJackpotGames;
    Difficulty public newDifficulty;
    uint256 public newDifficultyGame;
    uint256 public newTicketPrice;
    uint256 public newTicketPriceGameNumber;
    bool public gameStopped;

    // Witnet randomness
    IWitnetRandomness public immutable witnet;
    mapping(uint256 => uint256) public gameRandomizingBlock;

    // Mappings
    mapping(uint256 => uint256) public gameStartBlock;
    mapping(uint256 => Difficulty) public gameDifficulty;
    mapping(uint256 => uint256) public gamePrizePool;
    mapping(uint256 => uint256[4]) public gameWinningNumbers;
    mapping(uint256 => uint256[3]) public gamePayouts;
    mapping(address => mapping(uint256 => uint256)) public playerTicketCount;
    mapping(uint256 => mapping(uint32 => uint256)) public ticketCounts;
    mapping(uint256 => mapping(uint32 => mapping(address => bool))) public ticketOwners;

    mapping(uint256 => bool) public gameDrawInitiated;
    mapping(uint256 => bytes32) public gameRandomSeed;
    mapping(uint256 => uint256) public gameRandomBlock;
    mapping(uint256 => bool) public gameDrawCompleted;
    mapping(uint256 => mapping(address => bool)) public prizesClaimed;
    mapping(uint256 => uint256) public gameDrawnBlock;
    mapping(uint256 => mapping(address => bool)) public hasClaimedNFT;

    mapping(uint256 => bool) public gameRefundsEnabled;
    mapping(uint256 => mapping(address => bool)) public hasRefunded;

    // Events
    event TicketPurchased(address indexed player, uint256 gameNumber, uint256[3] numbers, uint256 etherball);
    event TicketsPurchased(address indexed player, uint256 gameNumber, uint256 ticketCount);
    event DrawInitiated(uint256 gameNumber);
    event RandomSet(uint256 gameNumber, uint256 random);
    event WinningNumbersSet(uint256 indexed gameNumber, uint256 number1, uint256 number2, uint256 number3, uint256 etherball);
    event DifficultyChanged(uint256 gameNumber, Difficulty newDifficulty);
    event TicketPriceChangeScheduled(uint256 newPrice, uint256 effectiveGameNumber);
    event ExcessPrizePoolTransferred(uint256 fromGame, uint256 toGame, uint256 amount);
    event GamePrizePayoutInfo(uint256 gameNumber, uint256 goldPrize, uint256 silverPrize, uint256 bronzePrize);
    event FeeRecipientChanged(address newFeeRecipient);
    event PrizeClaimed(uint256 gameNumber, address player, uint256 amount);
    event NFTMinted(address indexed winner, uint256 indexed tokenId, uint256 indexed gameNumber);
    event GameStopped(uint256 gameNumber);
    event GameRefundsEnabled(uint256 gameNumber);
    event TicketsRefunded(address player, uint256 gameNumber, uint256 amount);

    /**
     * @dev Constructor to initialize the Lottery contract
     * @param _witnetRandomness Address of the WitnetRandomness contract
     * @param _nftPrizeAddress Address of the NFTPrize contract
     * @param _feeRecipient Address to receive fees
     * @param _paymentToken Address of the payment token
     */
    constructor(IWitnetRandomness _witnetRandomness, address _nftPrizeAddress, address _feeRecipient, address _paymentToken) Ownable(msg.sender) {
        require(address(_witnetRandomness) != address(0), "Invalid Witnet address");
        witnet = _witnetRandomness;
        nftPrize = NFTPrize(_nftPrizeAddress);
        ticketPrice = 0.1 * 1e18; // 1 token
        currentGameNumber = 1;
        gameDifficulty[currentGameNumber] = Difficulty.Easy;
        gameStartBlock[currentGameNumber] = block.number;
        lastDrawTime = block.timestamp;
        feeRecipient = _feeRecipient;
        paymentToken = IERC20(_paymentToken);
        permit2 = IPermit2(PERMIT2_ADDRESS);
    }

    /**
     * @dev Allows users to buy multiple lottery tickets using Permit2 (100 max)
     * @param tickets Array of ticket numbers (4 numbers per ticket)
     * @param permit The Permit2 permission structure
     * @param signature The signature for the Permit2 transfer
     */
    function buyTickets(uint256[4][] calldata tickets, IPermit2.PermitTransferFrom calldata permit, bytes calldata signature) external nonReentrant {
        require(!gameStopped, "Game is stopped");
        uint256 ticketCount = tickets.length;
        require(ticketCount > 0 && ticketCount <= 100, "Invalid ticket count");

        uint256 totalCost = ticketPrice * ticketCount;
        require(permit.permitted.amount >= totalCost, "Insufficient permit amount");

        // Execute the Permit2 transfer
        permit2.permitTransferFrom(
            permit,
            IPermit2.SignatureTransferDetails({
                to: address(this),
                requestedAmount: totalCost
            }),
            msg.sender,
            signature
        );

        uint256 gameNum = currentGameNumber;
        address player = msg.sender;

        unchecked {
            gamePrizePool[gameNum] += totalCost;
            playerTicketCount[player][gameNum] += ticketCount;
        }

        for (uint256 i = 0; i < ticketCount;) {
            _processSingleTicketPurchase(
                tickets[i],
                gameNum,
                player
            );
            unchecked { ++i; }
        }

        emit TicketsPurchased(player, gameNum, ticketCount);
    }

    /**
     * @dev Process a single ticket purchase
     * @param ticketData Array of ticket numbers (3 numbers + 1 etherball)
     * @param gameNum The game number to purchase the ticket for
     */
    function _processSingleTicketPurchase(
        uint256[4] calldata ticketData,
        uint256 gameNum,
        address player
    ) internal {
        (bool valid, uint32 packedNumbers) = _validateAndPackNumbers(ticketData);
        require(valid, "Invalid numbers");

        uint32 goldTicket = packedNumbers;                    // All numbers
        uint32 silverTicket = packedNumbers & 0xFFFFFF00;     // First 3 numbers
        uint32 bronzeTicket = packedNumbers & 0xFFFF0000;     // First 2 numbers

        _updateTicketState(
            goldTicket,
            silverTicket,
            bronzeTicket,
            gameNum,
            player
        );

        emit TicketPurchased(
            player,
            gameNum,
            [ticketData[0], ticketData[1], ticketData[2]],
            ticketData[3]
        );
    }

    /**
    * @dev Validate and pack numbers into uint32
    * @param numbers Array of 4 numbers (3 main numbers + 1 etherball)
    */
    function _validateAndPackNumbers(uint256[4] calldata numbers) internal view returns (bool, uint32) {
        Difficulty difficulty = gameDifficulty[currentGameNumber];
        (uint256 maxNumber, uint256 maxEtherball) = _getDifficultyParams(difficulty);

        for (uint256 i = 0; i < 3; i++) {
            if (numbers[i] < 1 || numbers[i] > maxNumber) {
                return (false, 0);
            }
        }
        
        if (numbers[3] < 1 || numbers[3] > maxEtherball) {
            return (false, 0);
        }

        uint32 packed = uint32(
            (numbers[0] << 24) |
            (numbers[1] << 16) |
            (numbers[2] << 8) |
            numbers[3]
        );

        return (true, packed);
    }

    /**
    * @dev Update ticket state for all ticket types
    * @param goldTicket The gold ticket number
    * @param silverTicket The silver ticket number
    * @param bronzeTicket The bronze ticket number
    * @param gameNum The game number
    * @param player The player address
    */
    function _updateTicketState(
        uint32 goldTicket,
        uint32 silverTicket,
        uint32 bronzeTicket,
        uint256 gameNum,
        address player
    ) internal {
        if (!ticketOwners[gameNum][goldTicket][player]) {
            ticketOwners[gameNum][goldTicket][player] = true;
            unchecked {
                ticketCounts[gameNum][goldTicket]++;
            }
        }

        if (!ticketOwners[gameNum][silverTicket][player]) {
            ticketOwners[gameNum][silverTicket][player] = true;
            unchecked {
                ticketCounts[gameNum][silverTicket]++;
            }
        }

        if (!ticketOwners[gameNum][bronzeTicket][player]) {
            ticketOwners[gameNum][bronzeTicket][player] = true;
            unchecked {
                ticketCounts[gameNum][bronzeTicket]++;
            }
        }
    }

    /**
     * @dev Initiates the lottery draw process
     */
    function initiateDraw() external payable nonReentrant {
        require(!gameDrawInitiated[currentGameNumber], "Draw already initiated for current game");
        require(block.timestamp >= lastDrawTime + DRAW_MIN_TIME_PERIOD, "Time interval not passed");

        lastDrawTime = block.timestamp;
        gameDrawInitiated[currentGameNumber] = true;

        // Request randomness from Witnet
        gameRandomizingBlock[currentGameNumber] = block.number;
        uint256 usedFunds = witnet.randomize{value: msg.value}();

        // Refund excess payment
        if (usedFunds < msg.value) {
            payable(msg.sender).transfer(msg.value - usedFunds);
        }

        _startNextGame();

        emit DrawInitiated(currentGameNumber - 1);
    }

    /**
     * @dev Starts the next game and updates game parameters
     */
    function _startNextGame() internal {
        Difficulty currentDifficulty = gameDifficulty[currentGameNumber];

        ++currentGameNumber;
        gameStartBlock[currentGameNumber] = block.number;

        if (newDifficulty != currentDifficulty && newDifficultyGame == currentGameNumber) {
            gameDifficulty[currentGameNumber] = newDifficulty;
        } else {
            gameDifficulty[currentGameNumber] = gameDifficulty[currentGameNumber - 1];
        }

        if (newTicketPrice != 0 && newTicketPriceGameNumber == currentGameNumber) {
            require(newTicketPrice > 0, "Invalid new ticket price");
            ticketPrice = newTicketPrice;
            newTicketPrice = 0;
        }
    }

    /**
     * @dev Sets the random value for a given game
     * @param gameNumber The game number to set the random value for
     */
    function setRandomAndWinningNumbers(uint256 gameNumber) external {
        require(gameDrawInitiated[gameNumber], "Draw not initiated for this game");
        require(gameRandomSeed[gameNumber] == 0, "Random has already been set");
        require(gameRandomizingBlock[gameNumber] > 0, "Randomization not requested");

        // Fetch randomness from Witnet
        bytes32 randomness = witnet.fetchRandomnessAfter(gameRandomizingBlock[gameNumber]);
        gameRandomSeed[gameNumber] = randomness;

        _setWinningNumbers(gameNumber, randomness);
    }

    /**
     * @dev Sets the winning numbers for a given game based on randomness
     * @param gameNumber The game number to set winning numbers for
     * @param randomness The randomness value from Witnet
     */
    function _setWinningNumbers(uint256 gameNumber, bytes32 randomness) internal {
        Difficulty difficulty = gameDifficulty[gameNumber];
        (uint256 maxNumber, uint256 maxEtherball) = _getDifficultyParams(difficulty);

        uint256[4] memory winningNumbers;

        for (uint256 i = 0; i < 4; i++) {
            uint256 maxValue = i < 3 ? maxNumber : maxEtherball;
            winningNumbers[i] = _generateUnbiasedRandomNumber(randomness, i, maxValue);
        }

        gameWinningNumbers[gameNumber] = winningNumbers;
        emit WinningNumbersSet(gameNumber, winningNumbers[0], winningNumbers[1], winningNumbers[2], winningNumbers[3]);
    }

    /**
     * @dev Generates an unbiased random number within a given range
     * @param seed The seed for randomness
     * @param nonce A nonce to ensure uniqueness
     * @param maxValue The maximum value (inclusive) of the random number
     * @return A random number between 1 and maxValue
     */
    function _generateUnbiasedRandomNumber(bytes32 seed, uint256 nonce, uint256 maxValue) internal pure returns (uint256) {
        uint256 maxAllowed = type(uint256).max - (type(uint256).max % maxValue);

        while (true) {
            uint256 randomNumber = uint256(keccak256(abi.encodePacked(seed, nonce)));
            if (randomNumber < maxAllowed) {
                return (randomNumber % maxValue) + 1;
            }
            nonce++;
        }

        revert("Failed to generate unbiased random number");
    }

    /**
     * @dev Calculates and sets the payouts for a given game
     * @param gameNumber The game number to calculate payouts for
     */
    function calculatePayouts(uint256 gameNumber) external nonReentrant {
        require(gameDrawCompleted[gameNumber] != true, "Payouts already calculated for this game");
        require(gameWinningNumbers[gameNumber][0] != 0, "Winning numbers not set");

        uint256 prizePool = gamePrizePool[gameNumber];
        require(prizePool > 0, "No prize pool exists for this game");

        (uint256 goldPrize, uint256 silverPrize, uint256 bronzePrize, uint256 fee) = _calculatePrizes(prizePool);

        fee = _handleExcessFee(fee);

        (uint256 goldWinnerCount, uint256 silverWinnerCount, uint256 bronzeWinnerCount) = _getWinnerCounts(gameNumber);

        (uint256 goldPrizePerWinner, uint256 silverPrizePerWinner, uint256 bronzePrizePerWinner) = _calculatePrizesPerWinner(goldPrize, silverPrize, bronzePrize, goldWinnerCount, silverWinnerCount, bronzeWinnerCount);

        _storeGameOutcomes(gameNumber, goldPrizePerWinner, silverPrizePerWinner, bronzePrizePerWinner, goldWinnerCount);

        _handleExcessPrizePool(prizePool, goldPrizePerWinner, silverPrizePerWinner, bronzePrizePerWinner, goldWinnerCount, silverWinnerCount, bronzeWinnerCount, fee, gameNumber);

        gameDrawCompleted[gameNumber] = true;
        emit GamePrizePayoutInfo(gameNumber, goldPrizePerWinner, silverPrizePerWinner, bronzePrizePerWinner);

        _sendFee(fee);
    }

    /**
     * @dev Calculates the prizes for gold, silver, bronze, and fee
     * @param prizePool The total prize pool
     * @return goldPrize The gold prize amount
     * @return silverPrize The silver prize amount
     * @return bronzePrize The bronze prize amount
     * @return fee The fee amount
     */
    function _calculatePrizes(uint256 prizePool) internal pure returns (uint256 goldPrize, uint256 silverPrize, uint256 bronzePrize, uint256 fee) {
        goldPrize = (prizePool * GOLD_PERCENTAGE) / BASIS_POINTS;
        silverPrize = (prizePool * SILVER_PLACE_PERCENTAGE) / BASIS_POINTS;
        bronzePrize = (prizePool * BRONZE_PLACE_PERCENTAGE) / BASIS_POINTS;
        fee = (prizePool * FEE_PERCENTAGE) / BASIS_POINTS;
    }

    /**
     * @dev Handles excess fee by transferring it to the current game's prize pool
     * @param fee The calculated fee
     * @return The adjusted fee amount
     */
    function _handleExcessFee(uint256 fee) internal returns (uint256) {
        if (fee > FEE_MAX_IN_TOKENS) {
            uint256 excessFee = fee - FEE_MAX_IN_TOKENS;
            fee = FEE_MAX_IN_TOKENS;
            gamePrizePool[currentGameNumber] += excessFee;
        }
        return fee;
    }

    /**
     * @dev Gets the count of winners for each prize tier
     * @param gameNumber The game number to get winner counts for
     * @return goldWinnerCount The number of gold winners
     * @return silverWinnerCount The number of silver winners
     * @return bronzeWinnerCount The number of bronze winners
     */
    function _getWinnerCounts(uint256 gameNumber) internal view returns (
        uint256 goldWinnerCount,
        uint256 silverWinnerCount,
        uint256 bronzeWinnerCount
    ) {
        uint256[4] memory winningNumbers = gameWinningNumbers[gameNumber];
        
        uint32 packedWinning = uint32(
            (winningNumbers[0] << 24) |
            (winningNumbers[1] << 16) |
            (winningNumbers[2] << 8) |
            winningNumbers[3]
        );
        
        goldWinnerCount = ticketCounts[gameNumber][packedWinning];
        silverWinnerCount = ticketCounts[gameNumber][packedWinning & 0xFFFFFF00];
        bronzeWinnerCount = ticketCounts[gameNumber][packedWinning & 0xFFFF0000];
    }


    /**
     * @dev Calculates the prize amount per winner for each tier
     * @param goldPrize Total gold prize
     * @param silverPrize Total silver prize
     * @param bronzePrize Total bronze prize
     * @param goldWinnerCount Number of gold winners
     * @param silverWinnerCount Number of silver winners
     * @param bronzeWinnerCount Number of bronze winners
     * @return goldPrizePerWinner Prize per gold winner
     * @return silverPrizePerWinner Prize per silver winner
     * @return bronzePrizePerWinner Prize per bronze winner
     */
    function _calculatePrizesPerWinner(
        uint256 goldPrize, 
        uint256 silverPrize, 
        uint256 bronzePrize, 
        uint256 goldWinnerCount, 
        uint256 silverWinnerCount, 
        uint256 bronzeWinnerCount
    ) internal pure returns (uint256 goldPrizePerWinner, uint256 silverPrizePerWinner, uint256 bronzePrizePerWinner) {
        goldPrizePerWinner = goldWinnerCount > 0 ? goldPrize / goldWinnerCount : 0;
        silverPrizePerWinner = silverWinnerCount > 0 ? silverPrize / silverWinnerCount : 0;
        bronzePrizePerWinner = bronzeWinnerCount > 0 ? bronzePrize / bronzeWinnerCount : 0;
    }

    /**
     * @dev Stores the game outcomes and updates consecutive game counters
     * @param gameNumber The game number
     * @param goldPrizePerWinner Prize per gold winner
     * @param silverPrizePerWinner Prize per silver winner
     * @param bronzePrizePerWinner Prize per bronze winner
     * @param goldWinnerCount Number of gold winners
     */
    function _storeGameOutcomes(
        uint256 gameNumber, 
        uint256 goldPrizePerWinner, 
        uint256 silverPrizePerWinner, 
        uint256 bronzePrizePerWinner, 
        uint256 goldWinnerCount
    ) internal {
        gamePayouts[gameNumber] = [goldPrizePerWinner, silverPrizePerWinner, bronzePrizePerWinner];
        gameDrawnBlock[gameNumber] = block.number;

        if (goldWinnerCount > 0) {
            consecutiveJackpotGames++;
            consecutiveNonJackpotGames = 0;
        } else {
            consecutiveNonJackpotGames++;
            consecutiveJackpotGames = 0;
        }
    }

    /**
     * @dev Handles excess prize pool by transferring it to the next game
     * @param prizePool Total prize pool
     * @param goldPrizePerWinner Prize per gold winner
     * @param silverPrizePerWinner Prize per silver winner
     * @param bronzePrizePerWinner Prize per bronze winner
     * @param goldWinnerCount Number of gold winners
     * @param silverWinnerCount Number of silver winners
     * @param bronzeWinnerCount Number of bronze winners
     * @param fee The fee amount
     * @param gameNumber The current game number
     * @return excessPrizePool The amount of excess prize pool
     */
    function _handleExcessPrizePool(
        uint256 prizePool,
        uint256 goldPrizePerWinner,
        uint256 silverPrizePerWinner,
        uint256 bronzePrizePerWinner,
        uint256 goldWinnerCount,
        uint256 silverWinnerCount,
        uint256 bronzeWinnerCount,
        uint256 fee,
        uint256 gameNumber
    ) internal returns (uint256 excessPrizePool) {
        uint256 goldPaidOut = goldPrizePerWinner * goldWinnerCount;
        uint256 silverPaidOut = silverPrizePerWinner * silverWinnerCount;
        uint256 bronzePaidOut = bronzePrizePerWinner * bronzeWinnerCount;

        excessPrizePool = prizePool - (goldPaidOut + silverPaidOut + bronzePaidOut + fee);

        if (excessPrizePool > 0) {
            gamePrizePool[currentGameNumber] += excessPrizePool;
            emit ExcessPrizePoolTransferred(gameNumber, currentGameNumber, excessPrizePool);
        }

        return excessPrizePool;
    }

    /**
     * @dev Sends the fee to the fee recipient
     * @param fee The amount of fee to send
     */
    function _sendFee(uint256 fee) internal {
        require(paymentToken.transfer(feeRecipient, fee), "Fee transfer failed");
    }

    /**
     * @dev Allows a player to claim their prize
     * @param gameNumber The game number to claim the prize for
     */
    function claimPrize(uint256 gameNumber) external nonReentrant {
        require(gameDrawCompleted[gameNumber], "Game draw not completed yet");
        require(!prizesClaimed[gameNumber][msg.sender], "Prize already claimed");

        uint256 totalPrize = _calculateTotalPrize(gameNumber);
        require(totalPrize > 0, "No prize to claim");

        prizesClaimed[gameNumber][msg.sender] = true;
        _sendPrize(msg.sender, totalPrize);

        emit PrizeClaimed(gameNumber, msg.sender, totalPrize);
    }

    /**
     * @dev Calculates the total prize for a player in a given game
     * @param gameNumber The game number to calculate the prize for
     * @return totalPrize The total prize amount
     */
    function _calculateTotalPrize(uint256 gameNumber) internal view returns (uint256 totalPrize) {
        uint256[4] memory winningNumbers = gameWinningNumbers[gameNumber];
        uint256[3] memory payouts = gamePayouts[gameNumber];

        uint32 packedWinning = uint32(
            (winningNumbers[0] << 24) |
            (winningNumbers[1] << 16) |
            (winningNumbers[2] << 8) |
            winningNumbers[3]
        );

        if (ticketOwners[gameNumber][packedWinning][msg.sender]) {
            totalPrize += payouts[0];
        }

        uint32 silverTicket = packedWinning & 0xFFFFFF00;
        if (ticketOwners[gameNumber][silverTicket][msg.sender]) {
            totalPrize += payouts[1];
        }

        uint32 bronzeTicket = packedWinning & 0xFFFF0000;
        if (ticketOwners[gameNumber][bronzeTicket][msg.sender]) {
            totalPrize += payouts[2];
        }

        return totalPrize;
    }

    /**
     * @dev Sends the prize to the winner
     * @param winner The address of the winner
     * @param amount The amount of the prize
     */
    function _sendPrize(address winner, uint256 amount) internal {
        require(paymentToken.transfer(winner, amount), "Prize transfer failed");
    }

    /**
     * @dev Allows a gold ticket winner to mint an NFT
     * @param gameNumber The game number to mint the NFT for
     */
    function mintWinningNFT(uint256 gameNumber) external nonReentrant {
        uint256[4] memory winningNums = gameWinningNumbers[gameNumber];
        uint32 packedWinning = uint32(
            (winningNums[0] << 24) |
            (winningNums[1] << 16) |
            (winningNums[2] << 8) |
            winningNums[3]
        );

        require(ticketOwners[gameNumber][packedWinning][msg.sender], "Not a gold ticket winner");
        require(gameDrawCompleted[gameNumber] == true, "Game draw not completed yet");
        require(!hasClaimedNFT[gameNumber][msg.sender], "NFT already claimed for this game");

        uint256[3] memory payouts = gamePayouts[gameNumber];

        uint256 tokenId = uint256(keccak256(abi.encodePacked(gameNumber, msg.sender)));
        nftPrize.mintNFT(msg.sender, tokenId, gameNumber, winningNums, payouts[0]);

        hasClaimedNFT[gameNumber][msg.sender] = true;
        emit NFTMinted(msg.sender, tokenId, gameNumber);
    }

    /**
     * @dev Changes the difficulty of the game based on consecutive wins/losses
     */
    function changeDifficulty() external {
        require(currentGameNumber > 3, "Not enough games played");
        require(currentGameNumber >= newDifficultyGame + 3, "Too soon to change difficulty");

        Difficulty currentDifficulty = gameDifficulty[currentGameNumber];
        Difficulty newDifficultyValue = currentDifficulty;

        if (consecutiveJackpotGames >= 3 && currentDifficulty != Difficulty.Hard) {
            newDifficultyValue = Difficulty(uint(currentDifficulty) + 1);
        } else if (consecutiveNonJackpotGames >= 3 && currentDifficulty != Difficulty.Easy) {
            newDifficultyValue = Difficulty(uint(currentDifficulty) - 1);
        }

        if (newDifficultyValue != currentDifficulty) {
            newDifficulty = newDifficultyValue;
            newDifficultyGame = currentGameNumber + 1;
            emit DifficultyChanged(currentGameNumber + 1, newDifficultyValue);

            // Reset counters after difficulty change
            consecutiveJackpotGames = 0;
            consecutiveNonJackpotGames = 0;
        }
    }

    /**
     * @dev Returns the current game information
     * @return gameNumber The current game number
     * @return difficulty The current game difficulty
     * @return prizePool The current prize pool
     * @return drawTime The next possible draw time
     * @return timeUntilDraw The time remaining until the next draw
     */
    function getCurrentGameInfo() external view returns (
        uint256 gameNumber,
        Difficulty difficulty,
        uint256 prizePool,
        uint256 drawTime,
        uint256 timeUntilDraw
    ) {
        gameNumber = currentGameNumber;
        difficulty = gameDifficulty[gameNumber];
        prizePool = gamePrizePool[gameNumber];
        drawTime = lastDrawTime + DRAW_MIN_TIME_PERIOD;
        timeUntilDraw = drawTime > block.timestamp ? drawTime - block.timestamp : 0;
    }

    /**
     * @dev Retrieves basic information for a range of games
     * @param startGameId The ID of the first game in the range
     * @param endGameId The ID of the last game in the range
     * @return gameInfos An array of GameBasicInfo structs containing the requested game information
     */
    function getBasicGameInfo(uint256 startGameId, uint256 endGameId) external view returns (
        GameBasicInfo[] memory gameInfos
    ) {
        require(startGameId <= endGameId, "Invalid game range");
        require(endGameId - startGameId <= 10, "Max 10 games per query");
        require(endGameId <= currentGameNumber, "End game ID exceeds current game");

        uint256 gameCount = endGameId - startGameId + 1;
        gameInfos = new GameBasicInfo[](gameCount);

        for (uint256 i = 0; i < gameCount; i++) {
            uint256 gameId = startGameId + i;
            GameStatus status = gameDrawCompleted[gameId] ? GameStatus.Completed :
                                (gameDrawInitiated[gameId] ? GameStatus.Drawing : GameStatus.InPlay);

            // Pack winning numbers for efficient counting
            uint32 packedWinning = uint32(
                (gameWinningNumbers[gameId][0] << 24) |
                (gameWinningNumbers[gameId][1] << 16) |
                (gameWinningNumbers[gameId][2] << 8) |
                gameWinningNumbers[gameId][3]
            );

            // Get winner counts using packed numbers
            uint256 goldWinners = ticketCounts[gameId][packedWinning];
            uint256 silverWinners = ticketCounts[gameId][packedWinning & 0xFFFFFF00];
            uint256 bronzeWinners = ticketCounts[gameId][packedWinning & 0xFFFF0000];
            uint256 totalWinners = goldWinners + silverWinners + bronzeWinners;

            gameInfos[i] = GameBasicInfo({
                gameId: gameId,
                status: status,
                prizePool: gamePrizePool[gameId],
                numberOfWinners: totalWinners,
                winningNumbers: gameWinningNumbers[gameId]
            });
        }
    }

    /**
     * @dev Retrieves detailed information for a specific game
     * @param gameId The ID of the game to retrieve information for
     * @return A GameDetailedInfo struct containing detailed information about the specified game
     */
    function getDetailedGameInfo(uint256 gameId) external view returns (GameDetailedInfo memory) {
        require(gameId <= currentGameNumber, "Game ID exceeds current game");

        GameStatus status = gameDrawCompleted[gameId] ? GameStatus.Completed :
                            (gameDrawInitiated[gameId] ? GameStatus.Drawing : GameStatus.InPlay);

        // Pack winning numbers for efficient counting
        uint32 packedWinning = uint32(
            (gameWinningNumbers[gameId][0] << 24) |
            (gameWinningNumbers[gameId][1] << 16) |
            (gameWinningNumbers[gameId][2] << 8) |
            gameWinningNumbers[gameId][3]
        );
        
        // Get winner counts using packed numbers
        uint256 goldWinners = ticketCounts[gameId][packedWinning];
        uint256 silverWinners = ticketCounts[gameId][packedWinning & 0xFFFFFF00];
        uint256 bronzeWinners = ticketCounts[gameId][packedWinning & 0xFFFF0000];
        uint256 totalWinners = goldWinners + silverWinners + bronzeWinners;
        
        return GameDetailedInfo({
            gameId: gameId,
            status: status,
            prizePool: gamePrizePool[gameId],
            numberOfWinners: totalWinners,
            goldWinners: goldWinners,
            silverWinners: silverWinners,
            bronzeWinners: bronzeWinners,
            winningNumbers: gameWinningNumbers[gameId],
            difficulty: gameDifficulty[gameId],
            drawInitiatedBlock: gameRandomizingBlock[gameId],
            randomSeed: uint256(gameRandomSeed[gameId]),
            payouts: gamePayouts[gameId]
        });
    }

    /**
     * @dev Checks if a user has won any prize in a specific game
     * @param gameNumber The game number to check
     * @param user The address of the user to check
     * @return hasWon Boolean indicating if the user has won any prize
     */
    function hasUserWon(uint256 gameNumber, address user) external view returns (bool hasWon) {
        require(gameNumber <= currentGameNumber, "Invalid game number");
        require(gameDrawCompleted[gameNumber], "Game draw not completed yet");

        uint256[4] memory winningNums = gameWinningNumbers[gameNumber];
        uint32 packedWinning = uint32(
            (winningNums[0] << 24) |
            (winningNums[1] << 16) |
            (winningNums[2] << 8) |
            winningNums[3]
        );

        hasWon = ticketOwners[gameNumber][packedWinning][user] ||
                ticketOwners[gameNumber][packedWinning & 0xFFFFFF00][user] ||
                ticketOwners[gameNumber][packedWinning & 0xFFFF0000][user];
    }

    /**
     * @dev Gets detailed information about a user's winnings for a specific game
     * @param gameNumber The game number to check
     * @param user The address of the user to check
     * @return goldWin Boolean indicating if the user won the gold prize
     * @return silverWin Boolean indicating if the user won the silver prize
     * @return bronzeWin Boolean indicating if the user won the bronze prize
     * @return totalPrize The total prize amount won by the user
     * @return claimed Boolean indicating if the user has claimed their prize
     */
    function getUserGameWinnings(uint256 gameNumber, address user) external view returns (
        bool goldWin,
        bool silverWin,
        bool bronzeWin,
        uint256 totalPrize,
        bool claimed
    ) {
        require(gameNumber <= currentGameNumber, "Invalid game number");
        require(gameDrawCompleted[gameNumber], "Game draw not completed yet");

        uint256[4] memory winningNums = gameWinningNumbers[gameNumber];
        uint256[3] memory payouts = gamePayouts[gameNumber];
        
        uint32 packedWinning = uint32(
            (winningNums[0] << 24) |
            (winningNums[1] << 16) |
            (winningNums[2] << 8) |
            winningNums[3]
        );

        goldWin = ticketOwners[gameNumber][packedWinning][user];
        silverWin = ticketOwners[gameNumber][packedWinning & 0xFFFFFF00][user];
        bronzeWin = ticketOwners[gameNumber][packedWinning & 0xFFFF0000][user];

        if (goldWin) totalPrize += payouts[0];
        if (silverWin) totalPrize += payouts[1];
        if (bronzeWin) totalPrize += payouts[2];

        claimed = prizesClaimed[gameNumber][user];
    }

    /**
     * @dev Returns the parameters for a given difficulty level
     * @param difficulty The difficulty level
     * @return maxNumber The maximum number for main numbers
     * @return maxEtherball The maximum number for the etherball
     */
    function _getDifficultyParams(Difficulty difficulty) internal pure returns (uint256 maxNumber, uint256 maxEtherball) {
        if (difficulty == Difficulty.Easy) {
            return (EASY_MAX, EASY_ETHERBALL_MAX);
        } else if (difficulty == Difficulty.Medium) {
            return (MEDIUM_MAX, MEDIUM_ETHERBALL_MAX);
        } else {
            return (HARD_MAX, HARD_ETHERBALL_MAX);
        }
    }

    /**
     * @dev Sets a new ticket price (owner only)
     * @param _newPrice The new ticket price
     */
    function setTicketPrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "Price must be positive");
        require(_newPrice != ticketPrice, "New price must be different");
        newTicketPrice = _newPrice;
        newTicketPriceGameNumber = currentGameNumber + 10;
        emit TicketPriceChangeScheduled(_newPrice, newTicketPriceGameNumber);
    }

    /**
     * @dev Sets a new fee recipient address (owner only)
     * @param _newFeeRecipient The address of the new fee recipient
     */
    function setFeeRecipient(address _newFeeRecipient) external onlyOwner {
        require(_newFeeRecipient != address(0) && _newFeeRecipient != feeRecipient, "Invalid fee recipient address");
        feeRecipient = _newFeeRecipient;
        emit FeeRecipientChanged(_newFeeRecipient);
    }

    /**
     * @dev Emergency stop of the specified game and enable refunds (owner only)
     * @param targetGame The game to stop (current or next game)
     */
    function stopGameAndEnableRefunds(uint256 targetGame) external onlyOwner {
        require(!gameStopped, "Game already stopped");
        require(targetGame == currentGameNumber || targetGame == currentGameNumber + 1, "Can only stop current or next game");
        
        if (targetGame == currentGameNumber) {
            require(!gameDrawInitiated[currentGameNumber], "Draw already initiated");
        }
        
        gameStopped = true;
        gameRefundsEnabled[targetGame] = true;
        
        emit GameStopped(targetGame);
        emit GameRefundsEnabled(targetGame);
    }

    /**
     * @dev Allow players to refund their tickets for a stopped game
     * @param gameNumber The game number to refund tickets for
     */
    function refundTickets(uint256 gameNumber) external nonReentrant {
        require(gameRefundsEnabled[gameNumber], "Refunds not enabled for this game");
        require(!hasRefunded[gameNumber][msg.sender], "Already refunded");
        require(playerTicketCount[msg.sender][gameNumber] > 0, "No tickets to refund");

        uint256 refundAmount = playerTicketCount[msg.sender][gameNumber] * ticketPrice;
        hasRefunded[gameNumber][msg.sender] = true;

        // Update prize pool
        gamePrizePool[gameNumber] -= refundAmount;

        // Transfer refund
        require(paymentToken.transfer(msg.sender, refundAmount), "Refund transfer failed");

        emit TicketsRefunded(msg.sender, gameNumber, refundAmount);
    }
}