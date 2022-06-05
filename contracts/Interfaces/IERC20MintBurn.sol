// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20MintBurn is IERC20 {
    function burn(uint amount) external ;
    function burnFrom(address from, uint amount) external ;
    function mint(address to, uint256 amount) external ;
}