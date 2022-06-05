//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Interfaces/IDepositInfo.sol";
import "./Interfaces/IDAO.sol";

contract DAO is IDAO {
    address public chairPerson;
    uint256 public minimunQuorum;
    uint256 public debatingPeriodDuration;
    IDepositInfo depositInfo;

    uint256 counter;

    struct Proposal {
        bytes callData;
        address recipient;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endTime;
        bool closed;
    }

    mapping(uint256 => Proposal) public proposals;

    mapping(address => uint256) public unlockDepositDates;
    mapping(address => mapping(uint256 => bool)) public voted;

    event ProposalCreated(
        uint256 indexed id,
        string description,
        uint256 endTime
    );
    event ProposalFinished(uint256 indexed id, bool won);

    constructor(
        address chairPerson_,
        uint256 minimunQuorum_,
        uint256 debatingPeriodDuration_
    ) {
        chairPerson = chairPerson_;
        minimunQuorum = minimunQuorum_;
        debatingPeriodDuration = debatingPeriodDuration_;
    }

    modifier only(address account) {
        require(msg.sender == account, "Restricted access");
        _;
    }

    function setDepositInfo(IDepositInfo depositInfo_)
        external
        only(chairPerson)
    {
        depositInfo = depositInfo_;
    }

    function addProposal(
        bytes memory callData,
        address recipient,
        string memory description
    ) external only(chairPerson) {
        require(recipient.code.length > 0, "Recipient has no code");

        counter++;
        uint256 endTime = block.timestamp + debatingPeriodDuration;
        proposals[counter] = Proposal(
            callData,
            recipient,
            description,
            0,
            0,
            endTime,
            false
        );

        emit ProposalCreated(counter, description, endTime);
    }

    function vote(uint256 proposalNum, bool voteFor) external {
        require(voted[msg.sender][proposalNum] == false, "Already voted");

        Proposal storage prop = proposals[proposalNum];
        uint256 endTime = prop.endTime;
        require(block.timestamp < endTime, "Debating period is over");

        uint256 depo = depositInfo.getDeposit(msg.sender);
        require(depo > 0, "No deposit to vote");

        if (voteFor) {
            prop.votesFor += depo;
        } else {
            prop.votesAgainst += depo;
        }

        if (endTime > unlockDepositDates[msg.sender]) {
            unlockDepositDates[msg.sender] = endTime;
        }

        voted[msg.sender][proposalNum] = true;
    }

    function finishProposal(uint256 proposalNum) external {
        Proposal storage prop = proposals[proposalNum];
        require(prop.closed == false, "Proposal already closed");
        require(
            block.timestamp > prop.endTime,
            "Debating period is not over yet"
        );

        prop.closed = true;

        uint256 votesFor = prop.votesFor;
        uint256 votesAgainst = prop.votesAgainst;
        bool won = votesFor > votesAgainst &&
            votesFor + votesAgainst > minimunQuorum;

        if (won) {
            (bool success, bytes memory returndata) = prop.recipient.call(
                prop.callData
            );
            Address.verifyCallResult(
                success,
                returndata,
                "Function call failed"
            );
        }

        emit ProposalFinished(proposalNum, won);
    }

    function setMinimumQuorum(uint256 minimumQuorum_)
        external
        only(address(this))
    {
        require(minimumQuorum_ > 0, "minimunQuorum should be positive");
        minimunQuorum = minimumQuorum_;
    }

    function setDebatingPeriod(uint256 debatingPeriod)
        external
        only(address(this))
    {
        require(debatingPeriod > 0, "debatingPeriod should be positive");
        debatingPeriodDuration = debatingPeriod;
    }

    function isDepositLocked(address user) external view override returns (bool) {
        return block.timestamp <= unlockDepositDates[user];
    }
}