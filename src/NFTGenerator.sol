// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFTGenerator {
    using Strings for uint256;

    function generateNFTMetadata(uint256 gameNumber, uint256[4] memory winningNumbers) public pure returns (string memory) {
        bytes memory svg = generateSVG(gameNumber, winningNumbers);
        
        string memory json = Base64.encode(
            bytes(string(
                abi.encodePacked(
                    '{"name": "EatThePie Lottery Winner #', gameNumber.toString(), '",',
                    '"description": "This NFT represents a jackpot win in the EatThePie Lottery.",',
                    '"image": "data:image/svg+xml;base64,', Base64.encode(svg), '",',
                    '"attributes": [',
                    '{"trait_type": "Game Number", "value": "', gameNumber.toString(), '"},',
                    '{"trait_type": "Winning Numbers", "value": "', 
                    winningNumbers[0].toString(), '-',
                    winningNumbers[1].toString(), '-',
                    winningNumbers[2].toString(), '-',
                    winningNumbers[3].toString(), '"}',
                    ']}'
                )
            ))
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function generateSVG(uint256 gameNumber, uint256[4] memory winningNumbers) internal pure returns (bytes memory) {
        string[7] memory colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F67280", "#C06C84"];
        
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
            '<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>',
            '<rect width="100%" height="100%" fill="black" />',
            generateCircles(winningNumbers, colors),
            '<text x="50%" y="20" class="base" text-anchor="middle">EatThePie Lottery Winner</text>',
            '<text x="50%" y="40" class="base" text-anchor="middle">Game #', gameNumber.toString(), '</text>',
            '<text x="50%" y="330" class="base" text-anchor="middle">',
            winningNumbers[0].toString(), '-',
            winningNumbers[1].toString(), '-',
            winningNumbers[2].toString(), '-',
            winningNumbers[3].toString(),
            '</text>',
            '</svg>'
        );

        return svg;
    }

    function generateCircles(uint256[4] memory numbers, string[7] memory colors) internal pure returns (bytes memory) {
        bytes memory circles;
        for (uint i = 0; i < 4; i++) {
            uint256 cx = 50 + (i * 80);
            uint256 cy = 175;
            uint256 radius = 20 + (numbers[i] % 30);
            string memory color = colors[numbers[i] % 7];
            
            circles = abi.encodePacked(
                circles,
                '<circle cx="', cx.toString(), '" cy="', cy.toString(), 
                '" r="', radius.toString(), '" fill="', color, '">',
                '<animate attributeName="r" values="', radius.toString(), ';', (radius + 10).toString(), ';', radius.toString(), 
                '" dur="2s" repeatCount="indefinite"/>',
                '</circle>'
            );
        }
        return circles;
    }
}
