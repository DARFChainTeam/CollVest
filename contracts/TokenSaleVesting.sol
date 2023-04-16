//SPDX-License-Identifier: GPL

pragma solidity >=0.4.22 <0.9.0;
import "./interfaces/i2SVstruct.sol";
import "./interfaces/IERC20.sol";
import "./libs/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title Typical DAIDO  vesting contract
/// @author @Stanta
/// @notice The team has issued tokens on TGE first time  and wants to sell them to a group of investors. Investors want to control the progress of the project. Thats why unlock for both sides goes step-by-step.

contract TokenSaleVesting is i2SVstruct,  AccessControl { 
    using SafeMath for uint256;
    
    bytes32 public constant WHITELISTED_ADDRESS = keccak256("WHITELISTED_ADDRESS");
    struct Migrant {
        address addr;
        uint256 am;
    }

    uint8 constant CREATED = 1;
    
    uint8 constant SOFTCAPPED = 9;
    uint8 constant CAPPED = 10;
    
    uint8 constant FINISHED = 255;


    uint8 public status ; // (1- created, 10- capped , 20 - started, 100 - paused 200 - aborted, 255 - finished )
    
    bool public isConfigured;    
    uint256 public raisedToken1; // sum raised in  token1
    uint256 public raisedToken2;  // sum raised in  token2
    uint256 public withdrawedToken1; // sum withdrawed in  token1
    uint256 public withdrawedToken2;  // sum withdrawed in  token2

    Vesting public vest;
    Rule[] public rules; 
    address[] public vestors;
    

    mapping(address => mapping (address => uint256)) public  vested; //token => address of user
    mapping(address => mapping (address => uint256))  public withdrawed; //token => address of user

    address constant ETHCODE = address(0x0000000000000000000000000000000000000001);

    address private owner_;
    address private factory;
    address private treasure;
    uint8 public fee ; // 5/1000 = 0,5%
    bool nonInitialised = true;


    
    function initialize (address _owner, address _treasure, uint8 _fee )  public {
        require(!nonInitialised, "Admin already set");
        _setRoleAdmin("WL", DEFAULT_ADMIN_ROLE); 
        _grantRole(getRoleAdmin("WL"), _owner);
        _setupRole(WHITELISTED_ADDRESS, _owner);

        treasure = _treasure;
        factory = _msgSender();
        fee = _fee;
        nonInitialised = false;
    }
    
    
    function setupWhiteList (address[] calldata _wl ) public {
        for (uint16 roleN = 0; roleN < _wl.length; roleN ++) {
            grantRole (WHITELISTED_ADDRESS, _wl[roleN]);
        }
    }

    function migrateUsers(Migrant[] calldata _migrants ) public onlyRole(getRoleAdmin(WHITELISTED_ADDRESS)){
        for (uint16 m = 0; m < _migrants.length; m ++) {
            _migrateUser(_migrants[m].addr, _migrants[m].am); 
        }

    }
    function buy( uint256 _amount, address _recipient) public {
        require (vest.vest2.roundStartTime <= block.timestamp && vest.vest2.capFinishTime > block.timestamp, "round not active now");
        require (vest.vest2.nonWhitelisted || hasRole("WL", _msgSender()), "msg.sender not in whitelist");

        if (vest.vest2.prevRound != address(ETHCODE) ) {
                require (TokenSaleVesting(vest.vest2.prevRound).status() >=CAPPED, "Didn't finished previous round"); 
            }  
        uint256 curVest =  vested[vest.vest1.token1][_recipient] +_amount;
        if (curVest == _amount) vestors.push(_recipient);          
        if (vest.vest1.maxBuy1 > 0) require(curVest <= vest.vest1.maxBuy1, "limit of vesting overquoted for this address" );
        if (vest.vest1.minBuy1 > 0) require(curVest >= vest.vest1.minBuy1, "sum toooo small to buy" );
        IERC20(vest.vest1.token1).transferFrom(msg.sender, address(this), _amount);
        IERC20(vest.vest1.token1).transfer( treasure,  _amount);
        
        raisedToken1 = raisedToken1.add( _amount);
        vested[vest.vest1.token1][_recipient] = curVest;
        emit Vested(address(this), vest.vest1.token1, _recipient, _amount);        
        require(raisedToken1 <= vest.vest1.amount1, "Token1 capped");
        {
        if (vest.vest1.softCap1 >0 && //softCap case
            raisedToken1 >= vest.vest1.softCap1 &&             
            ((vest.vest2.isNative && address(this).balance >=  vest.vest1.softCap1) ||
            (!vest.vest2.isNative && IERC20(vest.vest1.token1).balanceOf(address(this)) >= vest.vest1.softCap1))
            ) {
                status = SOFTCAPPED;
                emit VestStatus(address(this),status);

            }
        

        if (raisedToken1 >= vest.vest1.amount1 && 
            raisedToken2 >= vest.vest1.amount2 &&
            ((vest.vest2.isNative && address(this).balance >=  vest.vest1.amount1) ||
            (!vest.vest2.isNative && IERC20(vest.vest1.token1).balanceOf(address(this)) >= vest.vest1.amount1)) &&
             IERC20(vest.vest1.token2).balanceOf(address(this)) >= vest.vest1.amount2
            ) {
                status = CAPPED;
                emit VestStatus(address(this),status);

            }
        }
        _migrateUser (_recipient, _amount.mul(vest.vest1.amount1).div(vest.vest1.amount2));
        claim(availableClaim());
    }



    function _migrateUser (address _recipient, uint256 _amount) internal {
        raisedToken2 = raisedToken2.add( _amount);
        require(raisedToken2 <= vest.vest1.amount2, "Token2 capped");
        vested[vest.vest1.token2][_recipient] += _amount;
        emit Vested(address(this), vest.vest1.token2, _recipient, _amount);
    }

 
    function availableClaim() public view   returns (uint256 avAmount) {
        /// @notice calculates  available amount of token2 for claiming by vestors
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                uint256 inc = rules[i].amount2;
                avAmount = avAmount.add(inc); 

           }
        }
            avAmount = avAmount.mul(vested[vest.vest1.token2][msg.sender]);
            avAmount = avAmount.sub(withdrawed[vest.vest1.token2][msg.sender]);        
    } 

    function  claim (uint256 _amount) public    { 
        /// @notice withdraw _amount of ERC20 or native tokens 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 desired amount of  claiming token , 

        // require(!isPaused(), "Withdraw paused by participant");
        // require(status != ABORTED , "Vesting aborted");
        require(status >= CAPPED,  "Vesting not capped");
       
        uint256 avAmount = availableClaim();
        require(_amount <= avAmount, "No enough amount for withdraw");
        withdrawed[vest.vest1.token2][msg.sender] = withdrawed[vest.vest1.token2][msg.sender].add(_amount);
        withdrawedToken2 = withdrawedToken2.add(_amount);
       
        
        emit Claimed(address(this), vest.vest1.token2, msg.sender, _amount);
        if (raisedToken1 == withdrawedToken1 && raisedToken2 == withdrawedToken2) { 
            status = FINISHED;
            emit Finished (address(this));
        }
        
    }

    function rate () public view returns (uint256){
        return vest.vest1.amount2.div(vest.vest1.amount1);        
    }   

    function getUserInfo () public view   returns (
            uint256 amount,
            uint256 available,
            uint256 amountWithClaimed,
            uint256 currentLockTime
        ){
        amount =  vested[vest.vest1.token2][msg.sender];
        available = availableClaim();
        amountWithClaimed = available + withdrawed[vest.vest1.token2][msg.sender];
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime > block.timestamp){
                currentLockTime = rules[i].claimTime;
                break;            
           }
        }
    }
    
}
