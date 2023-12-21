// SPDX-License-Identifier: Huralya
pragma solidity 0.8.23;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';

contract Huralya is ERC20, Ownable2Step {
    uint256 public constant MINT_INTERVAL = 365 days * 4;
    uint256 public constant MAX_SUPPLY = 200_000_000 * 10 ** 6;

    uint256 public lastMintTimestamp;

    constructor() ERC20('Huralya', 'LYA') {
        
        _mint(owner(), 100_000_000 * 10 ** 6);
        lastMintTimestamp = block.timestamp;
    }

    function mint(uint256 _amount) external onlyOwner {
        require(
            block.timestamp >= lastMintTimestamp + MINT_INTERVAL,
            'LYA: Minting is not allowed yet, please wait until the next minting interval'
        );
        require(
            totalSupply() + _amount <= MAX_SUPPLY,
            'LYA: Cannot mint beyond maximum supply'
        );

        _mint(owner(), _amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function burn(uint256 _amount) external {
        super._burn(msg.sender, _amount);
    }
}
