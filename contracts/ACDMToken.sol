// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ACDMToken is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() ERC20("ACADEM Coin", "ACDM") {
        // _mint(msg.sender, 1000 * 10 ** decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(uint amount) public override onlyRole(BURNER_ROLE) {
        ERC20Burnable.burn(amount);
    }

    function burnFrom(address from, uint amount) public override onlyRole(BURNER_ROLE) {
        ERC20Burnable.burnFrom(from, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}