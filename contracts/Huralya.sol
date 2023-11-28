//SPDX-License-Identifier: Huralya
pragma solidity 0.8.23;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';

contract Huralya is ERC20, Ownable2Step {
  uint256 public constant MINTING_INTERVAL = 365 * 4 days;

  uint256 public constant TOTAL_SUPPLY_LIMIT_PER_4_YEARS =
    100_000_000 * 10 ** 6;
  uint256 public MAX_MINTED_AMOUNT_AFTER_DEPLOY;

  uint256 private deployTimestamp;

  constructor() ERC20('Huralya', 'LYA') {
    deployTimestamp = block.timestamp;
    _mint(owner(), TOTAL_SUPPLY_LIMIT_PER_4_YEARS);
  }

  function burn(uint256 _amount) external {
    super._burn(msg.sender, _amount);
  }

  function mint(uint256 _amount) external onlyOwner {
    uint256 currentMintableAmount = getMintableAmount();
    require(
      _amount <= currentMintableAmount,
      'LYA: your entered amount is greater than the mintable limit'
    );

    super._mint(owner(), _amount);
    MAX_MINTED_AMOUNT_AFTER_DEPLOY = MAX_MINTED_AMOUNT_AFTER_DEPLOY + _amount;
  }

  function getMintableAmount() public view returns (uint256) {
    uint256 elapsedMintingTime = block.timestamp - deployTimestamp;
    uint256 mintingPeriods = elapsedMintingTime / MINTING_INTERVAL;

    uint256 remainingTimeInInterval = elapsedMintingTime % MINTING_INTERVAL;
    uint256 maxMintableAmount = (mintingPeriods *
      MINTING_INTERVAL *
      TOTAL_SUPPLY_LIMIT_PER_4_YEARS) /
      (MINTING_INTERVAL + remainingTimeInInterval);

    if (maxMintableAmount > MAX_MINTED_AMOUNT_AFTER_DEPLOY) {
      return maxMintableAmount - MAX_MINTED_AMOUNT_AFTER_DEPLOY;
    }
    return MAX_MINTED_AMOUNT_AFTER_DEPLOY - maxMintableAmount;
  }

  function decimals() public view virtual override returns (uint8) {
    return 6;
  }
}
