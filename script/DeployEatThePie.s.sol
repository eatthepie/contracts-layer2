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
        // RSA-2048 challenge value
        string memory rsaChallenge = "25195908475657893494027183240048398571429282126204032027777137836043662020707595556264018525880784406918290641249515082189298559149176184502808489120072844992687392807287776735971418347270261896375014971824691165077613379859095700097330459748808428401797429100642458691817195118746121515172654632282216869987549182422433637259085141865462043576798423387184774447920739934236584823824281198163815010674810451660377306056201619676256133844143603833904414952634432190114657544454178424020924616515723350778707749817125772467962926386356373289912154831438167899885040445364023527381951378636564391212010397122822120720357";

        // Convert the string to bytes
        bytes memory rsaChallengeBytes = bytes(rsaChallenge);

        // Create the BigNumber struct
        BigNumber memory n = BigNumber({
            val: rsaChallengeBytes,
            bitlen: 2048
        });
        uint256 delta = 4;
        uint256 T = 1048576; // 2 ** 20

        VDFPietrzak vdf = new VDFPietrzak(n, delta, T);
        console.log("VDFPietrzak deployed at:", address(vdf));

        // Deploy NFTGenerator
        NFTGenerator nftGenerator = new NFTGenerator();
        console.log("NFTGenerator deployed at:", address(nftGenerator));

        // Deploy EatThePieLottery
        address feeRecipient = address(0x123); // Replace with actual fee recipient address
        EatThePieLottery lottery = new EatThePieLottery(
            address(vdf),
            rsaChallengeBytes,
            address(nftGenerator),
            feeRecipient
        );
        
        // set lottery address in NFTGenerator
        nftGenerator.setLotteryContract(address(lottery));

        console.log("EatThePieLottery deployed at:", address(lottery));

        vm.stopBroadcast();
    }
}