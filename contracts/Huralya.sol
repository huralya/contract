//SPDX-License-Identifier: Huralya
pragma solidity 0.8.23;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';

contract Huralya is ERC20, Ownable2Step {
  uint256 public constant MINT_INTERVAL = 365 days * 4;

  uint256 public constant MAX_SUPPLY = 200_000_000 * 10 ** 6;

  uint256 public MINT_TIMESTAP;

  constructor() ERC20('Huralya', 'LYA') {
    MINT_TIMESTAP = block.timestamp + MINT_INTERVAL;
    _mint(owner(), 100_000_000 * 10 ** 6);
  }

  function burn(uint256 _amount) external {
    super._burn(msg.sender, _amount);
  }

  function mint() external onlyOwner {
    require(
      block.timestamp >= MINT_TIMESTAP,
      'LYA: Minting is not allowed yet, please wait until the next minting interval'
    );
    require(
      totalSupply() < MAX_SUPPLY,
      'LYA: Maximum supply reached, no more tokens can be minted'
    );
    super._mint(owner(), 100_000_000 * 10 ** 6);
  }

  function decimals() public view virtual override returns (uint8) {
    return 6;
  }
}
