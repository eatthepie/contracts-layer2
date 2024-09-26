// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTGenerator.sol";
import "../src/EatThePieLottery.sol";
import "../src/libraries/BigNumbers.sol";

contract DeployEatThePie is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy VDFPietrzak
        BigNumbers.BigNumber memory n = BigNumbers.BigNumber({
            val: new uint256[](1),
            bitlen: 256
        });
        n.val[0] = 0x123456789abcdef; // Replace with your actual n value
        uint256 delta = 10; // Replace with your actual delta value
        uint256 T = 1000; // Replace with your actual T value
        VDFPietrzak vdf = new VDFPietrzak(n, delta, T);
        console.log("VDFPietrzak deployed at:", address(vdf));

        // Deploy NFTGenerator
        NFTGenerator nftGenerator = new NFTGenerator();
        console.log("NFTGenerator deployed at:", address(nftGenerator));

        // Deploy EatThePieLottery
        address feeRecipient = address(0x123); // Replace with actual fee recipient address
        uint256 vdfModulusN = 0x123456789abcdef; // Replace with actual VDF modulus N
        EatThePieLottery lottery = new EatThePieLottery(
            address(vdf),
            vdfModulusN,
            address(nftGenerator),
            feeRecipient
        );
        console.log("EatThePieLottery deployed at:", address(lottery));

        vm.stopBroadcast();
    }
}