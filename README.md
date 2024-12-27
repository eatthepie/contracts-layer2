# ⚠️ WARNING: DO NOT USE

This contract implementation contains a vulnerability. **Do not use in production.**

During a live deployment, the VDF verifier failed to validate a proof generated from RANDAO value:

```
31325452000363991679778000192024676047597961951682627885191052254553440896332
```

This critical failure in the verification process makes the contract unsafe for use.

![Eat The Pie](https://github.com/eatthepie/docs/blob/main/static/img/header.png)

> ⚠️ **Layer 2 Fork Notice**
>
> This repository contains a modified version of the [original Eat The Pie contracts](https://github.com/eatthepie/contracts). Key differences in this L2 implementation:
>
> 1. Randomness Source: Uses blockhash instead of prevrandao for VDFs
> 2. Payment Method: Implements ERC20 token purchase instead of ETHER

# Eat The Pie Layer 2 Smart Contracts

This repository contains all smart contracts running [Eat The Pie](https://www.eatthepie.xyz), the world lottery on Layer 2.

## Project Structure 📂

- `script/`: Deployment scripts

  - `DeployLottery.s.sol`
  - `DeployVDF.s.sol`

- `src/`: Main contract files

  - `libraries/`: Utility libraries
    - `BigNumbers.sol`
    - `PietrzakLibrary.sol`
  - `Lottery.sol`: Main lottery contract
  - `NFTPrize.sol`: NFT prize contract
  - `VDFPietrzak.sol`: Verifiable Delay Function implementation

## Setup

1. Install Foundry if you haven't already:

   ```
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. Clone the repository:

   ```
   git clone https://github.com/eatthepie/contracts
   cd contracts
   ```

3. Install dependencies:
   ```
   forge install
   ```

## Deployment

To deploy the contracts to a network:

1. Set up your `.env` file with the required environment variables (e.g., RPC_URL, PRIVATE_KEY).

2. Run the deployment script:
   ```
   source .env
   forge script script/DeployLottery.s.sol:DeployLottery --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
   ```

## Testing 🧪

Run the test suite with:

```
forge test
```

For more verbose output:

```
forge test -vv
```

To run a specific test file:

```
forge test --match-path test/[TestFileName].t.sol
```

## 📝 Deployed Contracts

| Network             | Address                                      |
| ------------------- | -------------------------------------------- |
| World Chain         | `0x44B340051a31D216f83428B447DBa2C102DFF373` |
| World Chain Sepolia | `0x78334Ea7df16a582cc98980d79D6271c42f9ef81` |

## Documentation 📚

For detailed information about the smart contracts and how they work, please visit [docs.eatthepie.xyz](https://docs.eatthepie.xyz).

## License 📜

This project is licensed under the MIT License.
