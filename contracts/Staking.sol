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

        Stake storage stakeStorage = stakes[msg.sender];

        // разобраться с оптмизацией кода

        if (stakeStorage.tokenAmount > 0) {
            (uint256 reward, uint256 rewardsCount) = calculateReward(
                stakeStorage
            );

            if (rewardsCount > stakeStorage.rewardsCount) {
                stakeStorage.reward = reward;
            }
        }

        stakeStorage.creationTime = block.timestamp;
        stakeStorage.rewardsCount = 0;
        stakeStorage.tokenAmount += amount;
    }

    function claim() external {
        Stake storage stakeStorage = stakes[msg.sender];
        Stake memory stakeMemory = stakeStorage;
        require(stakeMemory.creationTime > 0, "Stake was not created");

        (uint256 reward, uint256 rewardsCount) = calculateReward(stakeMemory);

        require(reward > 0, "No reward to claim");
        stakeStorage.reward = 0;
        stakeStorage.rewardsCount = rewardsCount;

        tokenRewards.mint(msg.sender, reward);
    }

    function unstake() external {
        Stake storage stakeStorage = stakes[msg.sender];
        Stake memory stakeMemory = stakeStorage;
        uint256 amount = stakeMemory.tokenAmount;
        require(amount > 0, "Nothing to unstake");
        require(
            stakeMemory.creationTime + frozenPeriod < block.timestamp,
            "Frozen period is not over yet"
        );
        require(dao.isDepositLocked(msg.sender), "Deposit is locked by DAO");

        _updateReward(stakeStorage, stakeMemory);

        stakeStorage.tokenAmount = 0;
        tokenStake.transfer(msg.sender, amount);
    }

    ////////////////////////////////////////////////////////////////////////////////

    function update() external {
        Stake storage stakeStorage = stakes[msg.sender];
        Stake memory stakeMemory = stakeStorage;
        _updateReward(stakeStorage, stakeMemory);
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

    function calculateReward(Stake memory stakeMemory)
        public
        view
        returns (uint256 fullReward, uint256 fullRewardsCount)
    {
        uint256 newRewardsCount = (block.timestamp - stakeMemory.creationTime) /
            rewardPeriod;
        uint256 oldCount = stakeMemory.rewardsCount;

        fullReward =
            stakeMemory.reward +
            ((newRewardsCount - oldCount) *
                rewardFor1TokenUnit *
                stakeMemory.tokenAmount) /
            (10**tokenRewardDecimals);
        fullRewardsCount = newRewardsCount;
    }

    function _updateReward(Stake storage stakeStorage, Stake memory stakeMemory)
        private
    {
        (uint256 reward, uint256 rewardsCount) = calculateReward(stakeMemory);

        if (rewardsCount > stakeMemory.rewardsCount) {
            stakeStorage.reward = reward;
            stakeStorage.rewardsCount = rewardsCount;
        }
    }

    function getDeposit(address user) external view override returns (uint256) {
        return stakes[user].tokenAmount;
    }

    function setDAO(IDAO dao_) external only(owner) {
        dao = dao_;
    }
}