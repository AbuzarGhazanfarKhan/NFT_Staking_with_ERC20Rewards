// SPDX-License-Identifier: MIT LICENSE
pragma solidity 0.8.4;

import "./Erc721_collection.sol";
import "./Erc20_Reward.sol";

contract NFTStaking is Ownable, IERC721Receiver {

  uint256 public totalStaked;
  
  
  // struct to store a stake's token, owner, and earning values
  struct Stake {
    uint24 tokenId;
    uint48 timestamp; // time starts the moment nft is staked
    address owner; //owner of nft
  }

  event NFTStaked(address owner, uint256 tokenId, uint256 value); // value of nft
  event NFTUnstaked(address owner, uint256 tokenId, uint256 value); // value of nft
  event Claimed(address owner, uint256 amount); // owner of nft and Amount== reward

  // reference to the Block NFT contract
  Erc721_collection nft; // reference to erc720 nft smart contract
  Erc20_Reward token; // reference to Erc20_Reward smart contract

  // maps tokenId to stake
  mapping(uint256 => Stake) public vault; 

   constructor(Erc721_collection _nft, Erc20_Reward _token) { 
    nft = _nft;
    token = _token;
  }

  function stake(uint256[] calldata tokenIds) external { // which tokens user wants to stake(array of tokenIds)
    uint256 tokenId;
    totalStaked += tokenIds.length;

    // for loop  to perform staking calculation PER nft (1 by 1)
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      require(nft.ownerOf(tokenId) == msg.sender, "not your token");
      require(vault[tokenId].tokenId == 0, 'already staked');

      nft.transferFrom(msg.sender, address(this), tokenId);
      emit NFTStaked(msg.sender, tokenId, block.timestamp);

      vault[tokenId] = Stake({
        owner: msg.sender,
        tokenId: uint24(tokenId),
        timestamp: uint48(block.timestamp)
      });
    }
  }

  
  function _unstakeMany(address account, uint256[] calldata tokenIds) internal {
    uint256 tokenId;
    totalStaked -= tokenIds.length;
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      Stake memory staked = vault[tokenId];
      require(staked.owner == msg.sender, "not an owner");

      delete vault[tokenId];
      emit NFTUnstaked(account, tokenId, block.timestamp);
      nft.transferFrom(address(this), account, tokenId);
    }
  }

  function claim(uint256[] calldata tokenIds) external {
      _claim(msg.sender, tokenIds, false);
  }

  function claimForAddress(address account, uint256[] calldata tokenIds) external {
      _claim(account, tokenIds, false);
  }

  function unstake(uint256[] calldata tokenIds) external {
      _claim(msg.sender, tokenIds, true);
  }

// TOKEN REWARDS CALCULATION
// MAKE SURE YOU CHANGE THE VALUE ON BOTH CLAIM AND EARNINGINFO FUNCTIONS.
// Find the following line and update accordingly based on how much you want 
// to reward users with ERC-20 reward tokens.

// rewardmath = 100 ether .... (This gives 1 token per day per NFT staked to the staker)
// rewardmath = 200 ether .... (This gives 2 tokens per day per NFT staked to the staker)
// rewardmath = 500 ether .... (This gives 5 tokens per day per NFT staked to the staker)
// rewardmath = 1000 ether .... (This gives 10 tokens per day per NFT staked to the staker)

  function _claim(address account, uint256[] calldata tokenIds, bool _unstake) internal {
    // boolean to ask if user want to just claim the reward or claim and unstake 
    uint256 tokenId;
    uint256 earned = 0;
    uint256 rewardmath = 0;

    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      Stake memory staked = vault[tokenId];
      require(staked.owner == account, "not an owner");
      uint256 stakedAt = staked.timestamp;
      rewardmath = 100 ether * (block.timestamp - stakedAt) / 86400 ; //or per day
      earned = rewardmath / 100;
      vault[tokenId] = Stake({
        owner: account,
        tokenId: uint24(tokenId),
        timestamp: uint48(block.timestamp)
      });
    }
    if (earned > 0) {
      token.mint(account, earned);
    }
    if (_unstake) {
      _unstakeMany(account, tokenIds);
    }
    emit Claimed(account, earned);
  }

  function earningInfo(address account, uint256[] calldata tokenIds) external view returns (uint256[1] memory info) {
     uint256 tokenId;
     uint256 earned = 0;
     uint256 rewardmath = 0;

    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      Stake memory staked = vault[tokenId];
      require(staked.owner == account, "not an owner");
      uint256 stakedAt = staked.timestamp;
      rewardmath = 100 ether * (block.timestamp - stakedAt) / 86400;
      earned = rewardmath / 100;

    }
    if (earned > 0) {
      return [earned];
    }
}

  // should never be used inside of transaction because of gas fee
  function balanceOf(address account) public view returns (uint256) {
    uint256 balance = 0;
    uint256 supply = nft.totalSupply();
    for(uint i = 1; i <= supply; i++) {
      if (vault[i].owner == account) {
        balance += 1;
      }
    }
    return balance;
  }

  // should never be used inside of transaction because of gas fee
  function tokensOfOwner(address account) public view returns (uint256[] memory ownerTokens) {

    uint256 supply = nft.totalSupply();
    uint256[] memory tmp = new uint256[](supply);

    uint256 index = 0;
    for(uint tokenId = 1; tokenId <= supply; tokenId++) {
      if (vault[tokenId].owner == account) {
        tmp[index] = vault[tokenId].tokenId;
        index +=1;
      }
    }

    uint256[] memory tokens = new uint256[](index);
    for(uint i = 0; i < index; i++) {
      tokens[i] = tmp[i];
    }

    return tokens;
  }

  function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
      require(from == address(0x0), "Cannot send nfts to Vault directly");
      return IERC721Receiver.onERC721Received.selector;
    }
  
}
