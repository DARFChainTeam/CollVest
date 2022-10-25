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
    uint8 constant CAPPED = 10;
    uint8 constant STARTED = 20;
    uint8 constant PAUSED = 100;
    uint8 constant ABORTED = 200;
    uint8 constant FINISHED = 255;
    
    uint8 public status ; // (0- created, 10- capped , 20 - started, 100 - paused 200 - aborted, 255 - finished )
    uint16 public votesForAbort;    
    bool isConfigured;    
    uint256 raisedToken1; // sum raised in  token1
    uint256 raisedToken2;  // sum raised in  token2
    Vesting public vest;
    
    Rule[] public rules; 
    Withdrawpauses[] public pauses;
    address[] public vestors;
    

    mapping(address => mapping (address => uint256))  vested; //token => address of user
    mapping(address => mapping (address => uint256))  withdrawed; //token => address of user

    address constant ETHCODE = address(0x1);
    /// @notice setVesting sets parameters of vesting 
    function setVesting (
        Vesting calldata _vest,
        Rule[] calldata _rules
        ) public override { 
        require(!isConfigured, "can't change anything");
        require(_vest.isNative && _vest.token1 == ETHCODE, "Error in config native token");
        
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
            // payments with ERC20 token               
        if (_token == vest.token1) {       
            if (vest.isNative) {
            // payments with native token        
                require(_amount == msg.value, "amount must be equal to sent ether");
            } 
            raisedToken1 = raisedToken1.add( _amount);
            require(raisedToken1 <= vest.amount1, "Token1 capped");
        } else  {
            raisedToken2 = raisedToken2.add( _amount);
            require(raisedToken2 <= vest.amount2, "Token2 capped");
        }
        if (raisedToken1 >= vest.amount1 && raisedToken2 >= vest.amount2  ) status = CAPPED;
        
        vested[_token][_recepient] = curVest;
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        }
    

    function isPaused () public view returns (bool) {
        for (uint8 i=0; i<pauses.length; i++){            
            if (block.timestamp > pauses[i].pauseTime+vest.pausePeriod) return true;
        }
        return false;
    }

    function availableClaimToken1 () public view returns (uint256 avAmount) {
        /// @notice calculates  available amount of token1 for claiming by team
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if (!isPaused() || status == ABORTED || status < CAPPED)  return 0;
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                avAmount.add(rules[i].amount1); 
           }
        }
            avAmount.sub(withdrawed[vest.token1][vest.teamWallet]);        
    }


    function claimWithdrawToken1(uint256 _amount) public  {
        /// @notice withdraw _amount of ERC20 or native tokens 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 desired amount of  claiming token , 

        require(!isPaused(), "Withdraw paused by participant");
        require(status != ABORTED , "Vesting aborted");
        require(status >= CAPPED,  "Vesting not capped");
       
        uint256 avAmount = availableClaimToken1();
        require(_amount <= avAmount, "No enough amount for withdraw");
        
        withdrawed[vest.token1][vest.teamWallet].add(_amount);
       
        if (vest.isNative) {
            payable(vest.teamWallet).transfer(_amount);
        }
        else { 
            IERC20(vest.token1).transferFrom( address(this), vest.teamWallet, _amount);
         }
    }

    function availableClaimToken2 () public view returns (uint256 avAmount) {
        /// @notice calculates  available amount of token2 for claiming by vestors
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if (!isPaused() || status == ABORTED || status < CAPPED )  return 0;
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                avAmount.add(rules[i].amount2); 
           }
        }
            avAmount.mul(vested[vest.token1][msg.sender]).div(raisedToken1);
            avAmount.sub(withdrawed[vest.token2][msg.sender]);        
    } 

    function claimWithdrawToken2(uint256 _amount) public override { 
        /// @notice withdraw _amount of ERC20 or native tokens 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 desired amount of  claiming token , 

        require(!isPaused(), "Withdraw paused by participant");
        require(status != ABORTED , "Vesting aborted");
        require(status >= CAPPED,  "Vesting not capped");
       
        uint256 avAmount = availableClaimToken1();
        require(_amount <= avAmount, "No enough amount for withdraw");
        withdrawed[vest.token2][msg.sender].add(_amount);

        IERC20(vest.token2).transferFrom( address(this), msg.sender, _amount);
    }
    

  
    function pauseWithdraw() public override {
        require(vested[vest.token1][msg.sender] > vest.vestShare4pauseWithdraw * raisedToken1 /100 ||
                vested[vest.token2][msg.sender] > vest.vestShare4pauseWithdraw * raisedToken1 /100, 
                "Didn't vested enough to pause work"
                );
        pauses.push(Withdrawpauses(msg.sender, block.timestamp));
        
    }
    

    function voteAbort(bool _vote) public override {
        if (_vote && isPaused())  {
            votesForAbort+=1;
            if (votesForAbort > vestors.length * vest.voteShareAbort / 100) {
                status = ABORTED ;
            }
        } else if (!isPaused()) {
            votesForAbort =0;
        }
        
    }

    function refund () public {
        require(status == ABORTED , "Vesting works normally, can't refund" );
        uint256 avAmount;
        //refund token1
        if (vested[vest.token1][msg.sender] > 0) { 
            if (vest.isNative) {
                // checking balance of ether
                avAmount = address(this).balance;
                avAmount.mul(vested[vest.token1][msg.sender]).div(vest.amount1);
                payable(msg.sender).transfer(avAmount);
            }
            else { 
                // checking balance of ERc20 token
                avAmount = IERC20(vest.token1).balanceOf(address(this));                
                avAmount.mul(vested[vest.token1][msg.sender]).div(vest.amount1);
                IERC20(vest.token1).transferFrom( address(this), msg.sender, avAmount);
            }
        }
        //refund token2 
        if (vested[vest.token2][msg.sender] > 0) { 
            avAmount = IERC20(vest.token2).balanceOf(address(this));
            avAmount.mul(vested[vest.token2][msg.sender]).div(vest.amount2);
            IERC20(vest.token2).transferFrom( address(this), msg.sender, avAmount);
        }
    }

    function getVested () public view returns (/* uint256, */ uint256) {
        return (/* vested[vest.token1][msg.sender],  */vested[vest.token2][msg.sender]);
    }

}
