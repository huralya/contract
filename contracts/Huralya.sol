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

<<<<<<< HEAD
  uint256 public MINTED_AMOUNT = 0;

  constructor() ERC20('Huralya', 'LYA') {
    MINT_TIMESTAP = block.timestamp + MINT_INTERVAL;
    MINTED_AMOUNT += 100_000_000 * 10 ** 6;
    _mint(owner(), 100_000_000 * 10 ** 6);
  }
=======
    function mint(uint256 _amount) external onlyOwner {
        require(
            block.timestamp >= lastMintTimestamp + MINT_INTERVAL,
            'LYA: Minting is not allowed yet, please wait until the next minting interval'
        );
        require(
            totalSupply() + _amount <= MAX_SUPPLY,
            'LYA: Cannot mint beyond maximum supply'
        );
>>>>>>> 9111c885c82aee342c3811da2ed756fb48bd3cc6

        _mint(owner(), _amount);
    }

<<<<<<< HEAD
  function mint() external onlyOwner {
    require(
      block.timestamp >= MINT_TIMESTAP,
      'LYA: Minting is not allowed yet, please wait until the next minting interval'
    );
    require(
      MINTED_AMOUNT < MAX_SUPPLY,
      'LYA: Maximum supply reached, no more tokens can be minted'
    );
    MINTED_AMOUNT += 100_000_000 * 10 ** 6;
    super._mint(owner(), 100_000_000 * 10 ** 6);
  }
=======
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
>>>>>>> 9111c885c82aee342c3811da2ed756fb48bd3cc6

    function burn(uint256 _amount) external {
        super._burn(msg.sender, _amount);
    }
}
