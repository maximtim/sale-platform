//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./Interfaces/IERC20MintBurn.sol";
import "./Interfaces/IDepositInfo.sol";
import "./Interfaces/IDAO.sol";

contract Staking is IDepositInfo {
    IERC20MintBurn public tokenRewards;
    IERC20MintBurn public tokenStake;
    uint256 public rewardPeriod;
    uint256 public frozenPeriod;
    uint256 public rewardFor1TokenUnit;
    uint256 public tokenRewardDecimals;
    address public owner;
    IDAO dao;

    struct Stake {
        uint256 tokenAmount;
        uint256 creationTime;
        uint256 reward;
        uint256 rewardsCount;
    }

    mapping(address => Stake) public stakes;

    constructor(
        IERC20MintBurn tokenStake_,
        IERC20MintBurn tokenRewards_,
        uint256 rewardPeriod_,
        uint256 frozenPeriod_,
        uint256 rewardFor1TokenUnit_,
        uint256 tokenRewardDecimals_
    ) {
        require(rewardPeriod_ > 0, "Reward period should be > 0");
        require(rewardFor1TokenUnit_ > 0, "Reward percent should be > 0");
        require(tokenRewardDecimals_ > 0, "Decimals should be > 0");

        owner = msg.sender;
        tokenRewards = tokenRewards_;
        tokenStake = tokenStake_;
        rewardPeriod = rewardPeriod_;
        frozenPeriod = frozenPeriod_;
        rewardFor1TokenUnit = rewardFor1TokenUnit_;
        tokenRewardDecimals = tokenRewardDecimals_;
    }

    modifier only(address account) {
        require(msg.sender == account, "Restricted access");
        _;
    }

    modifier greaterThanZero(uint256 arg) {
        require(arg > 0, "Greater than zero only");
        _;
    }

    ////////////////////////////////////////////////////////////////////////////////

    function stake(uint256 amount) external {
        require(amount > 0, "Stake == 0");
        tokenStake.transferFrom(msg.sender, address(this), amount);

        Stake storage stake0 = stakes[msg.sender];

        uint tokenAmount = stake0.tokenAmount;
        uint rewardsCnt = stake0.rewardsCount;

        if (tokenAmount > 0) {
            (uint256 reward, uint256 rewardsCount) = calculateReward(tokenAmount, stake0.creationTime, stake0.reward, rewardsCnt);

            if (rewardsCount > rewardsCnt) {
                stake0.reward = reward;
            }
        }

        stake0.creationTime = block.timestamp;
        stake0.rewardsCount = 0;
        stake0.tokenAmount += amount;
    }

    function claim() external {
        Stake storage stake0 = stakes[msg.sender];
        uint256 creationTime = stake0.creationTime;
        require(creationTime > 0, "Stake was not created");

        (uint256 reward, uint256 rewardsCount) = calculateReward(stake0.tokenAmount, creationTime, stake0.reward, stake0.rewardsCount);

        require(reward > 0, "No reward to claim");
        stake0.reward = 0;
        stake0.rewardsCount = rewardsCount;

        tokenRewards.mint(msg.sender, reward);
    }

    function unstake() external {
        Stake storage stake0 = stakes[msg.sender];
        uint256 amount = stake0.tokenAmount;
        uint256 creationTime = stake0.creationTime;
        require(amount > 0, "Nothing to unstake");
        require(
            creationTime + frozenPeriod < block.timestamp,
            "Frozen period is not over yet"
        );
        require(dao.isDepositLocked(msg.sender), "Deposit is locked by DAO");

        _updateReward(stake0, stake0.tokenAmount, creationTime, stake0.reward, stake0.rewardsCount);

        stake0.tokenAmount = 0;
        tokenStake.transfer(msg.sender, amount);
    }

    ////////////////////////////////////////////////////////////////////////////////

    function update() external {
        Stake storage stake0 = stakes[msg.sender];
        _updateReward(stake0, stake0.tokenAmount, stake0.creationTime, stake0.reward, stake0.rewardsCount);
    }

    function changeFrozenPeriod(uint256 frozenPeriod_) external only(address(dao)) {
        frozenPeriod = frozenPeriod_;
    }

    function changeRewardFor1TokenUnit(uint256 rewardFor1TokenUnit_)
        external
        only(owner)
        greaterThanZero(rewardFor1TokenUnit_)
    {
        rewardFor1TokenUnit = rewardFor1TokenUnit_;
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calculateReward(
        uint256 tokenAmount,
        uint256 creationTime,
        uint256 reward,
        uint256 rewardsCount)
        public
        view
        returns (uint256 fullReward, uint256 fullRewardsCount)
    {
        uint256 newRewardsCount = (block.timestamp - creationTime) /
            rewardPeriod;
        uint256 oldCount = rewardsCount;

        fullReward =
            reward +
            ((newRewardsCount - oldCount) *
                rewardFor1TokenUnit *
                tokenAmount) /
            (10**tokenRewardDecimals);
        fullRewardsCount = newRewardsCount;
    }

    function _updateReward(
        Stake storage stakeStorage, 
        uint256 tokenAmount,
        uint256 creationTime,
        uint256 reward,
        uint256 rewardsCount)
        private
    {
        (uint256 newReward, uint256 newRewardsCount) = calculateReward(tokenAmount, creationTime, reward, rewardsCount);

        if (newRewardsCount > rewardsCount) {
            stakeStorage.reward = newReward;
            stakeStorage.rewardsCount = newRewardsCount;
        }
    }

    function getDeposit(address user) external view override returns (uint256) {
        return stakes[user].tokenAmount;
    }

    function setDAO(IDAO dao_) external only(owner) {
        dao = dao_;
    }
}