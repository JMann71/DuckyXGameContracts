// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface ICreature {
    struct Ducky {
        uint8 creatureType;
        uint8 layer_0;
        uint8 layer_1;
        uint8 layer_2;
        uint8 layer_3;
        uint8 layer_4;
        uint8 layer_5;
        uint8 layer_6;
        uint8 level;
        uint256 eggModifier;
    }

    function getTokenTraits(uint256 tokenId) external view returns (Ducky memory);
}