//SPDX-License-Identifier: GPL

pragma solidity >=0.4.22 <0.9.0;
import "./interfaces/i2SV.sol";
import "./interfaces/IERC20.sol";
import "./libs/SafeMath.sol";
/// @title Typical DAIDO vesting contract
/// @author The name of the author
/// @notice Explain to an end user what this does 
/// @dev Explain to a developer any extra details
contract VestCollateral is i2SV {
    using SafeMath for uint256;

    //    Statuses:     0-created, 10- capped , 20 - started, 100 - paused 200 - aborted, 255 - finished

    uint8 constant CREATED = 1;
    uint8 constant OPENED = 5;
    // uint8 constant SOFTCAPPED = 9;
    uint8 constant CAPPED = 10;
    uint8 constant LOANWITHDRAWED = 15;
    uint8 constant STARTED = 20;
    uint8 constant PAUSED = 100;
    uint8 constant VOTING = 150;
    uint8 constant ABORTED = 200;
    uint8 constant REFUNDING = 220;
    uint8 constant FINISHED = 255;


    uint8 public status ; // (1- created, 10- capped , 20 - started, 100 - paused 200 - aborted, 255 - finished )
    uint16 public votesForAbort;    
    bool isConfigured;    
    uint256 public raisedToken1; // sum raised in  token1
    uint256 public raisedToken2;  // sum raised in  token2
    uint256 public refundToken1;  // sum refunded token2 by borrower
    uint256 public withdrawedToken1; // sum withdrawed in  token1
    uint256 public withdrawedRefund1; // sum withdrawed by creditor 
    uint256 public withdrawedToken2;  // sum withdrawed in  token2


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
        if (_vest.vest2.isNative) require( _vest.vest1.token1 == ETHCODE, "Error in config native token");
        
        uint256 amount1;
        uint256 amount2;            
        for (uint8 i=0; i<_rules.length; i++) {
            amount1 += _rules[i].amount1;
            amount2 += _rules[i].amount2;            
            rules.push (_rules[i]); 
        }
        require(amount1 == _vest.vest1.amount1 && amount2 == _vest.vest1.amount2, "Error in vest schedule"  );
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
    {   

        (bool ok, uint256 curVest) =  vested[_token][_recepient].tryAdd(_amount);
        require(ok,  "curVest.tryAdd" );
        if (curVest == _amount) vestors.push(_recepient);                      
        if (_token == vest.vest1.token1) {       
            if (vest.vest1.maxBuy1 > 0) require(curVest <= vest.vest1.maxBuy1, "limit of vesting overquoted for this address" );
            if (vest.vest2.isNative){ // payments with native token                     
                require(_amount == msg.value, "amount must be equal to sent ether");
                if (vest.vest1.minBuy1 > 0)  require(msg.value >= vest.vest1.minBuy1, "amount must be greater minBuy");
            } else {
                if (vest.vest1.minBuy1 > 0) require(_amount >= vest.vest1.minBuy1, "amount must be greater minBuy");
                IERC20(_token).transferFrom(msg.sender, address(this), _amount);
            }
            if (msg.sender != vest.vest2.teamWallet) {
                raisedToken1 = raisedToken1.add( _amount);
                }
            else {
                refundToken1 = refundToken1.add( _amount);
            }
            require(raisedToken1 <= vest.vest1.amount1, "Token1 capped");
        } else if (_token == vest.vest1.token2)  {
            raisedToken2 = raisedToken2.add( _amount);
            require(raisedToken2 <= vest.vest1.amount2, "Token2 capped");
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        }
         
        vested[_token][_recepient] = curVest;
        emit Vested(address(this), _token, msg.sender, _amount);
    } 
    {
/*         if (vest.vest1.softCap1 >0 && //softCap case
            raisedToken1 >= vest.vest1.softCap1 &&             
            ((vest.vest2.isNative && address(this).balance >=  vest.vest1.softCap1) ||
            (!vest.vest2.isNative && IERC20(vest.vest1.token1).balanceOf(address(this)) >= vest.vest1.softCap1))
            ) {
                status = SOFTCAPPED;
                emit VestStatus(address(this),status);

            } */
        

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
        }
    
/*     function startSoftCapped (bool _start )  public {
        require(vested[vest.vest1.token1][msg.sender] > 0 || vested[vest.vest1.token2][msg.sender]>0 , "only vestor can start " );
        if (status >= SOFTCAPPED && _start ) status = STARTED;
        emit VestStatus(address(this),status);

    } 

    function isPaused () public view returns (bool) {
        for (uint8 i=0; i<pauses.length; i++){            
            if (pauses[i].pauseTime > 0 && block.timestamp < pauses[i].pauseTime+vest.vest2.pausePeriod) return true;
        }
        return false;
    } 

*/
    function availableClaimToken1 () public view returns (uint256 avAmount) {
        /// @notice calculates  available amount of token1 for claiming by team
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if ( status == ABORTED || status < LOANWITHDRAWED)  return 0;

        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                uint256 inc = rules[i].amount1.mul(refundToken1).div(vest.vest1.amount1);
                avAmount = avAmount.add(inc);
           }
        }
        avAmount = avAmount.mul(vested[vest.vest1.token1][msg.sender]).div(refundToken1);
        avAmount = avAmount.sub(withdrawed[vest.vest1.token1][msg.sender]);       
    }



    function claimWithdrawToken1(uint256 _amount) public  { 
        /// @notice withdraw _amount of ERC20 or native tokens. In this version claimWithdrawToken1 uses by borrower to withdraw of loan body , for legacy reasons,  and all amount1 sum will withdrawed for one transaction.
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 (not used here, saved for legacy ) desired amount of  claiming token , 

        require(msg.sender == vest.vest2.teamWallet, "just call from teamwallet"); //tbd is necessary or not?
        require(status < LOANWITHDRAWED,  "Loan already  withdrawed");

        uint256 avAmount = _amount;// availableClaimToken1();      
        withdrawed[vest.vest1.token1][vest.vest2.teamWallet] =  withdrawed[vest.vest1.token1][vest.vest2.teamWallet].add(_amount);
        withdrawedToken1 = withdrawedToken1.add(_amount);
        if (vest.vest2.isNative) {
            payable(vest.vest2.teamWallet).transfer(_amount);
        }
        else { 
            IERC20(vest.vest1.token1).transfer(vest.vest2.teamWallet, _amount);            
         }
                
        emit Claimed(address(this), vest.vest1.token1, msg.sender, _amount);
        if (raisedToken1 == withdrawedToken1) status = LOANWITHDRAWED;

    }
 

 /// @notice  

    function availableClaimToken2 () public view returns (uint256 avAmount) {
        /// @notice calculates  available amount of token2 for claiming by vestors
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if ( status == ABORTED || status < LOANWITHDRAWED)  return 0;
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                uint256 inc = rules[i].amount2.mul(raisedToken2).div(vest.vest1.amount2);
                avAmount = avAmount.add(inc); 
                
           }
        }
            avAmount = avAmount.mul(vested[vest.vest1.token1][msg.sender]).div(refundToken1);
            avAmount = avAmount.sub(withdrawed[vest.vest1.token2][msg.sender]);        
    } 

    function claimWithdrawToken2(uint256 _withdrAmount) public override { 
        /// @notice withdraw _withdrAmount of ERC20 or native tokens.  In this version  uses for creditor's side,, for legacy reasons, it try to withdraw to creditor token1 and, in amount is not enough - proportional sum of pledged token2 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _withdrAmount - uint256 desired amount of  claiming token , 

        // require(status >= LOANWITHDRAWED,  "Loan didn't withdrawed");
       
        uint256 avAmount = availableClaimToken1();
        require(avAmount >= _withdrAmount, "Not enough amount for withdraw" );
        uint256 avAmount2 = availableClaimToken2();
        uint256 withdrAmount2 = _withdrAmount.mul(vest.vest1.amount2).div(vest.vest1.amount1);
        if (vest.vest2.isNative ) {
            if (address(this).balance >= _withdrAmount) {
                payable(msg.sender).transfer(_withdrAmount);
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);

           } else {
                _withdrAmount = address(this).balance;
                payable(msg.sender).transfer(_withdrAmount);
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);
                avAmount = _withdrAmount.mul(vest.vest1.amount2).div(vest.vest1.amount1);
                withdrAmount2 = _withdrAmount.sub(avAmount);
                IERC20(vest.vest1.token2).transfer( msg.sender, withdrAmount2);
                emit Claimed(address(this), vest.vest1.token2, msg.sender, withdrAmount2);

           }
        }
        else { 
            if ( IERC20(vest.vest1.token1 ).balanceOf(address(this)) >= _withdrAmount){ 
                IERC20(vest.vest1.token1).transfer(msg.sender, _withdrAmount);            
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);


            } else {
                _withdrAmount =  IERC20(vest.vest1.token1 ).balanceOf(address(this));
                IERC20(vest.vest1.token1).transfer(msg.sender, _withdrAmount);            
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);
                avAmount = _withdrAmount.mul(vest.vest1.amount2).div(vest.vest1.amount1);
                withdrAmount2 = withdrAmount2.sub(avAmount);
                IERC20(vest.vest1.token2).transfer( msg.sender, withdrAmount2);
                emit Claimed(address(this), vest.vest1.token2, msg.sender, withdrAmount2);



            }
        }

        withdrawed[vest.vest1.token1][msg.sender] = withdrawed[vest.vest1.token1][msg.sender].add(_withdrAmount);
        withdrawedRefund1 = withdrawedRefund1.add(_withdrAmount);
        withdrawed[vest.vest1.token2][msg.sender] = withdrawed[vest.vest1.token2][msg.sender].add(withdrAmount2);
        withdrawedToken2 = withdrawedToken2.add(withdrAmount2);

        if (raisedToken1 <= refundToken1 || raisedToken1 <= refundToken1.add(  withdrawedToken2.mul(vest.vest1.amount1).div(vest.vest1.amount2)) ) { 
            status = FINISHED;
            emit Finished (address(this));
        }
        
    }
    

  
     function pauseWithdraw() public override {
        revert ("not used here ");
    } 
    

    function voteAbort(bool _vote) public override {
 /*        if (_vote && isPaused())  {
            require (!voters[msg.sender], "already voted!");
            voters[msg.sender] = true;
            uint shareVote = vested[vest.vest1.token1][msg.sender].mul(100).div(raisedToken1);
            shareVote = shareVote.add( vested[vest.vest1.token2][msg.sender].mul(100).div(raisedToken2));
            votesForAbort = votesForAbort + uint16(shareVote);
            if (status != VOTING) {
                status = VOTING;
                emit VestStatus(address(this), VOTING);
                }
            emit Voting(address(this), shareVote); 
            if (votesForAbort >  vest.vest2.voteShareAbort ) {
                emit VestStatus(address(this),ABORTED);
                status = ABORTED ;
            }
        } else if (!isPaused()) {
            votesForAbort =0;
        }
         */
        revert ("not used here "); //TBD
    }

    function refund () public {
        require(status == FINISHED , "not finished yet, can't refund" );

        //refund token2 
        uint256 avAmount2;
        if (vested[vest.vest1.token2][msg.sender] > 0) { 
            avAmount2 = raisedToken2 - withdrawedToken2; //IERC20(vest.vest1.token2).balanceOf(address(this));
            avAmount2 = avAmount2.mul(vested[vest.vest1.token2][msg.sender]).div(vest.vest1.amount2);
            IERC20(vest.vest1.token2).transfer( msg.sender, avAmount2);
        } else {
            revert ("no token2 invested from this address");
        }
    }

    function getVestedTok1 () public view returns (uint256) {
        return (vested[vest.vest1.token1][msg.sender]);
    }
    function getVestedTok2 () public view returns (uint256) {
        return (vested[vest.vest1.token2][msg.sender]);
    }

    

}
