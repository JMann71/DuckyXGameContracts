// SPDX-License-Identifier: MIT LICENSE 

pragma solidity ^0.8.0;

interface IStake {
    function randomCoyoteHolder(address person) external returns (address);
    function getOwner(uint256 tokenId) external view returns(address);
}