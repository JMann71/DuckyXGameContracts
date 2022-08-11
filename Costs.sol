// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.0;

library Costs {
    // Maximum number of Initial Ducks
    uint256 constant MAX_INITIAL_DUCKS = 10000;
    // Maximum number of Initial Wolves
    uint256 constant MAX_INITIAL_COYOTES = 2000;
    // Maximum number of Initial Hunters
    uint256 constant MAX_INITIAL_FARMERS = 3000;

    /*
        Returns the current cost to mint each type of token
        Parameters:
            c_type: The type of token
        NOTE: if farmer returns 1, or if coyote returns 2, prices are in AVAX
    */
    function getMintCost(uint8 c_type, uint256 val) public pure returns (uint256){
        if(c_type == 1){
            if(val < MAX_INITIAL_DUCKS){
                return 0 ether;
            }
            else if(val <= 20000){
                return 12000 ether;
            }
            else if(val <= 30000) {
                return 24000 ether;
            }
            else if(val <= 40000){
                return 40000 ether;
            }
            else {
                return 60000 ether;
            }
        }
        else if(c_type == 2){
            if(val < MAX_INITIAL_FARMERS){
                return 1 ether;
            }
            else if(val <= 4000){
                return 20000 ether;
            }
            else if(val <= 4500){
                return 22000 ether;
            }
            else if(val <= 5000){
                return 24000 ether;
            }
            else if(val <= 5500){
                return 28000 ether;
            }
            else {
                return 32000 ether;
            }
        }
        else{
            if(val < MAX_INITIAL_COYOTES){
                return 2 ether;
            }
            else if(val <= 2500){
                return 35000 ether;
            }
            else if(val <= 3000){
                return 50000 ether;
            }
            else if(val <= 3500){
                return 65000 ether;
            }
            else{
                return 80000 ether;
            }
        }
    }
}