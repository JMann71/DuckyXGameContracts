// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./ERC20.sol";
import "./Ownable.sol";

contract EGG is ERC20, Ownable {

    mapping(address => bool) minters;

    constructor() ERC20("DuckyXToken", "DXT") {

    }

    function mint(address to, uint256 amount) external {
        require(minters[msg.sender], "Only approved minters allowed");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(minters[msg.sender], "Only approved minters allowed");
        _burn(from, amount);
    }

    function addMinter(address user) external onlyOwner {
        minters[user] = true;
    }

    function removeMinter(address user) external onlyOwner {
        minters[user] = false;
    }
}