// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "witnet-solidity-bridge/contracts/interfaces/IWitnetRandomness.sol";
import "../src/NFTPrize.sol";
import "../src/Lottery.sol";

contract DeployLottery is Script {
    function run() external {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = 0xac329d01dbbd2ee0b043d3c53af6419fefd59ce30b1a86094184f2d34474a694;
        vm.startBroadcast(deployerPrivateKey);

        // FEE RECIPIENT
        address feeRecipient = address(0x123);
        address paymentToken = address(0x123);
        IWitnetRandomness witnetRandomness = IWitnetRandomness(0xC0FFEE98AD1434aCbDB894BbB752e138c1006fAB);

        // NFT Contract
        NFTPrize nftContract = new NFTPrize();
        console.log("NFT Contract deployed to:", address(nftContract));

        // Lottery Contract
        Lottery lotteryContract = new Lottery(
            witnetRandomness,
            address(nftContract),
            feeRecipient,
            paymentToken
        );

        // Set Lottery Contract in NFT Contract
        nftContract.setLotteryContract(address(lotteryContract));

        console.log("Lottery Contract deployed to:", address(lotteryContract));

        vm.stopBroadcast();
    }
}