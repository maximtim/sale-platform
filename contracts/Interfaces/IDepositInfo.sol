// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

interface IDepositInfo {
    function getDeposit(address user) external view returns (uint);
}