# VDF Test Files

This folder contains valid and invalid proofs of VDF (Verifiable Delay Function) computations using historical `block.prevrandao` values from Ethereum mainnet and Sepolia testnet.

## Parameters

```solidity
bytes public constant nBytes = hex"c7970ceedcc3b0754490201a7aa613cd73911081c790f5f1a8726f463550bb5b7ff0db8e1ea1189ec72f93d1650011bd721aeeacc2acde32a04107f0648c2813a31f5b0b7765ff8b44b4b6ffc93384b646eb09c7cf5e8592d40ea33c80039f35b4f14a04b51f7bfd781be4d1673164ba8eb991c2c4d730bbbe35f592bdef524af7e8daefd26c66fc02c479af89d64d373f442709439de66ceb955f3ea37d5159f6135809f85334b5cb1813addc80cd05609f10ac6a95ad65872c909525bdad32bc729592642920f24c61dc5b3c3b7923e56b16a4d9d373d8721f24a3fc0f1b3131f55615172866bccc30f95054c824e733a5eb6817f7bc16399d48c6361cc7e5";

uint256 public constant nBitLength = 2048;
uint256 public constant T = 67108864; // 2^26
```

## Test Files

| File    | Description | RANDAO Value                                                                  |
| ------- | ----------- | ----------------------------------------------------------------------------- |
| `a.sol` | Test Case A | 65305838511507767948894108466576998214933764930710580223742911944647654807690 |
| `b.sol` | Test Case B | 51049764388387882260001832746320922162275278963975484447753639501411130604681 |
| `c.sol` | Test Case C | 2656751508725187512486344122081204096368588122458517885621621007542366135775  |
| `d.sol` | Test Case D | 96618837226557606533137319610808329371780981598490822395441686749465502125142 |

## Notes

- All test cases use `block.prevrandao` values sourced from both Ethereum mainnet and Sepolia testnet
- The delay parameter T is set to 2^26 (67,108,864)
