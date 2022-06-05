// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

interface IDAO {
    function isDepositLocked(address user) external view returns (bool);
}