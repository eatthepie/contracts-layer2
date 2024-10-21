// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/VDFPietrzak.sol";

contract DeployVDF is Script {
    function run() external {
        string memory pk = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
        uint256 deployerPrivateKey = vm.parseUint(pk);
        vm.startBroadcast(deployerPrivateKey);
        VDFPietrzak vdfContract = new VDFPietrzak();
        vm.stopBroadcast();
        console.log("VDF Contract deployed to:", address(vdfContract));
    }
}