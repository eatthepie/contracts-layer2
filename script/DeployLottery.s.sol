// forge script script/DeployLottery.s.sol:DeployLottery --rpc-url http://localhost:8545 --broadcast
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";
import "../src/Lottery.sol";
import "../src/libraries/BigNumbers.sol";

contract DeployLottery is Script {
    function run() external {
        string memory pk = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
        uint256 deployerPrivateKey = vm.parseUint(pk);
        vm.startBroadcast(deployerPrivateKey);

        // VDF Contract
        VDFPietrzak vdfContract = new VDFPietrzak();
        console.log("VDF Contract deployed to:", address(vdfContract));

        // NFT Contract
        NFTPrize nftContract = new NFTPrize();
        console.log("NFT Contract deployed to:", address(nftContract));

        // Lottery Contract
        address feeRecipient = address(0x123); // fee address
        Lottery lotteryContract = new Lottery(
            address(vdfContract),
            address(nftContract),
            feeRecipient
        );

        // Set Lottery Contract in NFT Contract
        nftContract.setLotteryContract(address(lotteryContract));

        console.log("Lottery Contract deployed to:", address(lotteryContract));

        vm.stopBroadcast();
    }
}