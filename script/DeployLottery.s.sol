// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/VDFPietrzak.sol";
import "../src/NFTPrize.sol";
import "../src/Lottery.sol";

contract DeployLottery is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // FEE RECIPIENT
        address feeRecipient = address(0x123);

        // VDF Contract
        VDFPietrzak vdfContract = new VDFPietrzak();
        console.log("VDF Contract deployed to:", address(vdfContract));

        // NFT Contract
        NFTPrize nftContract = new NFTPrize();
        console.log("NFT Contract deployed to:", address(nftContract));

        // Lottery Contract
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