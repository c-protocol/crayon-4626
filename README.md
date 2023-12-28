# crayon-protocol-interface

Vyper contracts implementing an ERC-4626-compliant wrapper to the Crayon Protocol.

## Overview

Crayon is a lending, trade leveraging and financing protocol on EVM-compatible blockchains.

This interface provides for depositing and withdrawing assets, and minting and redeeming shares as specified in the ERC-4626 standard. At deployment it must be attached to a specific Crayon desk through the constructor.

Liquidity-provider tokens are given the symbol of the base token of the attached Crayon desk prefixed with "xc". For example, an interface to the Crayon "WETH" desk will have the "xcWETH" token.

Liquidity-provider tokens are specified to 6 decimals.

No further documentation will be provided since knowledge of the ERC-4626 standard should be sufficient. 

## Development and Testing

The code was tested with Vyper 0.3.10 but with EVM version Paris since Arbtirum as of now still does not support the PUSH0 opcode.

### Dependencies

* python3 from version 3.10.6
* ape version 0.6.26

### Testing

Install dependencies and clone repository. Then, in the root directory do:

```bash
ape test --network arbitrum:mainnet-fork:foundry
```

This will run all tests against a forked arbitrum mainnet where Crayon desks are deployed.
