//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Huralya is ERC20, Ownable {
  //public variables
  using SafeMath for uint256;
  address public TREASURY_ADDRESS = 0x8ee6E81220F7EbF611701Ca9FB04A2D033392C7a;
  uint256 public MINTABLE_AMOUNT = 200000000 ether;
  uint256 public constant ADD_MINTABLE_AMOUNT_PER_EACH_ADDRESS = 100 ether;
  address[] public AUTHORIZED_CONTRACTS_ADDRESS;

  uint256 public constant TOTAL_SUPPLY_LIMIT_PER_4_YEARS = 100000000 ether; // Total supply limit of 100 million LYA per 4 year
  uint256 public constant MINTING_INTERVAL = 4 * 365 days;
  //private variables
  address[] private transferedFromTreasuryToAddresses;
  bool private isFirstMint = true;

  uint256 private lastMintTimestamp;
  uint256 private mintedAmount;

  // only treasury  can call condition
  modifier onlyTreasury() {
    require(
      msg.sender == TREASURY_ADDRESS,
      'LYA: only treasury address can call this function'
    );
    _;
  }

  constructor() ERC20('Huralya', 'LYA') {
    lastMintTimestamp = block.timestamp;
  }

  //change treasury address
  function changeTreausryAddress(address _address) external onlyOwner {
    TREASURY_ADDRESS = _address;
  }

  //check the address added in transfer from treasury addresses list or not
  function isTransferFromTreasuryToAddress(
    address _address
  ) public view returns (bool) {
    for (uint i = 0; i < transferedFromTreasuryToAddresses.length; i++) {
      if (transferedFromTreasuryToAddresses[i] == _address) {
        return true;
      }
    }
    return false;
  }

  //save each address when transfer from treasury to them,because I needed that for increase mintable amount
  function addTransferFromTreasuryToAddress(
    address _address
  ) private onlyTreasury {
    transferedFromTreasuryToAddresses.push(_address);
  }

  //check authorized contract address
  function isAuthorizedAddress(address _address) public view returns (bool) {
    for (uint i = 0; i < AUTHORIZED_CONTRACTS_ADDRESS.length; i++) {
      if (AUTHORIZED_CONTRACTS_ADDRESS[i] == _address) {
        return true;
      }
    }
    return false;
  }

  //add authorized contract address
  function addAuthorizedContractAddress(address _address) external onlyOwner {
    require(
      !isAuthorizedAddress(_address),
      'LYA: contract address already exists'
    );
    AUTHORIZED_CONTRACTS_ADDRESS.push(_address);
  }

  //remove authorized contract address
  function removeAuthorizedContractAddress(
    address _address
  ) external onlyOwner {
    require(
      isAuthorizedAddress(_address),
      'LYA: contract address does not exist'
    );
    for (uint i = 0; i < AUTHORIZED_CONTRACTS_ADDRESS.length; i++) {
      if (AUTHORIZED_CONTRACTS_ADDRESS[i] == _address) {
        for (uint j = i; j < AUTHORIZED_CONTRACTS_ADDRESS.length - 1; j++) {
          AUTHORIZED_CONTRACTS_ADDRESS[j] = AUTHORIZED_CONTRACTS_ADDRESS[j + 1];
        }
        AUTHORIZED_CONTRACTS_ADDRESS.pop();
        break;
      }
    }
  }

  //burn supply
  function burn(uint256 _amount) external {
    return super._burn(msg.sender, _amount);
  }

  //mint supply
  function mint(uint256 _amount) external onlyOwner {
    require(
      _amount <= MINTABLE_AMOUNT,
      'LYA: Your entered amount is greater than the mintable limit'
    );

    if (block.timestamp >= lastMintTimestamp.add(MINTING_INTERVAL)) {
      lastMintTimestamp = block.timestamp;
      mintedAmount = 0;
      require(
        mintedAmount.add(_amount) <= TOTAL_SUPPLY_LIMIT_PER_4_YEARS,
        'LYA: Exceeds the total supply limit in 4 years'
      );
    } else {
      if (!isFirstMint) {
        require(
          mintedAmount.add(_amount) <= TOTAL_SUPPLY_LIMIT_PER_4_YEARS,
          'LYA: Exceeds the total supply limit'
        );
      }
    }

    super._mint(owner(), _amount);
    if (!isFirstMint) {
      mintedAmount = mintedAmount.add(_amount);
    }
    MINTABLE_AMOUNT = MINTABLE_AMOUNT.sub(_amount);
    isFirstMint = false;
  }

  //transfer function
  function transfer(
    address _to,
    uint256 _amount
  ) public virtual override returns (bool) {
    if (
      !isTransferFromTreasuryToAddress(_to) && msg.sender == TREASURY_ADDRESS
    ) {
      addTransferFromTreasuryToAddress(_to);
      MINTABLE_AMOUNT = MINTABLE_AMOUNT.add(
        ADD_MINTABLE_AMOUNT_PER_EACH_ADDRESS
      );
    }
    return super.transfer(_to, _amount);
  }

  //transfer from function
  function transferFrom(
    address _from,
    address _to,
    uint256 _amount
  ) public virtual override returns (bool) {
    if (isAuthorizedAddress(msg.sender)) {
      super._transfer(_from, _to, _amount);
      return true;
    }
    return super.transferFrom(_from, _to, _amount);
  }

  //check the address is contract or not
  function isContract(address _address) internal view returns (bool) {
    uint256 codeSize;
    assembly {
      codeSize := extcodesize(_address)
    }
    return codeSize > 0;
  }
}
