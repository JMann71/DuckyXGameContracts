// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.0;

import "./ERC721Enumerable.sol";
import "./IDuckGenerator.sol";
import "./ICreature.sol";
import "./EGG.sol";
import "./Ownable.sol";
import "./IStake.sol";
import "./Pausable.sol";

contract DuckyXGame is ICreature, ERC721Enumerable, Ownable, Pausable {
    // Current amount of minted tokens
    uint256 public minted;
    // Current amount of minted initial ducks
    uint256 public mintedInitialDucks;
    // Current amount of minted initial wolves
    uint256 public mintedInitialCoyotes;
    // Current amount of minted initial farmers
    uint256 public mintedInitialFarmers;
    // Current amount of minted paid ducks
    uint256 public mintedPaidDucks;
    // Current amount of minted paid coyotes
    uint256 public mintedPaidCoyotes;
    // Current amount of minted paid hunters
    uint256 public mintedPaidFarmers;

    uint256 private seed;

    mapping(uint256 => Ducky) public duckTraits;

    mapping(uint256 => uint256) createdCreatures;

    mapping(uint256 => uint80) public poolDown;

    mapping(address => bool) whitelistedAddresses;
    mapping(address => uint8) numWhitelistedDucks;
    mapping(address => uint8) numWhitelistedFarmers;
    mapping(address => uint8) numWhitelistedCoyotes;

    bool whitelistEnabled;

    IDuckGenerator duckGenerator;
    EGG egg;
    IStake stake;
    address stakeAddress;

    // Number of times a tier of lootpool has been used
    // Max 10,000
    uint256 public tier1Uses;
    // Max 8,000
    uint256 public tier2Uses;
    // Max 6,000
    uint256 public tier3Uses;
    // Max 3,000
    uint256 public tier4Uses;
    // Max 1,000
    uint256 public tier5Uses;

    constructor(address _dg, address _egg, uint256 sd) ERC721("DuckyXGame", 'DXGAME'){
        mintedPaidDucks = 10000;
        mintedPaidFarmers = 3000;
        mintedPaidCoyotes = 2000;
        duckGenerator = IDuckGenerator(_dg);
        egg = EGG(_egg);
        whitelistEnabled = true;
        seed = sd;
    }

    /*
        Mints a token (Duck, Coyote, Hunter)
        Can mint up to 6 ducks at a time, and up to 10 at a time for Coyotes and Hunters
        Parameters:
        c_type - the type of token to mint.
            1 - Duck
            2 - Farmer
            3 - Coyote
        amount - number to be minted
    */
    function mint(uint8 c_type, uint256 amount) external payable whenNotPaused{
        if(c_type == 1){
            require(amount > 0 && amount <= 4);
            if(mintedInitialDucks >= 10000){
                require(mintedPaidDucks + amount <= 50000);
            }     
        }
        else if(c_type == 2){
            require(amount > 0 && amount <= 2);
            if(mintedInitialFarmers >= 3000){
                require(mintedPaidFarmers + amount <= 6000);
            }
            else{
                require(amount * 1 ether == msg.value);
            }
        }
        else if(c_type == 3){
            require(amount > 0 && amount <= 1);
            if(mintedInitialCoyotes >= 2000){
                require(mintedPaidCoyotes + amount <= 4000);
            }
            else {
                require(amount * 2 ether == msg.value);
            }

        }
        for(uint i = 0; i < amount; i++){
            address recipient = _msgSender();
            if(c_type == 1){
                if(mintedInitialDucks >= 10000){
                    egg.burn(_msgSender(), getMintCost(c_type));
                    mintedPaidDucks++;
                    if(random(100) > 80){
                        recipient = stake.randomCoyoteHolder(_msgSender());
                    }
                }
                else{
                    if(whitelistEnabled){
                        require(whitelistedAddresses[_msgSender()]);
                        require(numWhitelistedDucks[_msgSender()] < 4);
                        numWhitelistedDucks[_msgSender()]++;
                    }
                    mintedInitialDucks++;
                }
                minted++;
                generateDuck(minted, c_type);
            }
            else if(c_type == 2){
                if(mintedInitialFarmers >= 3000){
                    egg.burn(_msgSender(), getMintCost(c_type));
                    mintedPaidFarmers++;
                }
                else{
                    if(whitelistEnabled){
                        require(whitelistedAddresses[_msgSender()]);
                        require(numWhitelistedFarmers[_msgSender()] < 2);
                        numWhitelistedFarmers[_msgSender()]++;
                    }
                    mintedInitialFarmers++;
                }
                minted++;
                generateDuck(minted, c_type);
            }
            else if(c_type == 3){
                if(mintedInitialCoyotes >= 2000){
                    egg.burn(_msgSender(), getMintCost(c_type));
                    mintedPaidCoyotes++;
                }
                else{
                    if(whitelistEnabled){
                        require(whitelistedAddresses[_msgSender()]);
                        require(numWhitelistedCoyotes[_msgSender()] < 1);
                        numWhitelistedCoyotes[_msgSender()]++;
                    }
                    mintedInitialCoyotes++;
                }
                minted++;
                generateDuck(minted, c_type);
            }
            _safeMint(recipient, minted);
        }
    }

    /*
        Sends a duck to the lootpool
        Requires sender to be the owner
        Can only be used once every 30 minutes
        Parameters:
            tokenId: The token to use
            tier: The tier lootpool to use
        Each tier requires 3 levels more than the last, starting at level 3
            i.e
                tier 1 requires level 3
                tier 2 requires level 6
    */
    function LootPool(uint256 tokenId, uint8 tier) external whenNotPaused{
        require((_isApprovedOrOwner(_msgSender(), tokenId)) || (stake.getOwner(tokenId) == _msgSender()));
        require((duckTraits[tokenId].creatureType == 1) && (block.timestamp - poolDown[tokenId] >= 30 minutes));
        poolDown[tokenId] = uint80(block.timestamp);
        Ducky memory d = getTokenTraits(tokenId);
        uint8 rand = random(100);
        if(tier == 1){
            require(d.level >= 3);
            require(tier1Uses < 10000);
            tier1Uses++;
            if(rand < 65){
                d.eggModifier = 100;
            }
            else if(rand < 90){
                d.eggModifier = 200;
            }
            else {
                d.eggModifier = 300;
            }
        }
        else if(tier == 2){
            require(d.level >= 6);
            require(tier2Uses < 8000);
            tier2Uses++;
            if(rand < 65){
                d.eggModifier = 200;
            }
            else if(rand < 90){
                d.eggModifier = 300;
            }
            else {
                d.eggModifier = 400;
            }
        }
        else if(tier == 3){
            require(d.level >= 9);
            require(tier3Uses < 6000);
            tier3Uses++;
            if(rand < 65){
                d.eggModifier = 300;
            }
            else if(rand < 90){
                d.eggModifier = 400;
            }
            else {
                d.eggModifier = 500;
            }
        }
        else if(tier == 4){
            require(d.level >= 12);
            require(tier4Uses < 3000);
            tier4Uses++;
            if(rand < 65){
                d.eggModifier = 400;
            }
            else if(rand < 90){
                d.eggModifier = 500;
            }
            else {
                d.eggModifier = 600;
            }
        }
        else if(tier == 5){
            require(d.level >= 15);
            require(tier5Uses < 1000);
            tier5Uses++;
            if(rand < 70){
                d.eggModifier = 500;
            }
            else if(rand < 95){
                d.eggModifier = 600;
            }
            else {
                d.eggModifier = 700;
            }
        }
        duckTraits[tokenId] = d;
    }

    /*
        Returns the current cost to mint each type of token
        Parameters:
            c_type: The type of token
        NOTE: if farmer returns 1, or if coyote returns 2, prices are in AVAX
    */
    function getMintCost(uint8 c_type) public view returns (uint256){
        if(c_type == 1){
            if(mintedPaidDucks <= 10000){
                return 0 ether;
            }
            else if(mintedPaidDucks <= 20000){
                return 5000 ether;
            }
            else if(mintedPaidDucks <= 30000) {
                return 12000 ether;
            }
            else if(mintedPaidDucks <= 40000){
                return 21000 ether;
            }
            else {
                return 32000 ether;
            }
        }
        else if(c_type == 2){
            if(mintedPaidFarmers <= 3000){
                return 1 ether;
            }
            else if(mintedPaidFarmers <= 4000){
                return 14000 ether;
            }
            else if(mintedPaidFarmers <= 4500){
                return 20000 ether;
            }
            else if(mintedPaidFarmers <= 5000){
                return 28000 ether;
            }
            else if(mintedPaidFarmers <= 5500){
                return 38000 ether;
            }
            else {
                return 50000 ether;
            }
        }
        else{
            if(mintedPaidCoyotes <= 2000){
                return 2 ether;
            }
            else if(mintedPaidCoyotes <= 2500){
                return 25000 ether;
            }
            else if(mintedPaidCoyotes <= 3000){
                return 35000 ether;
            }
            else if(mintedPaidCoyotes <= 3500){
                return 50000 ether;
            }
            else{
                return 70000 ether;
            }
        }
    }

    /*
        Generates traits of a token
        Parameters:
            tokenId: Id of the token
            seed: a number used for random generation
            c_type: type of token to mint
        Internal use only for minting
    */
    function generateDuck(uint256 tokenId, uint8 c_type) internal returns (Ducky memory d){
        d.creatureType = c_type;
        if(c_type == 1){
            d.layer_0 = random(15);
            d.layer_1 = random(17);
            d.layer_2 = random(33);
            d.layer_3 = random(12);
        }
        else if(c_type == 2){
            d.layer_0 = random(5);
            d.layer_1 = random(7);
            d.layer_2 = random(5);
            d.layer_3 = random(10);
            d.layer_4 = random(5);
            d.layer_5 = random(9);
            d.layer_6 = random(6);
        }
        else if(c_type == 3){
            d.layer_0 = random(9);
            d.layer_1 = random(15);
            d.layer_2 = random(3);
            d.layer_3 = random(12);
        }
        if(createdCreatures[structToHash(d)] == 0){
            duckTraits[tokenId] = d;
            createdCreatures[structToHash(d)] = tokenId;
            return d;
        }
        else{
            return generateDuck(tokenId, c_type);
        }
    }

    /*
        Converts Creature Struct to hash to check uniqueness
    */
    function structToHash(Ducky memory d) internal pure returns (uint256) {
        return uint256(bytes32(
            abi.encodePacked(
                d.creatureType,
                d.layer_0,
                d.layer_1,
                d.layer_2,
                d.layer_3,
                d.layer_4,
                d.layer_5,
                d.layer_6
            )
        ));
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory){
        require(_exists(tokenId));
        return duckGenerator.tokenURI(tokenId);
    }

    function getTokenTraits(uint256 tokenId) public view override returns (Ducky memory) {
        require(_exists(tokenId));
        return duckTraits[tokenId];
    }

    function updateTokenFromStake(uint256 tokenId, Ducky memory d) public {
        require( _msgSender() == stakeAddress);
        duckTraits[tokenId] = d;
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        if (_msgSender() != address(stake)){
            require(_isApprovedOrOwner(_msgSender(), tokenId));
        }
        _transfer(from, to, tokenId);
    }

    function setStake(address _stake) external onlyOwner {
        stake = IStake(_stake);
        stakeAddress = _stake;
    }

    function setWhitelist(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
    }

    function addToWhitelist(address[] calldata users) external onlyOwner {
        for(uint i = 0; i < users.length; i++){
            whitelistedAddresses[users[i]] = true;
        }
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function random(uint256 max) internal returns (uint8){
        seed = random();
        return uint8(uint256(keccak256(abi.encodePacked(
            tx.origin,
            block.timestamp,
            seed
        ))) % max);
    }

    function random() internal view returns (uint256){
        return uint256(keccak256(abi.encodePacked(
            tx.origin,
            block.timestamp,
            seed
        )));
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount){
        return(owner(), (_salePrice * 10) / 100);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return true;
    }
}