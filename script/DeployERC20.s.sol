// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Worldcoin", "WLD") {
        _mint(msg.sender, 1000000000 * 10**18);
    }
}

contract DeployTestToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast();
        
        TestToken token = new TestToken();
        console.log("Test Token deployed to:", address(token));
        
        // fund accounts
        /*
            address[] memory testAccounts = new address[](3);
            testAccounts[0] = ;
            testAccounts[1] = ;
            testAccounts[2] = ;
            testAccounts[3] = ;
            testAccounts[4] = ;

            for (uint i = 0; i < testAccounts.length; i++) {
                token.transfer(testAccounts[i], 10000 * 10**18);
                console.log("Funded account", testAccounts[i], "with 100000 tokens");
            }
        */
        
        vm.stopBroadcast();
    }
}