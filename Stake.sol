// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./IERC721Receiver.sol";
import "./DuckyXGame.sol";
import "./ICreature.sol";
import "./EGG.sol";
import "./Pausable.sol";
import "./IRandomizer.sol";
import "./IStake.sol";

contract Stake is IStake, Ownable, IERC721Receiver, Pausable {
    event stolen(address stolenFrom);

    uint256 constant EGG_RATE = 1000;

    uint256 coyoteTaxPool;
    uint256 unclaimedEgg;

    uint256 public constant MAXIMUM_DXT = 1500000000 ether;
    uint256 DXTCounter;

    struct itemStake {
        uint8 action;
        uint16 tokenId;
        uint80 date;
        address owner;
    }

    struct farmerStake {
        uint16 tokenId;
        uint80 date;
        address owner;
    }

    struct coyoteStake {
        uint16 tokenId;
        uint80 date;
        address owner;
    }

    uint256 private seed;

    mapping(uint256 => itemStake) public stakedDucks;
    mapping(uint256 => coyoteStake) public stakedCoyotes;
    mapping(uint256 => farmerStake) public stakedFarmers;

    mapping(address => uint16) numFarmers;

    mapping(address => uint256[]) ownedTokens;

    uint256 totalCoyotesStaked;
    uint256[] coyoteHolders;

    DuckyXGame duck;
    EGG egg;

    ICreature public creature;

    constructor(address _duck, address _egg, uint256 sd) {
        duck = DuckyXGame(_duck);
        egg = EGG(_egg);
        totalCoyotesStaked = 0;
        DXTCounter = 0;
        seed = sd;
    }

    /*
        Sends duck to training stake
        Parameters:
            tokenId: Id of token
    */
    function AddDuckToTraining(uint256 tokenId) public whenNotPaused{
        ICreature.Ducky memory d = duck.getTokenTraits(tokenId);
        require(d.creatureType == 1);
        duck.transferFrom(_msgSender(), address(this), tokenId);
        stakedDucks[tokenId] = itemStake({
            action: 1,
            tokenId: uint16(tokenId),
            date: uint80(block.timestamp),
            owner: _msgSender()
        });
        ownedTokens[_msgSender()].push(tokenId);
    }

    /*
        Receives duck from training stake
        Parameters:
            tokenId: Id of token
    */
    function RemoveDuckFromTraining(uint256 tokenId) external {
        require(stakedDucks[tokenId].owner == _msgSender(), "You are not the owner");
        require(stakedDucks[tokenId].action == 1, "Duck is not training");
        require((block.timestamp - stakedDucks[tokenId].date) >= 4 hours, "Ducks must train for at least a day.");
        ICreature.Ducky memory d = duck.getTokenTraits(tokenId);
        if(uint8((block.timestamp - stakedDucks[tokenId].date) * 3 / 1 days) > 50){
            d.level = 50;
        }
        else {
            d.level = uint8((block.timestamp - stakedDucks[tokenId].date) * 3 / 1 days);
        }
        delete stakedDucks[tokenId];
        duck.updateTokenFromStake(tokenId, d);
        duck.safeTransferFrom(address(this), _msgSender(), tokenId, "");
        uint pos;
        for(uint i = 0; i < ownedTokens[_msgSender()].length; i++){
            if(ownedTokens[_msgSender()][i] == tokenId){
                pos = i;
                break;
            }
        }
        uint256 temp = ownedTokens[_msgSender()][ownedTokens[_msgSender()].length - 1];
        ownedTokens[_msgSender()][ownedTokens[_msgSender()].length - 1] = ownedTokens[_msgSender()][pos];
        ownedTokens[_msgSender()][pos] = temp;
        ownedTokens[_msgSender()].pop();
    }

    /*
        Sends duck to farming stake
        Parameters:
            tokenId: Id of token
    */
    function AddDuckToFarming(uint256 tokenId) public whenNotPaused{
        require(DXTCounter < MAXIMUM_DXT);
        ICreature.Ducky memory d = duck.getTokenTraits(tokenId);
        require(d.creatureType == 1);
        duck.transferFrom(_msgSender(), address(this), tokenId);
        stakedDucks[tokenId] = itemStake({
            action: 2,
            tokenId: uint16(tokenId),
            date: uint80(block.timestamp),
            owner: _msgSender()
        });
        ownedTokens[_msgSender()].push(tokenId);
    }

    /*
        Claims tokens from farming stake
        Parameters:
            tokenId: Id of token
            remove: True to also remove from stake, false to only claim tokens
    */
    function ClaimDuckFromFarming(uint256 tokenId, bool remove) external {
        require(stakedDucks[tokenId].owner == _msgSender(), "You are not the owner");
        require(stakedDucks[tokenId].action == 2, "Duck is not farming");
        require((block.timestamp - stakedDucks[tokenId].date) >= 4 hours);
        uint256 owed;
        ICreature.Ducky memory d = duck.getTokenTraits(tokenId);
        owed = ((block.timestamp - stakedDucks[tokenId].date) * (EGG_RATE + d.eggModifier + CheckFarmerBonus(_msgSender()))) / 1 days;
        if(remove){
            delete stakedDucks[tokenId];
            duck.safeTransferFrom(address(this), _msgSender(), tokenId, "");
            uint pos;
            for(uint i = 0; i < ownedTokens[_msgSender()].length; i++){
                if(ownedTokens[_msgSender()][i] == tokenId){
                    pos = i;
                    break;
                }
            }
            uint256 temp = ownedTokens[_msgSender()][ownedTokens[_msgSender()].length - 1];
            ownedTokens[_msgSender()][ownedTokens[_msgSender()].length - 1] = ownedTokens[_msgSender()][pos];
            ownedTokens[_msgSender()][pos] = temp;
            ownedTokens[_msgSender()].pop();
        }
        else{
            stakedDucks[tokenId] = itemStake({
                action: 2,
                tokenId: uint16(tokenId),
                date: uint80(block.timestamp),
                owner: _msgSender()
            });
        }
        if(DXTCounter >= MAXIMUM_DXT){
            owed = 0;
        }
        uint256 owedTax;
        if(numFarmers[_msgSender()] > 0){
            owedTax = (owed * 20) / 100;
        }
        else {
            owedTax = (owed * 30) / 100;
        }
        owed -= owedTax;
        PayTaxes(owedTax);
        egg.mint(_msgSender(), (owed * 1 ether));  
        DXTCounter += owed;
    }

    function addManyToFarm(uint256[] calldata tokenIds) external whenNotPaused {
        for(uint i = 0; i < tokenIds.length; i++){
            AddDuckToFarming(tokenIds[i]);
        }
    }

    function addManyToTrain(uint256[] calldata tokenIds) external whenNotPaused {
        for(uint i = 0; i < tokenIds.length; i++){
            AddDuckToTraining(tokenIds[i]);
        }
    }

    /*
        Sends farmer to stake (Max 2 farmers allowed)
        Parameters:
            tokenId: Id of token
    */
    function AddFarmerToStake(uint256 tokenId) external whenNotPaused{
        ICreature.Ducky memory d = duck.getTokenTraits(tokenId);
        require(numFarmers[_msgSender()] < 2, "Max 2 Farmers allowed in stake.");
        require(d.creatureType == 2);
        duck.transferFrom(_msgSender(), address(this), tokenId);
        stakedFarmers[tokenId] = farmerStake({
            tokenId: uint16(tokenId),
            date: uint80(block.timestamp),
            owner: _msgSender()
        });
        numFarmers[_msgSender()]++;
        ownedTokens[_msgSender()].push(tokenId);
    }

    function CheckFarmerBonus(address owner) public view returns(uint256){
        uint256 bonus;
        bonus = uint256(numFarmers[owner] * 50);
        return bonus;
    }

    /*
        Receives Farmer from stake
        Parameters:
            tokenId: Id of token
    */
    function RemoveFarmerFromStake(uint256 tokenId) external {
        require(stakedFarmers[tokenId].owner == _msgSender(), "You are not the Owner");
        delete stakedFarmers[tokenId];
        numFarmers[_msgSender()]--;
        duck.safeTransferFrom(address(this), _msgSender(), tokenId, "");
        uint pos;
        for(uint i = 0; i < ownedTokens[_msgSender()].length; i++){
            if(ownedTokens[_msgSender()][i] == tokenId){
                pos = i;
                break;
            }
        }
        uint256 temp = ownedTokens[_msgSender()][ownedTokens[_msgSender()].length - 1];
        ownedTokens[_msgSender()][ownedTokens[_msgSender()].length - 1] = ownedTokens[_msgSender()][pos];
        ownedTokens[_msgSender()][pos] = temp;
        ownedTokens[_msgSender()].pop();
    }

    /*
        Sends coyote to stake
        Parameters:
            tokenId: Id of token
    */
    function AddCoyoteToStake(uint256 tokenId) public whenNotPaused{
        require(DXTCounter < MAXIMUM_DXT);
        ICreature.Ducky memory d = duck.getTokenTraits(tokenId);
        require(d.creatureType == 3);
        duck.transferFrom(_msgSender(), address(this), tokenId);
        stakedCoyotes[tokenId] = coyoteStake({
            tokenId: uint16(tokenId),
            date: uint80(block.timestamp),
            owner: _msgSender()
        });
        totalCoyotesStaked++;
        coyoteHolders.push(tokenId);
        ownedTokens[_msgSender()].push(tokenId);
    }

    function addManyCoyotes(uint256[] calldata tokenIds) external whenNotPaused {
        for(uint i = 0; i < tokenIds.length; i++){
            AddCoyoteToStake(tokenIds[i]);
        }
    }

    /*
        Claims tokens from coyote stake
        Parameters:
            tokenId: Id of token
            remove: True to also remove from stake, false to only claim tokens
    */
    function ClaimCoyote(uint256 tokenId, bool remove) external {
        require(stakedCoyotes[tokenId].owner == _msgSender(), "You are not the owner");
        require((block.timestamp - stakedCoyotes[tokenId].date) >= 4 hours, "Coyote must stay for at least a day.");
        if(remove){
            delete stakedCoyotes[tokenId];
            totalCoyotesStaked--;
            duck.safeTransferFrom(address(this), _msgSender(), tokenId, "");
            uint pos;
            for(uint i = 0; i < coyoteHolders.length; i++){
                if(coyoteHolders[i] == tokenId){
                    pos = i;
                    break;
                }
            }
            uint256 temp = coyoteHolders[coyoteHolders.length - 1];
            coyoteHolders[coyoteHolders.length - 1] = coyoteHolders[pos];
            coyoteHolders[pos] = temp;
            coyoteHolders.pop();
            uint pos2;
            for(uint i = 0; i < ownedTokens[_msgSender()].length; i++){
                if(ownedTokens[_msgSender()][i] == tokenId){
                    pos2 = i;
                    break;
                }
            }
            uint256 temp2 = ownedTokens[_msgSender()][ownedTokens[_msgSender()].length - 1];
            ownedTokens[_msgSender()][ownedTokens[_msgSender()].length - 1] = ownedTokens[_msgSender()][pos2];
            ownedTokens[_msgSender()][pos2] = temp2;
            ownedTokens[_msgSender()].pop();
        }
        else{
            stakedCoyotes[tokenId] = coyoteStake({
                tokenId: uint16(tokenId),
                date: uint80(block.timestamp),
                owner: _msgSender()
            });
        }
        uint256 owed;
        if(DXTCounter >= MAXIMUM_DXT){
            owed = 0;
        }
        else {
            owed = coyoteTaxPool / totalCoyotesStaked;
        }
        coyoteTaxPool -= owed;
        egg.mint(_msgSender(), (owed * 1 ether));
        DXTCounter += owed;
    }

    function PayTaxes(uint256 amount) internal {
        if(totalCoyotesStaked == 0){
            unclaimedEgg += amount;
        }
        else {
            coyoteTaxPool += (amount + unclaimedEgg);
            unclaimedEgg = 0;
        }
    }

    /*
        Shows the current number of tokens a coyote can claim
    */
    function currentCoyoteLoot() external view returns(uint256) {
        return coyoteTaxPool / totalCoyotesStaked;
    }

    /*
        Shows the current number of tokens accumulated by a duck
        Parameters:
            tokenId: Id of the token
    */
    function currentDuckLoot(uint256 tokenId) external view returns(uint256){
        ICreature.Ducky memory d = duck.getTokenTraits(tokenId);
        require(d.creatureType == 1);
        return ((block.timestamp - stakedDucks[tokenId].date) * (EGG_RATE + d.eggModifier + CheckFarmerBonus(_msgSender()))) / 1 days;
    }

    /*
        Shows the current number of levels accumulated by a duck
        Parameters:
            tokenId: Id of the token
    */
    function currentDuckLevel(uint256 tokenId) external view returns(uint8) {
        ICreature.Ducky memory d = duck.getTokenTraits(tokenId);
        require(d.creatureType == 1);
        return uint8((block.timestamp - stakedDucks[tokenId].date) * 3 / 1 days);
    }

    /*
        Shows the current number of DXT tokens minted
    */
    function totalDXTMinted() external view returns(uint256) {
        return DXTCounter;
    }

    function onERC721Received(address, address from, uint256, bytes calldata)
        external pure override returns (bytes4) {
            require(from == address(0x0), "Cannot send tokens to Barn directly");
            return IERC721Receiver.onERC721Received.selector;
    }

    function randomCoyoteHolder(address person) external returns (address){
        if(coyoteHolders.length == 0){
            return person;
        }
        emit stolen(person);
        uint256 rand = uint256(random(coyoteHolders.length));
        uint256 randToken = coyoteHolders[rand];
        address winner = stakedCoyotes[randToken].owner;
        return winner;
    }

    /*
        Returns an array of all token Ids currently in the stake for a given owner
        Parameters:
            owner: wallet address to check
    */
    function getOwnedTokens(address owner) external view returns(uint256[] memory){
        return ownedTokens[owner];
    }

    /*
        Returns who the owner is for a given tokenId if the token is in the stake
        Parameters:
            tokenId: Id of the token to check
    */
    function getOwner(uint256 tokenId) external view returns(address){
        return stakedDucks[tokenId].owner;
    }

    function random(uint256 max) internal returns (uint8){
        seed = random();
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(
            tx.origin,
            block.timestamp,
            seed
        )));
        return uint8(randomNumber % max);
    }

    function random() internal view returns (uint256){
        return uint256(keccak256(abi.encodePacked(
            tx.origin,
            block.timestamp,
            seed
        )));
    }

    function rescue() external onlyOwner {
        for(uint i = 0; i < duck.balanceOf(address(this)); i++){
            uint256 tokenId = duck.tokenOfOwnerByIndex(address(this), i);
            ICreature.Ducky memory d = duck.getTokenTraits(tokenId);
            address owner;
            if(d.creatureType == 1){
                owner = stakedDucks[tokenId].owner;
            }
            else if(d.creatureType == 2) {
                owner = stakedFarmers[tokenId].owner;
            }
            else {
                owner = stakedCoyotes[tokenId].owner;
            }
            duck.safeTransferFrom(address(this), owner, tokenId, "");
        }
    }

    /*
        Returns the stake ducks are currently in. Returns 1 for training, and 2 for farming.
    */
    function getDuckState(uint256 tokenId) external view returns(uint8){
        return stakedDucks[tokenId].action;
    }

    function manualUnstake(uint256 tokenId) external onlyOwner() {
        ICreature.Ducky memory d = duck.getTokenTraits(tokenId);
        address owner;
        if(d.creatureType == 1){
            owner = stakedDucks[tokenId].owner;
        }
        else if(d.creatureType == 2) {
            owner = stakedFarmers[tokenId].owner;
        }
        else {
            owner = stakedCoyotes[tokenId].owner;
        }
        duck.safeTransferFrom(address(this), owner, tokenId, "");
    }
}