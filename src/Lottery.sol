// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./VDFPietrzak.sol";
import "./NFTPrize.sol";
import "./libraries/BigNumbers.sol";

contract Lottery is Ownable, ReentrancyGuard {
    // Enums
    enum Difficulty { Easy, Medium, Hard }

    // Contracts
    VDFPietrzak public vdfContract;
    NFTPrize public immutable nftPrize;

    // Constants
    /* prize pool distribution (percentages) */
    uint256 public constant GOLD_PERCENTAGE = 6000;
    uint256 public constant SILVER_PLACE_PERCENTAGE = 2500;
    uint256 public constant BRONZE_PLACE_PERCENTAGE = 1000;
    uint256 public constant LOYALTY_PERCENTAGE = 400;
    /* fees are 1%, capped at max 100ETH */
    uint256 public constant FEE_PERCENTAGE = 100;
    uint256 public constant FEE_MAX_IN_ETH = 100 ether;

    /* lottery ball numbers (max allowed numbers) */
    uint256 public constant EASY_MAX = 50;
    uint256 public constant EASY_ETHERBALL_MAX = 5;
    uint256 public constant MEDIUM_MAX = 100;
    uint256 public constant MEDIUM_ETHERBALL_MAX = 10;
    uint256 public constant HARD_MAX = 150;
    uint256 public constant HARD_ETHERBALL_MAX = 15;
    /* draw threshold */
    uint256 public constant DRAW_MIN_PRIZE_POOL = 500 ether;
    uint256 public constant DRAW_MIN_TIME_PERIOD = 1 weeks;
    uint256 public constant DRAW_DELAY_SECURITY_BUFFER = 128; // roughly 4 epoch delay for security 
    uint256 public constant BLOCKS_PER_YEAR = 3_000_000; // number of blocks before unclaimed prizes can be released

    // State Variables
    address public feeRecipient;
    uint256 public ticketPrice;
    uint256 public currentGameNumber;
    uint256 public lastDrawTime;
    /* check if game difficulty needs to be adjusted */
    uint256 public consecutiveJackpots;
    uint256 public consecutiveNoJackpots;
    /* new game difficulty - anyone can call changeDifficulty() */
    Difficulty public newDifficulty;
    uint256 public newDifficultyGame;
    uint256 public lastDifficultyChangeGame;

    /* ADMIN CHANGES (ticket price or new vdf function) HAVE A 10 GAME BUFFER */
    /* new ticket price */
    uint256 public newTicketPrice;
    uint256 public newTicketPriceGameNumber;
    /* new VDF contract - needed if RSA 2048 security gets busted in the next 3 decades */
    address public newVDFContract;
    uint256 public newVDFContractGameNumber;

    // game state
    mapping(uint256 => uint256) public gamePrizePool;
    mapping(uint256 => Difficulty) public gameDifficulty;
    mapping(uint256 => uint256[4]) public gameWinningNumbers;
    mapping(uint256 => uint256[4]) public gamePayouts; // gold, silver, bronze, loyalty
    // tickets
    mapping(uint256 => mapping(bytes32 => uint256)) public goldTicketCounts;
    mapping(uint256 => mapping(bytes32 => uint256)) public silverTicketCounts;
    mapping(uint256 => mapping(bytes32 => uint256)) public bronzeTicketCounts;
    mapping(address => mapping(uint256 => uint256)) public playerLoyaltyCount;
    mapping(address => mapping(uint256 => uint256)) public playerTicketCount;

    mapping(uint256 => mapping(bytes32 => mapping(address => bool))) public goldTicketOwners;
    mapping(uint256 => mapping(bytes32 => mapping(address => bool))) public silverTicketOwners;
    mapping(uint256 => mapping(bytes32 => mapping(address => bool))) public bronzeTicketOwners;

    // lottery numbers
    mapping(uint256 => bool) public gameDrawInitiated;
    mapping(uint256 => uint256) public gameRandomValue;
    mapping(uint256 => uint256) public gameRandomBlock;
    mapping(uint256 => bool) public gameVDFValid;
    // game results
    mapping(uint256 => bool) public gameDrawCompleted;
    mapping(uint256 => mapping(address => bool)) public prizesClaimed;
    mapping(uint256 => bool) public prizesLoyaltyDistributed;
    mapping(uint256 => bool) public gameJackpotWon;
    mapping(uint256 => uint256) public gameDrawnBlock;
    mapping(uint256 => mapping(address => bool)) public hasClaimedNFT;

    // Events
    event TicketPurchased(address indexed player, uint256 gameNumber, uint256[3] numbers, uint256 etherball);
    event DrawInitiated(uint256 gameNumber, uint256 targetSetBlock);
    event RandomSet(uint256 gameNumber, uint256 random);
    event VDFProofSubmitted(address indexed submitter, uint256 gameNumber);
    event WinningNumbersSet(uint256 indexed gameNumber, uint256 number1, uint256 number2, uint256 number3, uint256 etherball);
    event PrizesDistributed(uint256 gameNumber);
    event DifficultyChanged(uint256 gameNumber, Difficulty newDifficulty);
    event TicketsPurchased(address indexed player, uint256 gameNumber, uint256 ticketCount);
    event TicketPriceChangeScheduled(uint256 newPrice, uint256 effectiveGameNumber);
    event UnclaimedPrizeTransferred(uint256 fromGame, uint256 toGame, uint256 amount);
    event GamePrizePayoutInfo(uint256 gameNumber, uint256 goldPrize, uint256 silverPrize, uint256 bronzePrize, uint256 loyaltyPrize);
    event FeeRecipientChanged(address newFeeRecipient);
    event PrizeClaimed(uint256 gameNumber, address player, uint256 amount);
    event LoyaltyPrizeDistributed(uint256 gameNumber, address[] winners, uint256 prizePerWinner);
    event NFTMinted(address indexed winner, uint256 indexed tokenId, uint256 indexed gameNumber);
    event UnclaimedPrizesReleased(uint256 fromGame, uint256 toGame, uint256 amount);

    constructor(address _vdfContractAddress, address _nftPrizeAddress, address _feeRecipient) Ownable(msg.sender) {
        vdfContract = VDFPietrzak(_vdfContractAddress);
        nftPrize = NFTPrize(_nftPrizeAddress);
        ticketPrice = 0.1 ether;
        currentGameNumber = 1;
        gameDifficulty[currentGameNumber] = Difficulty.Easy;
        lastDrawTime = block.timestamp;
        feeRecipient = _feeRecipient;
    }

    // ticketing
    function buyTicket(uint256[3] memory numbers, uint256 etherball) external payable nonReentrant {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        _processSingleTicketPurchase(numbers, etherball);
        playerTicketCount[msg.sender][currentGameNumber] += 1;
    }

    function buyBulkTickets(uint256[4][] calldata tickets) external payable nonReentrant {
        uint256 ticketCount = tickets.length;
        require(ticketCount > 0 && ticketCount <= 100, "Invalid ticket count");
        require(msg.value == ticketPrice * ticketCount, "Incorrect total price");

        for (uint256 i = 0; i < ticketCount;) {
            _processSingleTicketPurchase([tickets[i][0], tickets[i][1], tickets[i][2]], tickets[i][3]);
            unchecked { ++i; }
        }

        playerTicketCount[msg.sender][currentGameNumber] += ticketCount;
    }

    function _processSingleTicketPurchase(uint256[3] memory numbers, uint256 etherball) internal {
        require(validateNumbers(numbers, etherball, currentGameNumber), "Invalid numbers");

        bytes32 goldTicket = computeGoldTicketHash(numbers[0], numbers[1], numbers[2], etherball);
        bytes32 silverTicket = computeSilverTicketHash(numbers[0], numbers[1], numbers[2]);
        bytes32 bronzeTicket = computeBronzeTicketHash(numbers[0], numbers[1]);

        if (!goldTicketOwners[currentGameNumber][goldTicket][msg.sender]) {
            goldTicketOwners[currentGameNumber][goldTicket][msg.sender] = true;
            goldTicketCounts[currentGameNumber][goldTicket] += 1;
        }

        if (!silverTicketOwners[currentGameNumber][silverTicket][msg.sender]) {
            silverTicketOwners[currentGameNumber][silverTicket][msg.sender] = true;
            silverTicketCounts[currentGameNumber][silverTicket] += 1;
        }

        if (!bronzeTicketOwners[currentGameNumber][bronzeTicket][msg.sender]) {
            bronzeTicketOwners[currentGameNumber][bronzeTicket][msg.sender] = true;
            bronzeTicketCounts[currentGameNumber][bronzeTicket] += 1;
        }

        _updateLoyaltyCount(msg.sender, currentGameNumber);
        gamePrizePool[currentGameNumber] += ticketPrice;

        emit TicketPurchased(msg.sender, currentGameNumber, numbers, etherball);
    }

    function _updateLoyaltyCount(address player, uint256 gameNumber) internal {
        if (playerLoyaltyCount[player][gameNumber] == 0) {
            playerLoyaltyCount[player][gameNumber] = playerLoyaltyCount[player][gameNumber - 1] > 0 
                ? playerLoyaltyCount[player][gameNumber - 1] + 1 
                : 1;
        }
    }

    function validateNumbers(uint256[3] memory numbers, uint256 etherball, uint256 gameNumber) internal view returns (bool) {
        Difficulty difficulty = gameDifficulty[gameNumber];
        (uint256 maxNumber, uint256 maxEtherball) = getDifficultyParams(difficulty);

        for (uint256 i = 0; i < 3; i++) {
            if (numbers[i] < 1 || numbers[i] > maxNumber) {
                return false;
            }
        }

        if (etherball < 1 || etherball > maxEtherball) {
            return false;
        }

        return true;
    }

    // ticket hashes
    function computeBronzeTicketHash(uint256 numberOne, uint256 numberTwo) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(numberOne, numberTwo));
    }

    function computeSilverTicketHash(uint256 numberOne, uint256 numberTwo, uint256 numberThree) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(numberOne, numberTwo, numberThree));
    }

    function computeGoldTicketHash(uint256 numberOne, uint256 numberTwo, uint256 numberThree, uint256 etherball) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(numberOne, numberTwo, numberThree, etherball));
    }

    // drawing
    function initiateDraw() external nonReentrant {
        require(!gameDrawInitiated[currentGameNumber], "Draw already initiated for current game");
        require(block.timestamp >= lastDrawTime + DRAW_MIN_TIME_PERIOD, "Time interval not passed");
        require(gamePrizePool[currentGameNumber] >= DRAW_MIN_PRIZE_POOL, "Insufficient prize pool");

        // Record the draw initiation
        lastDrawTime = block.timestamp;
        gameDrawInitiated[currentGameNumber] = true;

        // Calculate target block for randomness
        uint256 targetSetBlock = block.number + DRAW_DELAY_SECURITY_BUFFER;
        require(targetSetBlock > block.number, "Invalid target block");
        gameRandomBlock[currentGameNumber] = targetSetBlock;

        // Increment game number for the next game
        ++currentGameNumber;

        // check for difficulty changes
        if (newDifficulty != Difficulty(0) && newDifficultyGame == currentGameNumber) {
            gameDifficulty[currentGameNumber] = newDifficulty;
            newDifficulty = Difficulty(0);
        } else {
            gameDifficulty[currentGameNumber] = gameDifficulty[currentGameNumber - 1];
        }

        // check ticket price changes
        if (newTicketPrice != 0 && newTicketPriceGameNumber == currentGameNumber) {
            require(newTicketPrice > 0, "Invalid new ticket price");
            ticketPrice = newTicketPrice;
            newTicketPrice = 0;
        }

        // check vdf contract changes
        if (newVDFContract != address(0) && newVDFContractGameNumber == currentGameNumber) {
            vdfContract = VDFPietrzak(newVDFContract);
            newVDFContract = address(0);
        }

        emit DrawInitiated(currentGameNumber - 1, targetSetBlock);
    }

    function setRandom(uint256 gameNumber) external {
        require(gameDrawInitiated[gameNumber], "Draw not initiated for this game");
        require(block.number >= gameRandomBlock[gameNumber], "Buffer period not yet passed");
        require(gameRandomValue[gameNumber] == 0, "Random has already been set");
        gameRandomValue[gameNumber] = block.prevrandao;
        emit RandomSet(gameNumber, block.prevrandao);
    }

    function submitVDFProof(uint256 gameNumber, BigNumber[] memory v, BigNumber memory y) external nonReentrant {
        require(gameRandomValue[gameNumber] != 0, "Random value not set for this game");
        require(!gameVDFValid[gameNumber], "VDF proof already submitted for this game");

        // VDF Verification
        BigNumber memory x = BigNumbers.init(abi.encodePacked(gameRandomValue[gameNumber]));
        bool isValid = vdfContract.verifyPietrzak(v, x, y);
        require(isValid, "Invalid VDF proof");

        gameVDFValid[gameNumber] = true;
        setWinningNumbers(gameNumber, y.val);
        emit VDFProofSubmitted(msg.sender, gameNumber);
    }

    function setWinningNumbers(uint256 gameNumber, bytes memory vdfOutput) internal {
        Difficulty difficulty = gameDifficulty[gameNumber];
        (uint256 maxNumber, uint256 maxEtherball) = getDifficultyParams(difficulty);

        // Use the vdfOutput to generate random numbers
        bytes32 randomSeed = keccak256(vdfOutput);
        uint256[4] memory winningNumbers;

        for (uint256 i = 0; i < 4; i++) {
            uint256 maxValue = i < 3 ? maxNumber : maxEtherball;
            winningNumbers[i] = generateUnbiasedRandomNumber(randomSeed, i, maxValue);
        }

        gameWinningNumbers[gameNumber] = winningNumbers;
        emit WinningNumbersSet(gameNumber, winningNumbers[0], winningNumbers[1], winningNumbers[2], winningNumbers[3]);
    }

    function generateUnbiasedRandomNumber(bytes32 seed, uint256 nonce, uint256 maxValue) internal pure returns (uint256) {
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

    function verifyPastGameVDF(uint256 gameNumber, BigNumber[] memory v, BigNumber memory y) external view returns (uint256[4] memory calculatedNumbers, bool isValid) {
        require(gameNumber < currentGameNumber, "Game has not ended yet");
        require(gameRandomValue[gameNumber] != 0, "Random value not set for this game");

        // Verify the VDF proof
        BigNumber memory x = BigNumbers.init(abi.encodePacked(gameRandomValue[gameNumber]));
        isValid = vdfContract.verifyPietrzak(v, x, y);

        if (!isValid) {
            return (calculatedNumbers, false);
        }

        // If the proof is valid, calculate the winning numbers
        Difficulty difficulty = gameDifficulty[gameNumber];
        (uint256 maxNumber, uint256 maxEtherball) = getDifficultyParams(difficulty);

        bytes32 randomSeed = keccak256(y.val);

        for (uint256 i = 0; i < 4; i++) {
            uint256 maxValue = i < 3 ? maxNumber : maxEtherball;
            calculatedNumbers[i] = generateUnbiasedRandomNumber(randomSeed, i, maxValue);
        }

        // Compare calculated winning numbers with stored winning numbers
        for (uint256 i = 0; i < 4; i++) {
            if (calculatedNumbers[i] != gameWinningNumbers[gameNumber][i]) {
                isValid = false;
                break;
            }
        }

        return (calculatedNumbers, isValid);
    }

    function calculatePayouts(uint256 gameNumber) external nonReentrant {
        require(gameVDFValid[gameNumber], "VDF proof not yet validated for this game");
        require(gameDrawCompleted[gameNumber] != true, "Payouts already calculated for this game");

        uint256 prizePool = gamePrizePool[gameNumber];
        uint256 goldPrize = (prizePool * GOLD_PERCENTAGE) / 10000;
        uint256 silverPrize = (prizePool * SILVER_PLACE_PERCENTAGE) / 10000;
        uint256 bronzePrize = (prizePool * BRONZE_PLACE_PERCENTAGE) / 10000;
        uint256 loyaltyPrize = (prizePool * LOYALTY_PERCENTAGE) / 10000;
        uint256 fee = (prizePool * FEE_PERCENTAGE) / 10000;
    
        if (fee > FEE_MAX_IN_ETH) {
            fee = FEE_MAX_IN_ETH;
            // Add the excess fee to the next game's prize pool
            gamePrizePool[currentGameNumber] += (fee - FEE_MAX_IN_ETH);
        }

        uint256[4] memory winningNumbers = gameWinningNumbers[gameNumber];
        bytes32 goldTicketHash = computeGoldTicketHash(winningNumbers[0], winningNumbers[1], winningNumbers[2], winningNumbers[3]);
        bytes32 silverTicketHash = computeSilverTicketHash(winningNumbers[0], winningNumbers[1], winningNumbers[2]);
        bytes32 bronzeTicketHash = computeBronzeTicketHash(winningNumbers[0], winningNumbers[1]);

        uint256 goldWinnerCount = goldTicketCounts[gameNumber][goldTicketHash];
        uint256 silverWinnerCount = silverTicketCounts[gameNumber][silverTicketHash];
        uint256 bronzeWinnerCount = bronzeTicketCounts[gameNumber][bronzeTicketHash];

        uint256 goldPrizePerWinner = goldWinnerCount > 0 ? goldPrize / goldWinnerCount : 0;
        uint256 silverPrizePerWinner = silverWinnerCount > 0 ? silverPrize / silverWinnerCount : 0;
        uint256 bronzePrizePerWinner = bronzeWinnerCount > 0 ? bronzePrize / bronzeWinnerCount : 0;
        uint256 loyaltyTotalPrize = bronzeWinnerCount > 0 ? loyaltyPrize : 0;

        // Calculate paid out amounts (which may be less than the total prize due to rounding down)
        uint256 goldPaidOut = goldPrizePerWinner * goldWinnerCount;
        uint256 silverPaidOut = silverPrizePerWinner * silverWinnerCount;
        uint256 bronzePaidOut = bronzePrizePerWinner * bronzeWinnerCount;

        // Calculate unclaimed prizes
        uint256 unclaimedPrize = prizePool - (goldPaidOut + silverPaidOut + bronzePaidOut + loyaltyTotalPrize + fee);

        // Store game outcomes and payout information
        gamePayouts[gameNumber] = [goldPrizePerWinner, silverPrizePerWinner, bronzePrizePerWinner, loyaltyTotalPrize];
        gameJackpotWon[gameNumber] = (goldWinnerCount > 0);
        gameDrawnBlock[gameNumber] = block.number;

        // Transfer unclaimed prize to the next game
        if (unclaimedPrize > 0) {
            gamePrizePool[currentGameNumber] += unclaimedPrize;
            emit UnclaimedPrizeTransferred(gameNumber, currentGameNumber, unclaimedPrize);
        }

        // Mark the game as completed
        gameDrawCompleted[gameNumber] = true;

        // Emit event with payout information
        emit GamePrizePayoutInfo(gameNumber, goldPrizePerWinner, silverPrizePerWinner, bronzePrizePerWinner, loyaltyPrize);

        // Transfer fees to the fee recipient
        (bool success, ) = payable(feeRecipient).call{value: fee}("");
        require(success, "Fee transfer failed");
    }

    function claimPrize(uint256 gameNumber) external nonReentrant {
        require(gameDrawCompleted[gameNumber] == true, "Game draw not completed yet");
        require(prizesClaimed[gameNumber][msg.sender] != true, "Prize already claimed");

        uint256[4] memory payouts = gamePayouts[gameNumber];
        uint256 totalPrize = 0;

        // Check Gold prize
        bytes32 goldTicketHash = computeGoldTicketHash(gameWinningNumbers[gameNumber][0], gameWinningNumbers[gameNumber][1], gameWinningNumbers[gameNumber][2], gameWinningNumbers[gameNumber][3]);
        if (goldTicketOwners[gameNumber][goldTicketHash][msg.sender]) {
            totalPrize += payouts[0];
        }

        // Check Silver prize
        bytes32 silverTicketHash = computeSilverTicketHash(gameWinningNumbers[gameNumber][0], gameWinningNumbers[gameNumber][1], gameWinningNumbers[gameNumber][2]);
        if (silverTicketOwners[gameNumber][silverTicketHash][msg.sender]) {
            totalPrize += payouts[1];
        }

        // Check Bronze prize
        bytes32 bronzeTicketHash = computeBronzeTicketHash(gameWinningNumbers[gameNumber][0], gameWinningNumbers[gameNumber][1]);
        if (bronzeTicketOwners[gameNumber][bronzeTicketHash][msg.sender]) {
            totalPrize += payouts[2];
        }

        require(totalPrize > 0, "No prize to claim");

        prizesClaimed[gameNumber][msg.sender] = true;
        (bool success, ) = payable(msg.sender).call{value: totalPrize}("");
        require(success, "Transfer failed");

        emit PrizeClaimed(gameNumber, msg.sender, totalPrize);
    }

    function distributeLoyaltyPrize(uint256 gameNumber, address[] calldata addresses) external nonReentrant {
        require(gameDrawCompleted[gameNumber], "Prizes not yet calculated for this game");
        require(!prizesLoyaltyDistributed[gameNumber], "Loyalty prizes already distributed for this game");

        bytes32 bronzeTicketHash = computeBronzeTicketHash(gameWinningNumbers[gameNumber][0], gameWinningNumbers[gameNumber][1]);
        uint256 bronzeWinnerCount = bronzeTicketCounts[gameNumber][bronzeTicketHash];
        require(addresses.length == bronzeWinnerCount, "You must provide all winners for this game");

        uint256 winningNumber = 0;
        uint256 winningCounter = 0;
        address[] memory winners = new address[](bronzeWinnerCount);

        for (uint256 i = 0; i < addresses.length; i++) {
            require(bronzeTicketOwners[gameNumber][bronzeTicketHash][addresses[i]], "Invalid address");
            uint256 gamePlayerLoyaltyCount = playerLoyaltyCount[addresses[i]][gameNumber];
            if (gamePlayerLoyaltyCount > winningNumber) {
                winningNumber = gamePlayerLoyaltyCount;
                winningCounter = 1;
                winners[0] = addresses[i];
            } else if (gamePlayerLoyaltyCount == winningNumber) {
                winners[winningCounter] = addresses[i];
                winningCounter++;
            }
        }

        uint256 loyaltyPrize = gamePayouts[gameNumber][3];
        require(loyaltyPrize > 0, "No loyalty prize for this game");
        
        uint256 loyaltyPrizePerWinner = loyaltyPrize / winningCounter;
        require(loyaltyPrizePerWinner > 0, "Loyalty prize per winner is zero");

        address[] memory winningAddresses = new address[](winningCounter);
        for (uint256 i = 0; i < winningCounter; i++) {
            (bool success, ) = payable(winners[i]).call{value: loyaltyPrizePerWinner}("");
            require(success, "Transfer failed");
            winningAddresses[i] = winners[i];
        }

        prizesLoyaltyDistributed[gameNumber] = true;
        emit LoyaltyPrizeDistributed(gameNumber, winningAddresses, loyaltyPrizePerWinner);
    }

    function mintWinningNFT(uint256 gameNumber) external nonReentrant {
        bytes32 goldTicketHash = computeGoldTicketHash(gameWinningNumbers[gameNumber][0], gameWinningNumbers[gameNumber][1], gameWinningNumbers[gameNumber][2], gameWinningNumbers[gameNumber][3]);

        require(goldTicketOwners[gameNumber][goldTicketHash][msg.sender], "Not a gold ticket winner");
        require(gameDrawCompleted[gameNumber] == true, "Game draw not completed yet");
        require(!hasClaimedNFT[gameNumber][msg.sender], "NFT already claimed for this game");

        uint256[4] memory payouts = gamePayouts[gameNumber];

        uint256 tokenId = uint256(keccak256(abi.encodePacked(gameNumber, msg.sender)));
        nftPrize.mintNFT(msg.sender, tokenId, gameNumber, gameWinningNumbers[gameNumber], payouts[0]);

        hasClaimedNFT[gameNumber][msg.sender] = true;
        emit NFTMinted(msg.sender, tokenId, gameNumber);
    }

    function releaseUnclaimedPrizes(uint256 gameNumber) external {
        require(gameDrawCompleted[gameNumber] == true, "Game must be completed");
        require(block.number >= gameDrawnBlock[gameNumber] + BLOCKS_PER_YEAR && gameDrawnBlock[gameNumber] != 0, "Must wait 1 year after game");
        require(gamePrizePool[gameNumber] > 0, "Prize pool must be non-zero");

        uint256 unclaimedAmount = gamePrizePool[gameNumber];
        gamePrizePool[gameNumber] = 0;
        gamePrizePool[currentGameNumber] += unclaimedAmount;

        emit UnclaimedPrizesReleased(gameNumber, currentGameNumber, unclaimedAmount);
    }

    function changeDifficulty() external {
        require(currentGameNumber > 3, "Not enough games played");
        require(currentGameNumber > lastDifficultyChangeGame + 3, "Too soon to change difficulty");

        uint256 jackpotCount = 0;
        for (uint256 i = currentGameNumber - 3; i < currentGameNumber; i++) {
            if (gameJackpotWon[i]) {
                jackpotCount++;
            }
        }

        Difficulty currentDifficulty = gameDifficulty[currentGameNumber];
        Difficulty newGameDifficulty = currentDifficulty;

        if (jackpotCount == 3 && currentDifficulty != Difficulty.Hard) {
            newGameDifficulty = Difficulty(uint(currentDifficulty) + 1);
        } else if (jackpotCount == 0 && currentDifficulty != Difficulty.Easy) {
            newGameDifficulty = Difficulty(uint(currentDifficulty) - 1);
        }

        if (newGameDifficulty != currentDifficulty) {
            gameDifficulty[currentGameNumber + 1] = newGameDifficulty;
            lastDifficultyChangeGame = currentGameNumber;
            emit DifficultyChanged(currentGameNumber + 1, newGameDifficulty);
        }
    }

    // helper functions
    function getCurrentGameInfo() public view returns (
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

    function getDifficultyParams(Difficulty difficulty) internal pure returns (uint256 maxNumber, uint256 maxEtherball) {
        if (difficulty == Difficulty.Easy) {
            return (EASY_MAX, EASY_ETHERBALL_MAX);
        } else if (difficulty == Difficulty.Medium) {
            return (MEDIUM_MAX, MEDIUM_ETHERBALL_MAX);
        } else {
            return (HARD_MAX, HARD_ETHERBALL_MAX);
        }
    }

    // admin functions
    function setTicketPrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "Price must be positive");
        require(_newPrice != ticketPrice, "New price must be different");
        newTicketPrice = _newPrice;
        newTicketPriceGameNumber = currentGameNumber + 10;
        emit TicketPriceChangeScheduled(_newPrice, newTicketPriceGameNumber);
    }

    function setNewVDFContract(address _newVDFContract) external onlyOwner {
        require(_newVDFContract != address(0) && _newVDFContract != address(vdfContract), "Invalid VDF contract address");
        newVDFContract = _newVDFContract;
        newVDFContractGameNumber = currentGameNumber + 10;
    }

    function setFeeRecipient(address _newFeeRecipient) external onlyOwner {
        require(_newFeeRecipient != address(0) && _newFeeRecipient != feeRecipient, "Invalid fee recipient address");
        feeRecipient = _newFeeRecipient;
        emit FeeRecipientChanged(_newFeeRecipient);
    }

    // fallback send ETH to prize pool
    receive() external payable {
        gamePrizePool[currentGameNumber] += msg.value;
    }
}