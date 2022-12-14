// SPDX-License-Identifier: MIT LICENSE 

pragma solidity ^0.8.0;

interface IRandomizer {
  function random(uint256 max) external returns (uint8);
  function random() external returns (uint256);
}