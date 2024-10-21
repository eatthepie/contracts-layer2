// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/VDFPietrzak.sol";

contract DeployVDF is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        VDFPietrzak vdfContract = new VDFPietrzak();

        console.log("VDF Contract deployed to:", address(vdfContract));

        vm.stopBroadcast();
    }
}