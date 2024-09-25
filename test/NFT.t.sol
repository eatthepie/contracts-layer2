// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/NFTGenerator.sol";

contract NFTGeneratorTest is Test {
    NFTGenerator public nftGenerator;

    function setUp() public {
        nftGenerator = new NFTGenerator();
    }

    function testGenerateNFTMetadata() public {
        uint256 gameNumber = 123;
        uint256[4] memory ticketNumbers = [12, 34, 56, 78];
        uint256 jackpotPrize = 100 ether;

        string memory metadata = nftGenerator.generateNFTMetadata(gameNumber, ticketNumbers, jackpotPrize);
        
        // Check that the metadata is not empty
        assertTrue(bytes(metadata).length > 0);
        
        // Check that the metadata starts with the correct prefix
        assertTrue(LibString.startsWith(metadata, "data:application/json;base64,"));

        // Decode the base64 content
        string memory decodedMetadata = string(Base64.decode(LibString.slice(metadata, 29, bytes(metadata).length - 29)));

        // Check for expected content in the metadata
        assertTrue(LibString.contains(decodedMetadata, '"name": "EatThePie Lottery Ticket #123"'));
        assertTrue(LibString.contains(decodedMetadata, '"description": "This NFT represents a lottery ticket in the EatThePie Lottery."'));
        assertTrue(LibString.contains(decodedMetadata, '"image": "data:image/svg+xml;base64,'));
        assertTrue(LibString.contains(decodedMetadata, '"trait_type": "Game Number", "value": "123"'));
        assertTrue(LibString.contains(decodedMetadata, '"trait_type": "Ticket Numbers", "value": "12-34-56-78"'));
        assertTrue(LibString.contains(decodedMetadata, '"trait_type": "Jackpot Prize", "value": "100000000000000000000 ETH"'));
    }

    function testGenerateQuadrantSVG() public {
        uint256[4] memory numbers = [12, 34, 56, 78];
        bytes memory svg = nftGenerator.generateQuadrantSVG(numbers);

        // Check that the SVG is not empty
        assertTrue(svg.length > 0);

        // Convert bytes to string for easier assertions
        string memory svgString = string(svg);

        // Check for expected content in the SVG
        assertTrue(LibString.contains(svgString, '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">'));
        assertTrue(LibString.contains(svgString, '<rect x="0" y="0" width="300" height="300" fill="#F47C7C"/>'));
        assertTrue(LibString.contains(svgString, '<rect x="300" y="0" width="300" height="300" fill="#F7F48B"/>'));
        assertTrue(LibString.contains(svgString, '<rect x="0" y="300" width="300" height="300" fill="#A1DE93"/>'));
        assertTrue(LibString.contains(svgString, '<rect x="300" y="300" width="300" height="300" fill="#70A1D7"/>'));
        assertTrue(LibString.contains(svgString, '</svg>'));
    }

    function testGetTotalWidth() public {
        // Test single-digit numbers
        for (uint256 i = 0; i < 10; i++) {
            uint256 width = nftGenerator.getTotalWidth(i);
            assertTrue(width > 0);
        }

        // Test multi-digit numbers
        uint256 width12 = nftGenerator.getTotalWidth(12);
        uint256 width34 = nftGenerator.getTotalWidth(34);
        assertTrue(width12 < width34);

        uint256 width123 = nftGenerator.getTotalWidth(123);
        uint256 width1234 = nftGenerator.getTotalWidth(1234);
        assertTrue(width123 < width1234);
    }

    function testGetDigitPaths() public {
        bytes memory paths0 = nftGenerator.getDigitPaths(0);
        assertTrue(paths0.length > 0);
        assertTrue(LibString.contains(string(paths0), '<g transform="translate(0,0)">'));

        bytes memory paths123 = nftGenerator.getDigitPaths(123);
        assertTrue(paths123.length > 0);
        assertTrue(LibString.contains(string(paths123), '<g transform="translate('));
        
        // Count the number of digit paths
        uint256 pathCount = LibString.countOccurrences(string(paths123), '<g transform="translate(');
        assertEq(pathCount, 3);
    }
}