// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title NFTPrize
 * @dev ERC721 token representing lottery winning tickets with dynamic SVG generation
 */
contract NFTPrize is ERC721 {
    using Strings for uint256;

    struct NumberSVG {
        bytes path;
        uint256 width;
    }

    mapping(uint256 => NumberSVG) private numberSVGs;
    address public lotteryContract;
    bool private initialized;

    mapping(uint256 => uint256) private tokenGameNumbers;
    mapping(uint256 => uint256[4]) private tokenWinningNumbers;
    mapping(uint256 => uint256) private tokenPayouts;

    constructor() ERC721("EatThePieNFT", "ETPNFT") {
        initializeNumberSVGs();
    }

    /**
     * @dev Sets the lottery contract address. Can only be called once.
     * @param _lotteryContract Address of the lottery contract
     */
    function setLotteryContract(address _lotteryContract) external {
        require(!initialized, "Already initialized");
        require(_lotteryContract != address(0), "Invalid lottery contract address");
        lotteryContract = _lotteryContract;
        initialized = true;
    }

    /**
     * @dev Initializes SVG paths for numbers 0-9
     */
    function initializeNumberSVGs() private {
        numberSVGs[0] = NumberSVG(abi.encodePacked('<path d="M47.4207 72.5C43.6874 73.4333 39.054 73.9 33.5207 73.9C27.9874 73.9 23.3207 73.4333 19.5207 72.5C15.7874 71.5 12.3874 69.7 9.3207 67.1C3.25404 61.9667 0.220703 51.9333 0.220703 37C0.220703 22.6 3.38737 12.8333 9.7207 7.69999C12.854 5.16666 16.2874 3.4 20.0207 2.4C23.754 1.4 28.2207 0.899998 33.4207 0.899998C38.6874 0.899998 43.1874 1.4 46.9207 2.4C50.7207 3.4 54.1874 5.16666 57.3207 7.69999C63.654 12.8333 66.8207 22.6 66.8207 37C66.8207 51.9333 63.7874 61.9667 57.7207 67.1C54.654 69.7 51.2207 71.5 47.4207 72.5ZM31.4207 56.9C31.954 57.7667 32.654 58.2 33.5207 58.2C34.454 58.2 35.1874 57.7667 35.7207 56.9C36.254 55.9667 36.6874 53.9667 37.0207 50.9C37.354 47.8333 37.5207 43.4667 37.5207 37.8C37.5207 32.1333 37.354 27.7333 37.0207 24.6C36.6874 21.4 36.254 19.3 35.7207 18.3C35.1874 17.2333 34.454 16.7 33.5207 16.7C32.654 16.7 31.954 17.2 31.4207 18.2C30.0874 20.4667 29.4207 27 29.4207 37.8C29.4207 48.5333 30.0874 54.9 31.4207 56.9Z" fill="black"/>'), 67);
        numberSVGs[1] = NumberSVG(abi.encodePacked('<path d="M40.1438 69.6C40.1438 70.3333 38.1104 70.9333 34.0438 71.4C29.9771 71.8 25.9104 72 21.8438 72C17.7771 72 15.1438 71.8333 13.9438 71.5C12.8104 71.1 12.2438 70.4667 12.2438 69.6V26.4H2.04375C0.910417 26.4 0.34375 23.9667 0.34375 19.1C0.34375 14.2333 0.910417 9.83333 2.04375 5.9C2.37708 4.63333 5.91042 3.46666 12.6438 2.4C19.3771 1.33333 24.5438 0.799999 28.1438 0.799999C31.7438 0.799999 34.1438 0.933332 35.3438 1.2C36.5438 1.46666 37.4438 1.8 38.0438 2.2C38.6438 2.53333 39.1104 2.93333 39.4438 3.4C39.9104 4.13333 40.1438 4.83333 40.1438 5.5V69.6Z" fill="black"/>'), 41);
        numberSVGs[2] = NumberSVG(abi.encodePacked('<path d="M7.68711 27.9C5.82044 27.9 4.18711 25.7 2.78711 21.3C1.45378 16.9 0.787109 12.6667 0.787109 8.59999C0.787109 7.66666 1.82044 6.63333 3.88711 5.5C5.95378 4.3 9.08711 3.23333 13.2871 2.3C17.4871 1.36667 22.0538 0.899998 26.9871 0.899998C46.1204 0.899998 55.6871 7.6 55.6871 21C55.6871 24.7333 54.8871 28.2333 53.2871 31.5C51.6871 34.7667 49.9204 37.4 47.9871 39.4C46.0538 41.3333 43.7871 43.1333 41.1871 44.8C38.1871 46.6667 35.3204 48.1333 32.5871 49.2H52.5871C52.9871 49.2 53.4204 49.4 53.8871 49.8C54.3538 50.1333 54.8538 51.2 55.3871 53C55.9204 54.7333 56.1871 56.9333 56.1871 59.6C56.1871 62.2 56.0204 64.4 55.6871 66.2C55.3538 67.9333 54.9538 69.2 54.4871 70C53.4871 71.8 52.5871 72.7667 51.7871 72.9L51.2871 73H7.48711C3.28711 73 1.18711 66.4333 1.18711 53.3C1.18711 51.8333 5.52044 47.8 14.1871 41.2C17.4538 38.8 20.4538 36.1667 23.1871 33.3C25.9204 30.4333 27.2871 28.1 27.2871 26.3C27.2871 24.3 25.7871 23.3 22.7871 23.3C19.7871 23.3 16.6204 24.0667 13.2871 25.6C10.0204 27.1333 8.15378 27.9 7.68711 27.9Z" fill="black"/>'), 57);
        numberSVGs[3] = NumberSVG(abi.encodePacked('<path d="M54.0313 19.6C54.0313 26.3333 51.3646 31.3667 46.0313 34.7C46.7646 35.0333 47.6979 35.8333 48.8313 37.1C50.0313 38.3667 51.0313 39.6333 51.8313 40.9C53.8979 44.1667 54.9313 48.0333 54.9313 52.5C54.9313 59.8333 52.2979 65.2333 47.0312 68.7C41.7646 72.1667 34.5313 73.9 25.3313 73.9C20.7979 73.9 16.4979 73.5333 12.4313 72.8C8.43125 72 5.36458 71.1333 3.23125 70.2C1.09792 69.2 0.0312501 68.3 0.0312501 67.5C0.0312501 63.8333 0.43125 60.6 1.23125 57.8C2.03125 55 2.93125 53.0333 3.93125 51.9C4.93125 50.7 5.89792 50.1 6.83125 50.1C7.09792 50.1 8.86458 50.7 12.1313 51.9C15.3979 53.1 18.5979 53.7 21.7313 53.7C24.9313 53.7 26.5313 52.7 26.5313 50.7C26.5313 47.9667 23.1646 46.5 16.4313 46.3C13.7646 46.2333 12.2979 46.1667 12.0313 46.1C10.6313 45.6333 9.93125 42.7 9.93125 37.3C9.93125 31.9 10.6313 28.9333 12.0313 28.4C12.2979 28.2667 13.7646 28.2 16.4313 28.2C23.1646 28.0667 26.5313 26.7 26.5313 24.1C26.5313 22.1 25.0646 21.1 22.1313 21.1C19.2646 21.1 16.0646 21.8 12.5313 23.2C8.99792 24.6 7.06458 25.3 6.73125 25.3C5.19792 25.3 3.79792 23.0667 2.53125 18.6C1.26458 14.1333 0.63125 10.9667 0.63125 9.09999C0.63125 7.36666 2.56458 5.6 6.43125 3.8C10.6979 1.86666 16.9646 0.899998 25.2313 0.899998C44.4313 0.899998 54.0313 7.13333 54.0313 19.6Z" fill="black"/>'), 55);
        numberSVGs[4] = NumberSVG(abi.encodePacked('<path d="M56.3918 69.6C56.3918 70.3333 54.3585 70.9333 50.2918 71.4C46.2251 71.8 42.1585 72 38.0918 72C34.0251 72 31.3918 71.8333 30.1918 71.5C29.0585 71.1 28.4918 70.4667 28.4918 69.6V57.3H3.4918C1.22513 57.3 0.0917969 51.7667 0.0917969 40.7C0.0917969 39.4333 2.7918 34 8.1918 24.4C13.6585 14.8 17.4251 8.5 19.4918 5.5C20.2918 4.36666 23.2918 3.3 28.4918 2.3C33.6918 1.3 38.7585 0.799999 43.6918 0.799999C52.1585 0.799999 56.3918 2.36667 56.3918 5.5V69.6ZM30.1918 41.7L30.2918 19.9L23.2918 41.7H30.1918Z" fill="black"/>'), 57);
        numberSVGs[5] = NumberSVG(abi.encodePacked('<path d="M0.933594 65.3C0.933594 60.9667 1.53359 57.0667 2.73359 53.6C3.93359 50.0667 5.26693 48.3 6.73359 48.3C7.13359 48.3 9.26693 49.1333 13.1336 50.8C17.0003 52.4 19.8669 53.2 21.7336 53.2C23.6003 53.2 25.0336 52.9 26.0336 52.3C27.1003 51.7 27.6336 50.9 27.6336 49.9C27.6336 46.2333 20.8669 44.0667 7.33359 43.4C5.00026 43.2667 3.83359 36.1333 3.83359 22C3.83359 7.86667 4.93359 0.799999 7.13359 0.799999H51.3336C53.0669 0.799999 53.9336 3.46666 53.9336 8.8C53.9336 12 53.6003 15.5333 52.9336 19.4C52.3336 23.2 51.2669 25.1 49.7336 25.1H21.7336V29.6C34.6003 29.6 43.8003 31.6667 49.3336 35.8C53.8003 39.2 56.0336 44.2 56.0336 50.8C56.0336 57.4 53.5669 62.7333 48.6336 66.8C43.7003 70.8667 35.8003 72.9 24.9336 72.9C17.8669 72.9 12.1003 72.1 7.63359 70.5C3.16693 68.9 0.933594 67.1667 0.933594 65.3Z" fill="black"/>'), 57);
        numberSVGs[6] = NumberSVG(abi.encodePacked('<path d="M28.2945 29.3C28.8945 28.7667 30.4945 28.0667 33.0945 27.2C35.6945 26.3333 38.6279 25.9 41.8945 25.9C45.2279 25.9 48.0279 26.4 50.2945 27.4C52.6279 28.3333 54.4279 29.5333 55.6945 31C57.0279 32.4667 58.0612 34.3 58.7945 36.5C59.9945 40.1 60.5945 43.7667 60.5945 47.5C60.5945 51.2333 60.4279 54.0667 60.0945 56C59.8279 57.8667 59.0945 59.9667 57.8945 62.3C56.7612 64.6333 55.1945 66.6 53.1945 68.2C51.2612 69.8 48.4612 71.1667 44.7945 72.3C41.1945 73.3667 36.9612 73.9 32.0945 73.9C21.6279 73.9 13.7279 71.0333 8.39453 65.3C3.0612 59.5 0.394531 50.1667 0.394531 37.3C0.394531 24.3667 2.89453 15.0667 7.89453 9.4C12.8945 3.66666 20.4945 0.799994 30.6945 0.799994C37.6945 0.799994 43.7612 1.33333 48.8945 2.4C54.0945 3.4 56.6945 4.6 56.6945 6C56.6945 7.73333 56.0279 10.7667 54.6945 15.1C53.4279 19.4333 52.2612 21.6 51.1945 21.6C50.8612 21.6 49.8612 21.4333 48.1945 21.1C43.6612 20.1667 39.5279 19.7 35.7945 19.7C32.0612 19.7 29.6612 20.6333 28.5945 22.5C27.5279 24.3 26.9945 26.9667 26.9945 30.5C27.2612 30.1667 27.6945 29.7667 28.2945 29.3ZM30.4945 38.3C28.5612 38.3 27.5945 41.9 27.5945 49.1C27.5945 56.2333 28.5612 59.8 30.4945 59.8C32.5612 59.8 33.5945 56.2333 33.5945 49.1C33.5945 41.9 32.5612 38.3 30.4945 38.3Z" fill="black"/>'), 61);
        numberSVGs[7] = NumberSVG(abi.encodePacked('<path d="M38.9469 69.6C38.7469 70.3333 36.5135 70.9333 32.2469 71.4C28.0469 71.8 23.8802 72 19.7469 72C15.6135 72 12.9802 71.8333 11.8469 71.5C10.7135 71.1 10.1469 70.4667 10.1469 69.6C10.1469 68.2 14.6469 53.3333 23.6469 25H3.14688C2.21354 25 1.48021 23.4 0.946875 20.2C0.680208 18.6667 0.546875 16.6333 0.546875 14.1C0.546875 11.5667 0.880208 8.73333 1.54688 5.6C2.28021 2.4 3.41354 0.799999 4.94688 0.799999H45.1469C48.4135 0.799999 50.4802 1.53333 51.3469 2.99999C52.0802 4.13333 52.4469 5.63333 52.4469 7.5C52.4469 9.3 51.6802 13.7 50.1469 20.7C48.6135 27.7 46.6135 36.3 44.1469 46.5C41.7469 56.7 40.0135 64.4 38.9469 69.6Z" fill="black"/>'), 53);
        numberSVGs[8] = NumberSVG(abi.encodePacked('<path d="M60.441 50.6C60.441 66.1333 50.441 73.9 30.441 73.9C10.5077 73.9 0.541016 66.1333 0.541016 50.6C0.541016 43.6 2.14102 38.3333 5.34102 34.8C4.47435 33.8 3.67435 32.0667 2.94102 29.6C2.20768 27.0667 1.84102 24.5667 1.84102 22.1C1.84102 14.4333 4.27435 9 9.14102 5.79999C14.0077 2.53333 21.1077 0.899998 30.441 0.899998C39.7744 0.899998 46.8744 2.53333 51.741 5.79999C56.6744 9 59.141 14.4333 59.141 22.1C59.141 24.5667 58.7744 27.0667 58.041 29.6C57.3077 32.0667 56.5077 33.8 55.641 34.8C58.841 38.3333 60.441 43.6 60.441 50.6ZM27.241 51.3C27.241 54.6333 27.5077 56.8333 28.041 57.9C28.5744 58.9 29.3744 59.4 30.441 59.4C31.5744 59.4 32.3744 58.9 32.841 57.9C33.3744 56.8333 33.641 54.6333 33.641 51.3C33.641 47.9667 33.3744 45.7667 32.841 44.7C32.3744 43.5667 31.5744 43 30.441 43C29.3744 43 28.5744 43.5667 28.041 44.7C27.5077 45.7667 27.241 47.9667 27.241 51.3ZM30.541 27.4C32.6077 27.4 33.641 25.4333 33.641 21.5C33.641 17.5 32.6077 15.5 30.541 15.5C28.341 15.5 27.241 17.5 27.241 21.5C27.241 25.4333 28.341 27.4 30.541 27.4Z" fill="black"/>'), 61);
        numberSVGs[9] = NumberSVG(abi.encodePacked('<path d="M17.8945 47.8C12.1612 47.8 7.79453 45.7333 4.79453 41.6C1.8612 37.4 0.394531 31.9 0.394531 25.1C0.394531 19.3667 2.2612 14.1333 5.99453 9.4C7.99453 6.8 10.9612 4.73333 14.8945 3.2C18.8279 1.6 23.4945 0.799994 28.8945 0.799994C39.4945 0.799994 47.4279 3.53333 52.6945 9C57.9612 14.4667 60.5945 23.8333 60.5945 37.1C60.5945 50.3667 58.1279 59.8333 53.1945 65.5C48.2612 71.1 40.6279 73.9 30.2945 73.9C23.0945 73.9 16.9612 73.4667 11.8945 72.6C6.82787 71.6667 4.29453 70.5 4.29453 69.1C4.29453 67.4333 4.92787 64.4333 6.19453 60.1C7.52787 55.7667 8.72786 53.6 9.79453 53.6C10.1279 53.6 11.1279 53.7333 12.7945 54C17.6612 54.6667 21.8612 55 25.3945 55C28.9945 55 31.3279 54.0667 32.3945 52.2C33.4612 50.2667 33.9945 47.7333 33.9945 44.6C33.0612 45.3333 30.9945 46.0667 27.7945 46.8C24.6612 47.4667 21.3612 47.8 17.8945 47.8ZM30.4945 35.4C32.4279 35.4 33.3945 32 33.3945 25.2C33.3945 18.3333 32.4279 14.9 30.4945 14.9C28.4279 14.9 27.3945 18.3333 27.3945 25.2C27.3945 32 28.4279 35.4 30.4945 35.4Z" fill="black"/>'), 61);
    }

    /**
     * @dev Mints a new NFT representing a winning lottery ticket
     * @param winner Address of the winner
     * @param tokenId Unique identifier for the token
     * @param gameNumber The lottery game number
     * @param winningNumbers Array of winning numbers
     * @param payout The payout amount for the winning ticket
     */
    function mintNFT(address winner, uint256 tokenId, uint256 gameNumber, uint256[4] calldata winningNumbers, uint256 payout) external {
        require(msg.sender == lotteryContract, "Only the lottery contract can mint NFTs");
        require(initialized, "Not initialized");
        _safeMint(winner, tokenId);
        tokenGameNumbers[tokenId] = gameNumber;
        tokenWinningNumbers[tokenId] = winningNumbers;
        tokenPayouts[tokenId] = payout;
    }

    /**
     * @dev Returns the URI for a given token ID
     * @param tokenId The ID of the token
     * @return A string containing the URI
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");

        uint256 gameNumber = tokenGameNumbers[tokenId];
        uint256[4] memory winningNumbers = tokenWinningNumbers[tokenId];

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "EatThePie Lottery Ticket #', gameNumber.toString(), '",',
                        '"description": "This NFT represents a winning ticket in the EatThePie Lottery.",',
                        '"image": "', generateImageURI(winningNumbers), '",',
                        '"attributes": [',
                        '{"trait_type": "Game Number", "value": "', gameNumber.toString(), '"},',
                        '{"trait_type": "Payout", "value": "', tokenPayouts[tokenId].toString(), '"},',
                        '{"trait_type": "Winning Numbers", "value": "', 
                        winningNumbers[0].toString(), '-', 
                        winningNumbers[1].toString(), '-', 
                        winningNumbers[2].toString(), '-', 
                        winningNumbers[3].toString(), '"}',
                        ']}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /**
     * @dev Generates the image URI for the token
     * @param numbers Array of winning numbers
     * @return A string containing the image URI
     */
    function generateImageURI(uint256[4] memory numbers) internal view returns (string memory) {
        bytes memory svg = generateQuadrantSVG(numbers);
        return string(abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64.encode(svg)
        ));
    }

    /**
     * @dev Generates the SVG for the quadrant layout
     * @param numbers Array of winning numbers
     * @return Bytes containing the SVG data
     */
    function generateQuadrantSVG(uint256[4] memory numbers) internal view returns (bytes memory) {
        string[4] memory colors = ["#F47C7C", "#F7F48B", "#A1DE93", "#70A1D7"];

        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">',
            generateQuadrants(numbers, colors),
            '</svg>'
        );

        return svg;
    }

    /**
     * @dev Generates the quadrants for the SVG
     * @param numbers Array of winning numbers
     * @return Bytes containing the quadrant SVG data
     */
    function generateQuadrants(uint256[4] memory numbers, string[4] memory colors) internal view returns (bytes memory) {
        bytes memory quadrants;
        uint256 size = 300;

        for (uint i = 0; i < 4; i++) {
            uint256 x = (i % 2) * size;
            uint256 y = (i / 2) * size;
            
            quadrants = abi.encodePacked(
                quadrants,
                '<rect x="', x.toString(), '" y="', y.toString(), 
                '" width="300" height="300" fill="', colors[i], '"/>',
                generateNumberSVG(numbers[i], x, y)
            );
        }

        return quadrants;
    }

    /**
     * @dev Generates the SVG for a single number
     * @param number The number to generate
     * @param xOffset X offset for positioning
     * @param yOffset Y offset for positioning
     * @return Bytes containing the number SVG data
     */
    function generateNumberSVG(uint256 number, uint256 xOffset, uint256 yOffset) internal view returns (bytes memory) {
        bytes memory digitPaths = getDigitPaths(number);
        uint256 totalWidth = getTotalWidth(number);
        uint256 xPos = xOffset + (150 - (totalWidth / 2)); // Center horizontally
        uint256 yPos = yOffset + 150 - 37; // Center vertically (300/2 - 74/2)

        bytes memory numberSVG = abi.encodePacked('<g transform="translate(', xPos.toString(), ',', yPos.toString(), ')">', digitPaths, '</g>');

        return numberSVG;
    }

    /**
     * @dev Gets the SVG paths for each digit in a number
     * @param number The number to process
     * @return Bytes containing the digit SVG paths
     */
    function getDigitPaths(uint256 number) internal view returns (bytes memory) {
        bytes memory paths;
        uint256 xOffset = 0;

        if (number == 0) {
            return abi.encodePacked('<g transform="translate(0,0)">', numberSVGs[0].path, '</g>');
        }

        while (number > 0) {
            uint256 digit = number % 10;
            paths = abi.encodePacked('<g transform="translate(', xOffset.toString(), ',0)">', numberSVGs[digit].path, '</g>', paths);
            xOffset += numberSVGs[digit].width;
            number /= 10;
        }

        return paths;
    }

    /**
     * @dev Calculates the total width of a number's SVG representation
     * @param number The number to process
     * @return The total width of the number's SVG
     */
    function getTotalWidth(uint256 number) internal view returns (uint256) {
        uint256 totalWidth = 0;

        if (number == 0) {
            return numberSVGs[0].width;
        }

        while (number > 0) {
            uint256 digit = number % 10;
            totalWidth += numberSVGs[digit].width;
            number /= 10;
        }

        return totalWidth;
    }
}