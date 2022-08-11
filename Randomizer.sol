// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.0;

contract Randomizer {
    uint256 private seed;
    uint256 private counter;

    constructor() {
        seed = 4823942635;
        counter = 0;
    }

    function random(uint256 max) external returns (uint8){
        if(counter % 2 == 0){
            seed = random();
            counter = 0;
        }
        seed = random();
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(
            tx.origin,
            block.timestamp,
            block.basefee,
            block.timestamp,
            seed
        )));
        counter++;
        return uint8(randomNumber % max);
    }

    function random() public view returns (uint256){
        return uint256(keccak256(abi.encodePacked(
            tx.origin,
            block.timestamp,
            block.basefee,
            block.timestamp,
            seed
        )));
    }
}