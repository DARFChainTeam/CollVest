//SPDX-License-Identifier: GPL

pragma solidity >=0.4.22 <0.9.0;
import "./interfaces/i2SV.sol";
import "./interfaces/IERC20.sol";
import "./libs/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
/// @title Typical DAIDO vesting contract
/// @author The name of the author
/// @notice Explain to an end user what this does 
/// @dev Explain to a developer any extra details
contract VestNFTasCollateral1to1 is i2SV, IERC721Receiver  {
    using SafeMath for uint256;

    //    Statuses:     0-created, 10- capped , 20 - started, 100 - paused 200 - aborted, 255 - finished

    uint8 constant CREATED = 1;
    uint8 constant OPENED = 5;
    uint8 constant BORROWERFUNDED = 7;
    uint8 constant VESTORFUNDED = 8;
    uint8 constant SOFTCAPPED = 9;
    uint8 constant CAPPED = 10;
    uint8 constant LOANWITHDRAWED = 15;
    uint8 constant STARTED = 20;
    uint8 constant PAUSED = 100;
    uint8 constant VOTING = 150;
    uint8 constant ABORTED = 200;
    uint8 constant REFUNDING = 220;
    uint8 constant FINISHED = 255;

    bool isFundedFromBorrower = false;

    uint8 public status ; // (1- created, 10- capped , 20 - started, 100 - paused 200 - aborted, 255 - finished )
    uint16 public votesForAbort;    
    bool isConfigured;    
    uint256 public raisedToken1; // sum raised in  token1
    uint256 public raisedToken2;  // sum raised in  token2
    uint256 public refundToken1;  // sum refunded token2 by borrower
    uint256 public withdrawedToken1; // sum withdrawed in  token1
    uint256 public withdrawedRefund1; // sum withdrawed by creditor 
    uint256 public withdrawedToken2;  // sum withdrawed in  token2
    uint256 lastPaymentDate;


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
        // if (_vest.vest2.isNative) require( _vest.vest1.token1 == ETHCODE, "Error in config native token");
        
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
        if (msg.sender == vest.vest2.borrowerWallet) { 
            if (_token == vest.vest1.token1) {       
                IERC20(vest.vest1.token1).transferFrom(msg.sender, address(this), _amount);

                refundToken1 = refundToken1.add( _amount);
                lastPaymentDate = block.timestamp;

                emit Vested(address(this), _token, msg.sender, _amount);
            }
            else {
                if (IERC721(vest.vest1.token2).ownerOf(vest.vest1.token2Id) != address(this)){///@notice team vests NFT as collateral
                    IERC721(vest.vest1.token2).safeTransferFrom(msg.sender , address(this), vest.vest1.token2Id);
                }
                status = status==VESTORFUNDED?CAPPED:BORROWERFUNDED; ///@notice borrower sent NFT to us
                emit Vested(address(this), vest.vest1.token2, msg.sender, vest.vest1.token2Id);
                }
            }
        else {
            uint256 amount = vest.vest1.amount1;
            (bool ok, uint256 curVest) =  vested[vest.vest1.token1][_recepient].tryAdd(amount);
            require(ok,  "curVest.tryAdd" );
            if (curVest == _amount) vestors.push(_recepient);                      
           
            // if (vest.vest2.isNative){ // payments with native token                     
            //     require(amount == msg.value, "amount must be equal to sent ether");
            // } else {
            IERC20(vest.vest1.token1).transferFrom(msg.sender, address(this), amount);
            // } //isNative
            
            raisedToken1 = raisedToken1.add( amount);
            
            vested[_token][_recepient] = curVest;
            emit Vested(address(this), _token, msg.sender, _amount);
            status = status==BORROWERFUNDED ?CAPPED:VESTORFUNDED;

        }
    }




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
        avAmount = avAmount.sub(refundToken1).mul(vested[vest.vest1.token1][msg.sender]).div(raisedToken1);
        avAmount = avAmount.sub(withdrawed[vest.vest1.token1][msg.sender]);       
    }



    function claimWithdrawToken1(uint256 _amount) public  { 
        /// @notice withdraw _amount of ERC20 or native tokens. In this version claimWithdrawToken1 uses by borrower to withdraw of loan body , for legacy reasons,  and all amount1 sum will withdrawed for one transaction.
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 (not used here, saved for legacy ) desired amount of  claiming token , in this version VestNFTasCollateral1to1  don't used because of borrower have to claim al sum at once.

        require(msg.sender == vest.vest2.borrowerWallet, "just call from borrowerWallet"); //tbd is necessary or not?
        require(status < LOANWITHDRAWED,  "Loan already  withdrawed");

        uint256 avAmount = vest.vest1.amount1;// availableClaimToken1();      
        withdrawed[vest.vest1.token1][vest.vest2.borrowerWallet] =  withdrawed[vest.vest1.token1][vest.vest2.borrowerWallet].add(avAmount);
        withdrawedToken1 = withdrawedToken1.add(avAmount);
        // if (vest.vest2.isNative) {
        //     payable(vest.vest2.borrowerWallet).transfer(avAmount);
        // }
        // else { 
        IERC20(vest.vest1.token1).transfer(vest.vest2.borrowerWallet, avAmount);            
        //  } //isNative
                
        emit Claimed(address(this), vest.vest1.token1, msg.sender, avAmount);
        //if (raisedToken1 == withdrawedToken1) 
        status = LOANWITHDRAWED;

    }
 

    function calcAmountandPenalty () public view returns (uint256 avAmount, uint256 penalty) {
        uint lastPaymentAmount;

        if ( status == ABORTED || status < LOANWITHDRAWED)  return (0, 0);
            for (uint8 i=0; i<rules.length; i++) { 
                if (rules[i].claimTime <= block.timestamp){                
                    avAmount = avAmount.add( rules[i].amount1); 
                    lastPaymentAmount = rules[i].amount1;
            }
            }
            avAmount = avAmount.sub(withdrawedRefund1);
            if (avAmount > lastPaymentAmount) {
                // penalty here
                penalty = vest.vest2.penalty; 
            }
    }

    function availableClaimToken2 () public view returns (uint256 avAmount) {
        /// @notice calculates  available amount of token2 for claiming by vestors
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
     
        (uint256 avAmountin, uint256 penalty) = calcAmountandPenalty();
        avAmount = avAmountin.add( penalty);
        // avAmount = avAmount.mul(vested[vest.vest1.token1][msg.sender]).div(raisedToken1);
        
        avAmount = avAmount.sub(withdrawed[vest.vest1.token2][msg.sender]);        

    } 

    function claimWithdrawToken2(uint256 _withdrAmount) public override { 
        /// @notice withdraw _withdrAmount of ERC20 or native tokens.  In this version  uses for creditor's side, for legacy reasons, it try to withdraw to creditor token1 and, in amount is not enough - proportional sum of pledged token2 
  
        /// @param _withdrAmount - uint256 desired amount of  claiming token , 

        // require(status >= LOANWITHDRAWED,  "Loan didn't withdrawed");
       
        // uint256 avAmount = availableClaimToken1();
        (uint256 avAmount, uint256 penalty) = calcAmountandPenalty();
        require(avAmount >= _withdrAmount, "No available amount for withdraw" );


 /*         if (vest.vest2.isNative ) {
             if (address(this).balance >= _withdrAmount) {
                 payable(msg.sender).transfer(_withdrAmount);
                 emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);

            } else {
            _withdrAmount = address(this).balance;
            payable(msg.sender).transfer(_withdrAmount);
            emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);
            if (penalty > 0 && block.timestamp - lastPaymentDate > vest.vest2.penaltyPeriod ) { ///@notice creditor get NFT pledge 
            
                IERC721(vest.vest1.token2).transferFrom(address(this), msg.sender, vest.vest1.token2Id);
                emit Claimed(address(this), vest.vest1.token2, msg.sender, vest.vest1.token2Id);
                }
            } 
         } 
        else { */ 
            if ( IERC20(vest.vest1.token1 ).balanceOf(address(this)) >= _withdrAmount){ 
                IERC20(vest.vest1.token1).transfer(msg.sender, _withdrAmount);            
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);

            } else {
                _withdrAmount =  IERC20(vest.vest1.token1 ).balanceOf(address(this));
                IERC20(vest.vest1.token1).transfer(msg.sender, _withdrAmount);            
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);
                if (penalty > 0 && block.timestamp - lastPaymentDate > vest.vest2.penaltyPeriod ) { ///@notice creditor get NFT pledge 
                    IERC721(vest.vest1.token2).transferFrom(address(this), msg.sender, vest.vest1.token2Id);
                    emit Claimed(address(this), vest.vest1.token2, msg.sender, vest.vest1.token2Id);
                }
            }
      //  } //isNative

        withdrawed[vest.vest1.token1][msg.sender] = withdrawed[vest.vest1.token1][msg.sender].add(_withdrAmount);
        withdrawedRefund1 = withdrawedRefund1.add(_withdrAmount);
        // withdrawed[vest.vest1.token2][msg.sender] = withdrawed[vest.vest1.token2][msg.sender].add(withdrAmount2);
        // withdrawedToken2 = withdrawedToken2.add(withdrAmount2);

        if (raisedToken1 <= refundToken1){ 
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
        /// @notice returning NFT to borrower if all ok
        
        require(status == FINISHED , "not finished yet, can't refund" );
          IERC721(vest.vest1.token2).safeTransferFrom( address(this), vest.vest2.borrowerWallet,  vest.vest1.token2Id);

    }

    function getVestedTok1 () public view returns (uint256) {
        return (vested[vest.vest1.token1][msg.sender]);
    }
    function getVestedTok2 () public view returns (uint256) {
        return (IERC721(vest.vest1.token2).balanceOf(address(this)));
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    )  external returns (bytes4) {
        return this.onERC721Received.selector;
    }

}
