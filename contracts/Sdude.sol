//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract Sdude is ERC721, ERC721URIStorage, ReentrancyGuard {
  using SafeMath for uint256;
  using Strings for uint256;
  using Counters for Counters.Counter;
  struct StakingHistory {
    uint256 tokenId;
    uint256 startDate;
    uint256 endDate;
    uint256 daysStaked;
    uint256 amount;
    uint256 unstakeTimestamp;
    uint256 stakeTimestamp;
    uint256 totalStakedDays;
    uint256 totalAllowedStakingDays;
    uint256 activingStakingTimestamp;
    bool isStaked;
  }

  struct TokenLock {
    uint256 unlockAt;
    bool isStart;
  }

  Counters.Counter private _idCounter;
  string public constant baseURI = 'https://nft.huralya.com/sdude/';
  address public constant lyaToken = 0x2A301aAa4a97F83657d6bedA1D5327280079C3e9;
  address public constant owner = 0x8102635f7701Ab96F7e7ebF7A859f4c80Ef63E83;
  address public treasury = 0x8ee6E81220F7EbF611701Ca9FB04A2D033392C7a;
  address public lockManager = 0x8ee6E81220F7EbF611701Ca9FB04A2D033392C7a;

  uint256 public mintPrice = 500000000000000000000;
  uint256 public constant totalSupply = 50000;
  uint256 public constant mintPriceIncrement = 500000000000000000000;
  uint256 public currentSupply = 0;
  uint256 public constant tokensForEachMintPeriod = 1000;
  uint256 public treasuryLyaForClaimReward = 0;
  mapping(uint256 => uint256) private tokenMintPrice;
  mapping(address => uint256) private userRewards;
  mapping(uint256 => address) private tokenStaker;
  mapping(address => uint256[]) private stakedTokensByAddress;
  mapping(address => uint256[]) public lockedTokensByAddress;
  mapping(address => uint256[]) private tokensOfAddress;
  mapping(uint256 => TokenLock) public lockedTokens;

  uint256 public constant stakeRewardPeriod = 2 minutes;
  uint256 public constant totalStakePeriod = 1000 days;
  uint256 private constant SECONDS_IN_DAY = 86400;

  mapping(uint256 => StakingHistory) private stakingHistory;

  modifier onlyOwner() {
    require(msg.sender == owner, 'Only owner can call this function');
    _;
  }

  modifier onlyTreasury() {
    require(msg.sender == treasury, 'Only treasury can call this function');
    _;
  }

  modifier onlyLockManager() {
    require(
      msg.sender == lockManager,
      'Only lock manager can call this function'
    );
    _;
  }

  modifier onlyUnlockedTokens(uint256 _tokenId) {
    require(!isTokenLocked(_tokenId), 'Token is locked');
    _;
  }

  modifier onlyLockedTokens(uint256 _tokenId) {
    require(isTokenLocked(_tokenId), 'Token not locked');
    _;
  }

  modifier onlyUnstakedTokens(uint256 _tokenId) {
    require(!isStaked(_tokenId), 'Token is already staking');
    _;
  }

  modifier onlyExistTokens(uint256 _tokenId) {
    require(exists(_tokenId), 'Token is not exist');
    _;
  }

  modifier onlyStakedTokens(uint256 _tokenId) {
    require(isStaked(_tokenId), 'Token is not staked');
    _;
  }

  modifier onlyTokenOwner(uint256 _tokenId) {
    require(
      msg.sender == ownerOf(_tokenId),
      'Caller is not the owner of the token'
    );
    _;
  }

  constructor() ERC721('Sanjab the dude', 'Sdude') {
    _idCounter = Counters.Counter(1);
  }

  function changeTreausryAddress(address _address) public onlyOwner {
    treasury = _address;
  }

  function changeLockManagerAddress(address _address) public onlyOwner {
    lockManager = _address;
  }

  function addTokensOfAddresses(address _address, uint256 _tokenId) private {
    tokensOfAddress[_address].push(_tokenId);
  }

  function lyaTokenBalance(address _address) private view returns (uint256) {
    return ERC20(lyaToken).balanceOf(_address);
  }

  function mint(uint256 _quantity) external nonReentrant {
    require(_quantity != 0, 'Quantity is invalid');

    for (uint256 i = 0; i < _quantity; i++) {
      uint256 tokenId = _idCounter.current();
      require(tokenId <= totalSupply, 'Token minting limit reached');

      mintPrice = calcMintPrice(tokenId);
      tokenMintPrice[tokenId] = mintPrice;
      uint256 lyaBalance = lyaTokenBalance(msg.sender);

      require(lyaBalance >= mintPrice, 'Insufficient LYA token funds');

      ERC20(lyaToken).transferFrom(msg.sender, owner, mintPrice);

      _safeMint(msg.sender, tokenId);

      bytes memory tokenUri = abi.encodePacked(baseURI, tokenId.toString());

      bytes memory tokenCompleteUri = abi.encodePacked(
        string(tokenUri),
        '.json'
      );

      _setTokenURI(tokenId, string(tokenCompleteUri));

      updateMintPrice(tokenId);
      _idCounter.increment();
      currentSupply = tokenId;
      addTokensOfAddresses(msg.sender, tokenId);
    }
  }

  function lockToken(
    uint256 _tokenId,
    uint256 _lockTimeInDays
  )
    public
    onlyLockManager
    onlyUnlockedTokens(_tokenId)
    onlyExistTokens(_tokenId)
  {
    if (_lockTimeInDays == 0) {
      lockedTokens[_tokenId].unlockAt = 0;
    } else {
      uint256 lockTimeInSeconds = _lockTimeInDays.mul(SECONDS_IN_DAY);
      lockedTokens[_tokenId].unlockAt = lockTimeInSeconds.add(block.timestamp);
    }
    lockedTokens[_tokenId].isStart = true;
    lockedTokensByAddress[ownerOf(_tokenId)].push(_tokenId);
  }

  function unlockToken(
    uint256 _tokenId
  )
    public
    onlyLockManager
    onlyLockedTokens(_tokenId)
    onlyExistTokens(_tokenId)
  {
    require(
      isUnlimitedTokenLock(_tokenId),
      'can not unlock tokenId with lockTime'
    );
    address tokenOwnerAddress = ownerOf(_tokenId);
    uint256 index;
    for (
      uint256 i = 0;
      i < lockedTokensByAddress[tokenOwnerAddress].length;
      i++
    ) {
      if (lockedTokensByAddress[tokenOwnerAddress][i] == _tokenId) {
        index = i;
        break;
      }
    }
    lockedTokens[_tokenId].isStart = false;
    delete lockedTokens[_tokenId];
    delete lockedTokensByAddress[tokenOwnerAddress][index];
  }

  function getRemainingDaysForUnlock(
    uint256 _tokenId
  )
    public
    view
    onlyExistTokens(_tokenId)
    onlyLockedTokens(_tokenId)
    returns (uint256, bool)
  {
    TokenLock storage tokenLock = lockedTokens[_tokenId];
    if (tokenLock.isStart) {
      if (tokenLock.unlockAt == 0) {
        return (0, true);
      }
    }
    uint256 remainingTimeInSeconds = tokenLock.unlockAt.sub(block.timestamp);
    if (remainingTimeInSeconds <= 0) {
      return (0, false);
    }
    return (remainingTimeInSeconds, true);
  }

  function isUnlimitedTokenLock(
    uint256 _tokenId
  )
    public
    view
    onlyExistTokens(_tokenId)
    onlyLockedTokens(_tokenId)
    returns (bool)
  {
    return lockedTokens[_tokenId].unlockAt == 0;
  }

  function isTokenLocked(
    uint256 _tokenId
  ) public view onlyExistTokens(_tokenId) returns (bool) {
    TokenLock storage tokenLock = lockedTokens[_tokenId];
    if (tokenLock.isStart == true) {
      if (tokenLock.unlockAt == 0 || tokenLock.unlockAt >= block.timestamp) {
        return true;
      }
    }
    return false;
  }

  function getTokenLockTime(
    uint256 _tokenId
  )
    public
    view
    onlyExistTokens(_tokenId)
    onlyLockedTokens(_tokenId)
    returns (uint256)
  {
    return lockedTokens[_tokenId].unlockAt;
  }

  function removeTokenFromAddress(address _address, uint256 _tokenId) private {
    uint256[] storage tokens = tokensOfAddress[_address];
    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == _tokenId) {
        tokens[i] = tokens[tokens.length - 1];
        tokens.pop();
        break;
      }
    }
  }

  function transfer(
    address _to,
    uint256 _tokenId
  )
    public
    virtual
    onlyExistTokens(_tokenId)
    onlyTokenOwner(_tokenId)
    onlyUnlockedTokens(_tokenId)
    onlyUnstakedTokens(_tokenId)
  {
    super._transfer(msg.sender, _to, _tokenId);
    removeTokenFromAddress(msg.sender, _tokenId);
    addTokensOfAddresses(_to, _tokenId);
  }

  function safeTransfer(
    address _to,
    uint256 _tokenId
  )
    public
    virtual
    onlyExistTokens(_tokenId)
    onlyTokenOwner(_tokenId)
    onlyUnlockedTokens(_tokenId)
    onlyUnstakedTokens(_tokenId)
  {
    super.safeTransferFrom(msg.sender, _to, _tokenId);
    removeTokenFromAddress(msg.sender, _tokenId);
    addTokensOfAddresses(_to, _tokenId);
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
    public
    override
    onlyExistTokens(_tokenId)
    onlyUnlockedTokens(_tokenId)
    onlyUnstakedTokens(_tokenId)
  {
    require(
      msg.sender == _from ||
        isApprovedForAll(_from, msg.sender) ||
        getApproved(_tokenId) == msg.sender,
      'Caller is not approved to transfer this NFT'
    );
    super.transferFrom(_from, _to, _tokenId);
    removeTokenFromAddress(_from, _tokenId);
    addTokensOfAddresses(_to, _tokenId);
  }

  function calculateStakeRewardPerDay(
    uint256 _tokenId
  ) public view onlyExistTokens(_tokenId) returns (uint256) {
    return tokenMintPrice[_tokenId].mul(1).div(1000);
  }

  function mintPriceFromTokenId(
    uint256 _tokenId
  ) public view onlyExistTokens(_tokenId) returns (uint256) {
    return tokenMintPrice[_tokenId];
  }

  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
    public
    override
    onlyOwner
    onlyExistTokens(_tokenId)
    onlyUnlockedTokens(_tokenId)
    onlyUnstakedTokens(_tokenId)
  {
    super.safeTransferFrom(_from, _to, _tokenId);
    removeTokenFromAddress(_from, _tokenId);
    addTokensOfAddresses(_to, _tokenId);
  }

  function stake(
    uint256 _tokenId
  )
    public
    onlyExistTokens(_tokenId)
    onlyTokenOwner(_tokenId)
    onlyUnlockedTokens(_tokenId)
  {
    require(remainingStakingDays(_tokenId) > 0, 'Maximum stake done');

    stakedTokensByAddress[msg.sender].push(_tokenId);
    stakingHistory[_tokenId].isStaked = true;
    stakingHistory[_tokenId].stakeTimestamp = block.timestamp;
    stakingHistory[_tokenId].totalAllowedStakingDays = remainingStakingDays(
      _tokenId
    );
    stakingHistory[_tokenId].activingStakingTimestamp = block.timestamp;
  }

  function unstake(
    uint256 _tokenId
  )
    public
    onlyExistTokens(_tokenId)
    onlyTokenOwner(_tokenId)
    onlyUnlockedTokens(_tokenId)
    onlyStakedTokens(_tokenId)
  {
    uint256 profit = calculateReward(_tokenId);
    if (profit > 0) {
      claimReward(_tokenId);
    }

    stakingHistory[_tokenId].totalAllowedStakingDays = remainingStakingDays(
      _tokenId
    );
    stakingHistory[_tokenId].totalStakedDays = passedStakingDays(_tokenId);
    stakingHistory[_tokenId].isStaked = false;
    stakingHistory[_tokenId].unstakeTimestamp = block.timestamp;

    uint256 index;
    for (uint256 i = 0; i < stakedTokensByAddress[msg.sender].length; i++) {
      if (stakedTokensByAddress[msg.sender][i] == _tokenId) {
        index = i;
        break;
      }
    }
    delete stakedTokensByAddress[msg.sender][index];
  }

  function historyOfTotalStakedDays(
    uint256 _tokenId
  ) public view onlyExistTokens(_tokenId) returns (uint256) {
    StakingHistory storage history = stakingHistory[_tokenId];

    return history.totalStakedDays;
  }

  function stakeActivingAt(
    uint256 _tokenId
  )
    public
    view
    onlyExistTokens(_tokenId)
    onlyStakedTokens(_tokenId)
    returns (uint256)
  {
    StakingHistory storage history = stakingHistory[_tokenId];
    return history.activingStakingTimestamp;
  }

  function passedStakingDays(
    uint256 _tokenId
  ) public view onlyExistTokens(_tokenId) returns (uint256) {
    StakingHistory storage history = stakingHistory[_tokenId];
    uint256 totalDaysStaked;

    if (history.isStaked) {
      totalDaysStaked = block.timestamp - history.stakeTimestamp;
    } else {
      totalDaysStaked = history.unstakeTimestamp - history.stakeTimestamp;
    }
    uint256 passedStakingDaysInHumanReadableFormat = SafeMath.div(
      totalDaysStaked,
      stakeRewardPeriod
    );

    return passedStakingDaysInHumanReadableFormat + history.totalStakedDays;
  }

  function remainingStakingDays(
    uint256 _tokenId
  ) public view onlyExistTokens(_tokenId) returns (uint256) {
    StakingHistory storage history = stakingHistory[_tokenId];
    uint256 totalDaysStaked;
    if (history.isStaked) {
      totalDaysStaked = block.timestamp - history.stakeTimestamp;
    } else {
      totalDaysStaked = history.unstakeTimestamp - history.stakeTimestamp;
    }

    totalDaysStaked =
      totalDaysStaked +
      SafeMath.mul(history.totalStakedDays, stakeRewardPeriod);

    uint256 remainingDays = totalStakePeriod - totalDaysStaked;
    uint256 remainingDaysInHumanReadableFormat = SafeMath.div(
      remainingDays,
      stakeRewardPeriod
    );

    return remainingDaysInHumanReadableFormat;
  }

  function calculateReward(
    uint256 _tokenId
  )
    public
    view
    onlyExistTokens(_tokenId)
    onlyStakedTokens(_tokenId)
    returns (uint256)
  {
    uint256 remainingTime = remainingStakingDays(_tokenId);
    uint256 reward = 0;

    if (remainingTime <= 0) {
      reward = tokenMintPrice[_tokenId].mul(1).div(1000);
      return reward.mul(allowedStakingDays(_tokenId));
    }

    reward = tokenMintPrice[_tokenId].mul(1).div(1000);
    return
      reward.mul(
        passedStakingDays(_tokenId) - historyOfTotalStakedDays(_tokenId)
      );
  }

  function allowedStakingDays(
    uint256 _tokenId
  ) public view onlyExistTokens(_tokenId) returns (uint256) {
    StakingHistory storage history = stakingHistory[_tokenId];

    return history.totalAllowedStakingDays;
  }

  function exists(uint256 _tokenId) public view virtual returns (bool) {
    return super._exists(_tokenId);
  }

  function claimReward(
    uint256 _tokenId
  )
    public
    onlyExistTokens(_tokenId)
    onlyTokenOwner(_tokenId)
    onlyUnlockedTokens(_tokenId)
    onlyStakedTokens(_tokenId)
  {
    uint256 profit = calculateReward(_tokenId);
    require(
      treasuryLyaForClaimReward >= profit,
      'Insufficient fund Lya for claim reward treasury'
    );
    require(profit > 0, 'No profit to claim');
    require(
      ERC20(lyaToken).transferFrom(treasury, ownerOf(_tokenId), profit),
      'LYA Transfer failed'
    );
    treasuryLyaForClaimReward = treasuryLyaForClaimReward.sub(profit);
    stakingHistory[_tokenId].totalAllowedStakingDays = remainingStakingDays(
      _tokenId
    );
    stakingHistory[_tokenId].totalStakedDays = passedStakingDays(_tokenId);
    stakingHistory[_tokenId].stakeTimestamp = block.timestamp;
  }

  function approveTreasuryAmountOfClaimReward(
    uint256 _amount
  ) public onlyTreasury {
    require(
      ERC20(lyaToken).approve(treasury, _amount),
      'Reward approval failed'
    );
    treasuryLyaForClaimReward = treasuryLyaForClaimReward.add(_amount);
  }

  function calcMintPrice(uint256 _tokenId) private view returns (uint256) {
    if (_tokenId.mod(tokensForEachMintPeriod) == 0) {
      return mintPrice.add(mintPriceIncrement);
    }
    return mintPrice;
  }

  function updateMintPrice(uint256 _tokenId) private {
    mintPrice = calcMintPrice(_tokenId);
  }

  function _burn(
    uint256 tokenId
  ) internal override(ERC721, ERC721URIStorage) onlyOwner {
    super._burn(tokenId);
  }

  function tokenURI(
    uint256 tokenId
  ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
    return super.tokenURI(tokenId);
  }

  function isStaked(
    uint256 _tokenId
  ) public view onlyExistTokens(_tokenId) returns (bool) {
    return stakingHistory[_tokenId].isStaked;
  }

  function getStakedTokensOfAddress(
    address _address
  ) public view returns (uint256[] memory) {
    return stakedTokensByAddress[_address];
  }

  function getTokensOfAddress(
    address _address
  ) public view returns (uint256[] memory) {
    return tokensOfAddress[_address];
  }

  function getLockedTokensOfAddress(
    address _address
  ) public view returns (uint256[] memory) {
    uint256[] memory tokens = new uint256[](
      lockedTokensByAddress[_address].length
    );
    uint256 index = 0;
    for (uint256 i = 0; i < lockedTokensByAddress[_address].length; i++) {
      uint256 tokenId = lockedTokensByAddress[_address][i];
      if (isTokenLocked(tokenId)) {
        tokens[index] = tokenId;
        index++;
      }
    }
    uint256[] memory result = new uint256[](index);
    for (uint256 i = 0; i < index; i++) {
      result[i] = tokens[i];
    }
    return result;
  }
}
