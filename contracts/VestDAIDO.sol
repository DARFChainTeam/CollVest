//SPDX-License-Identifier: GPL

pragma solidity >=0.4.22 <0.9.0;
import "./interfaces/i2SV.sol";
import "./interfaces/IERC20.sol";
import "./libs/SafeMath.sol";
/// @title Typical DAIDO vesting contract
/// @author The name of the author
/// @notice Explain to an end user what this does 
/// @dev Explain to a developer any extra details
contract VestDAIDO is i2SV {
    using SafeMath for uint256;

    //    Statuses:     0-created, 10- capped , 20 - started, 100 - paused 200 - aborted, 255 - finished

    uint8 constant CREATED = 1;
    uint8 constant SOFTCAPPED = 9;
    uint8 constant CAPPED = 10;
    uint8 constant STARTED = 20;
    uint8 constant PAUSED = 100;
    uint8 constant VOTING = 150;
    uint8 constant ABORTED = 200;
    uint8 constant REFUNDING = 220;
    
    uint8 public status ; // (0- created, 10- capped , 20 - started, 100 - paused 200 - aborted, 255 - finished )
    uint16 public votesForAbort;    
    bool isConfigured;    
    uint256 raisedToken1; // sum raised in  token1
    uint256 raisedToken2;  // sum raised in  token2
    uint256 withdrawedToken1; // sum withdrawed in  token1
    uint256 withdrawedToken2;  // sum withdrawed in  token2


    Vesting public vest;
    
    Rule[] public rules; 
    Withdrawpauses[] public pauses;
    address[] public vestors;
    

    mapping(address => mapping (address => uint256)) public  vested; //token => address of user
    mapping(address => mapping (address => uint256))  public withdrawed; //token => address of user
    mapping(address => bool) public voters; 

    address constant ETHCODE = address(0x0000000000000000000000000000000000000001);
    /// @notice setVesting sets parameters of vesting 
    function setVesting (
        Vesting calldata _vest,
        Rule[] calldata _rules
        ) public override { 
        require(!isConfigured, "can't change anything");
        if (_vest.isNative) require( _vest.token1 == ETHCODE, "Error in config native token");
        
        uint256 amount1;
        uint256 amount2;            
        for (uint8 i=0; i<_rules.length; i++) {
            amount1 += _rules[i].amount1;
            amount2 += _rules[i].amount2;            
            rules.push (_rules[i]); 
        }
        require(amount1 == _vest.amount1 && amount2 == _vest.amount2, "Error in vest schedule"  );
        vest = _vest;
        isConfigured = true;
        emit CreatedVesting(address(this),_vest, _rules);
        emit VestStatus(address(this),CREATED);
        }
    
    
    function putVesting (address _token, address _recepient, uint256 _amount) public override  payable {
    /// @notice accepts vesting payments from both sides 
    /// @dev divides for native and ERC20 flows
    /// @param  _token - address of payment token,  "0x01" for native blockchain tokens 
    /// @param  _recepient - address of wallet, who can claim tokens
    /// @param  _amount - sum of vesting payment in wei 

    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        (bool ok, uint256 curVest) =  vested[_token][_recepient].tryAdd(_amount);
        require(ok,  "curVest.tryAdd" );
        if (curVest == _amount) vestors.push(_recepient);            
            
        if (_token == vest.token1) {       
            if (vest.isNative){ // payments with native token                     

                require(_amount == msg.value, "amount must be equal to sent ether");
            } else {
                IERC20(_token).transferFrom(msg.sender, address(this), _amount);
            }
            raisedToken1 = raisedToken1.add( _amount);
            require(raisedToken1 <= vest.amount1, "Token1 capped");
        } else if (_token == vest.token2)  {
            raisedToken2 = raisedToken2.add( _amount);
            require(raisedToken2 <= vest.amount2, "Token2 capped");
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        }
                
        vested[_token][_recepient] = curVest;
        emit Vested(address(this), _token, msg.sender, _amount);

        if (vest.softCap1 >0 && vest.softCap2 > 0 && //softCap case
            raisedToken1 >= vest.softCap1 && 
            raisedToken2 >= vest.softCap2 &&
            ((vest.isNative && address(this).balance >=  vest.softCap1) ||
            (!vest.isNative && IERC20(vest.token1).balanceOf(address(this)) >= vest.softCap1)) &&
             IERC20(vest.token2).balanceOf(address(this)) >= vest.softCap2
            ) {
                status = SOFTCAPPED;
                emit VestStatus(address(this),status);

            }
        

        if (raisedToken1 >= vest.amount1 && 
            raisedToken2 >= vest.amount2 &&
            ((vest.isNative && address(this).balance >=  vest.amount1) ||
            (!vest.isNative && IERC20(vest.token1).balanceOf(address(this)) >= vest.amount1)) &&
             IERC20(vest.token2).balanceOf(address(this)) >= vest.amount2
            ) {
                status = CAPPED;
                emit VestStatus(address(this),status);

            }
        
 
        }
    
    function startSoftCapped (bool _start )  public {
        require(vested[vest.token1][msg.sender] > 0 && vested[vest.token2][msg.sender]>0 , "only vestor can start " );
        if (status > SOFTCAPPED && _start /* && block.timestamp > vest.startDate */) status = STARTED;
    }

    function isPaused () public view returns (bool) {
        for (uint8 i=0; i<pauses.length; i++){            
            if (pauses[i].pauseTime > 0 && block.timestamp < pauses[i].pauseTime+vest.pausePeriod) return true;
        }
        return false;
    }

    function availableClaimToken1 () public view returns (uint256 avAmount) {
        /// @notice calculates  available amount of token1 for claiming by team
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if ( isPaused() ||  status == ABORTED || status < CAPPED)  return 0;
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                avAmount = avAmount.add(rules[i].amount1); 
           }
        }
          avAmount =  avAmount.sub(withdrawed[vest.token1][vest.teamWallet]);        
    }


    function claimWithdrawToken1(uint256 _amount) public  {
        /// @notice withdraw _amount of ERC20 or native tokens 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 desired amount of  claiming token , 

        require(!isPaused(), "Withdraw paused by participant");
        require(status != ABORTED , "Vesting aborted");
        require(status >= CAPPED,  "Vesting not capped");
//        require(msg.sender == vest.teamWallet, "just call from teamwallet"); //tbd is necessary or not?
       
        uint256 avAmount = availableClaimToken1();
        require(_amount <= avAmount, "No enough amount for withdraw");
        
        withdrawed[vest.token1][vest.teamWallet] =  withdrawed[vest.token1][vest.teamWallet].add(_amount);
        withdrawedToken1 = withdrawedToken1.add(_amount);
        if (vest.isNative) {
            payable(vest.teamWallet).transfer(_amount);
        }
        else { 
            IERC20(vest.token1).transfer(vest.teamWallet, _amount);            
         }
        emit Claimed(address(this), vest.token1, msg.sender, _amount);
    }

    function availableClaimToken2 () public view returns (uint256 avAmount) {
        /// @notice calculates  available amount of token2 for claiming by vestors
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if ( isPaused() ||  status == ABORTED || status < CAPPED)  return 0;
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                avAmount = avAmount.add(rules[i].amount2); 
           }
        }
            avAmount = avAmount.mul(vested[vest.token1][msg.sender]).div(raisedToken1);
            avAmount = avAmount.sub(withdrawed[vest.token2][msg.sender]);        
    } 

    function claimWithdrawToken2(uint256 _amount) public override { 
        /// @notice withdraw _amount of ERC20 or native tokens 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 desired amount of  claiming token , 

        require(!isPaused(), "Withdraw paused by participant");
        require(status != ABORTED , "Vesting aborted");
        require(status >= CAPPED,  "Vesting not capped");
       
        uint256 avAmount = availableClaimToken2();
        require(_amount <= avAmount, "No enough amount for withdraw");
        withdrawed[vest.token2][msg.sender] = withdrawed[vest.token2][msg.sender].add(_amount);
        withdrawedToken2 = withdrawedToken2.add(_amount);
        IERC20(vest.token2).transfer( msg.sender, _amount);
        emit Claimed(address(this), vest.token2, msg.sender, _amount);
    }
    

  
    function pauseWithdraw() public override {
        require(vested[vest.token1][msg.sender] > vest.vestShare4pauseWithdraw * raisedToken1 /100 ||
                vested[vest.token2][msg.sender] > vest.vestShare4pauseWithdraw * raisedToken1 /100, 
                "Didn't vested enough to pause work"
                );
        pauses.push(Withdrawpauses(msg.sender, block.timestamp));
        status = PAUSED;
        emit VestStatus(address(this),PAUSED);
        
    }
    

    function voteAbort(bool _vote) public override {
        if (_vote && isPaused())  {
            require (!voters[msg.sender], "already voted!");
            voters[msg.sender] = true;
            uint shareVote = vested[vest.token1][msg.sender].mul(100).div(raisedToken1);
            shareVote = shareVote.add( vested[vest.token2][msg.sender].mul(100).div(raisedToken2));
            votesForAbort = votesForAbort + uint16(shareVote);
            if (status != VOTING) {
                status = VOTING;
                emit VestStatus(address(this), VOTING);
                }
            emit Voting(address(this), shareVote); 
            if (votesForAbort >  vest.voteShareAbort ) {
                emit VestStatus(address(this),ABORTED);
                status = ABORTED ;
            }
        } else if (!isPaused()) {
            votesForAbort =0;
        }
        
    }

    function refund () public {
        require(status == ABORTED , "Vesting works normally, can't refund" );
        uint256 avAmount1;
        //refund token1
        if (vested[vest.token1][msg.sender] > 0) { 
            avAmount1 = raisedToken1 - withdrawedToken1;//address(this).balance;
            if (vest.isNative) {
                // checking balance of ether
                avAmount1 = avAmount1.mul(vested[vest.token1][msg.sender]).div(vest.amount1);
                payable(msg.sender).transfer(avAmount1);
            }
            else { 
                // checking balance of ERc20 token
                avAmount1 = avAmount1.mul(vested[vest.token1][msg.sender]).div(vest.amount1);
                IERC20(vest.token1).transfer( msg.sender, avAmount1);
            }
        }
        //refund token2 
        uint256 avAmount2;
        if (vested[vest.token2][msg.sender] > 0) { 
            avAmount2 = raisedToken2 - withdrawedToken2; //IERC20(vest.token2).balanceOf(address(this));
            avAmount2 = avAmount2.mul(vested[vest.token2][msg.sender]).div(vest.amount2);
            IERC20(vest.token2).transfer( msg.sender, avAmount2);
        }
    }

    function getVestedTok1 () public view returns (uint256) {
        return (vested[vest.token1][msg.sender]);
    }
    function getVestedTok2 () public view returns (uint256) {
        return (vested[vest.token2][msg.sender]);
    }

    

}
