//SPDX-License-Identifier: GPL

pragma solidity >=0.4.22 <0.9.0;
import "./DoubleSideVesting.sol";
import "./interfaces/IERC20.sol";
import "./libs/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
/// @title Typical NFT Collateral vesting contract
/// @author @Stanta
/// @notice Party1 (Lender) has (for example) stablecoins and wants to lend them to Party2 (Borrower) against the NFT. The borrower repays the loan in regular payments
/// @dev Explain to a developer any extra details
contract VestNFTasCollateral1to1 is DoubleSideVesting, IERC721Receiver  { 
    using SafeMath for uint256;

    bool isFundedFromBorrower = false;
    uint256 public  refundToken1;
    uint256 public withdrawedRefund1; // sum withdrawed by creditor 
    uint256 public lastPaymentDate;


        
    function putVesting (address _token, address _recepient, uint256 _amount) public override  payable {
    /// @notice accepts vesting payments from both sides 
    /// @dev divides for native and ERC20 flows
    /// @param  _token - address of payment token,  "0x01" for native blockchain tokens 
    /// @param  _recepient - address of wallet, who can claim tokens
    /// @param  _amount - sum of vesting payment in wei 
        require(vest.vest2.capFinishTime == 0 || vest.vest2.capFinishTime < block.timestamp, "time for vest out" );
        if (msg.sender == vest.vest2.borrowerWallet) { 
            
                IERC20(vest.vest1.token1).transferFrom(msg.sender, address(this), _amount);

                refundToken1 = refundToken1.add( _amount);
                lastPaymentDate = block.timestamp;

                emit Vested(address(this), _token, msg.sender, _amount);
            }
        else if (_token == vest.vest1.token2)  {
                ///@notice BORROWER vests NFT as collateral
                IERC721(vest.vest1.token2).safeTransferFrom(msg.sender , address(this), vest.vest1.token2Id);
                
                status = status==VESTORFUNDED?CAPPED:BORROWERFUNDED; ///@notice borrower sent NFT to us
                emit Vested(address(this), vest.vest1.token2, _recepient, vest.vest1.token2Id);
                
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
            emit Vested(address(this), _token, _recepient, _amount);
            status = status==BORROWERFUNDED ?CAPPED:VESTORFUNDED;

        }
    }




    function availableClaimToken1 () public view override returns (uint256 avAmount) {
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



    function claimWithdrawToken1(uint256 _amount) public override nonReentrant  { 
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
            IERC20(vest.vest1.token1).transfer(vest.vest2.borrowerWallet, _amount.sub( _amount.mul(fee).div(1000)));            
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

    function availableClaimToken2 () public view override returns (uint256 avAmount) {
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

    function claimWithdrawToken2(uint256 _withdrAmount) public  nonReentrant override  { 
        /// @notice withdraw _withdrAmount of ERC20 or native tokens.  In this version  uses for creditor's side, for legacy reasons, it try to withdraw to creditor token1 and, in amount is not enough - proportional sum of pledged token2 
        /// @param _withdrAmount - uint256 desired amount of  claiming token , 

        // require(status >= LOANWITHDRAWED,  "Loan didn't withdrawed");

        (uint256 avAmount, uint256 penalty) = calcAmountandPenalty();
        require(avAmount >= _withdrAmount, "No available amount for withdraw" );
            if (IERC20(vest.vest1.token1).balanceOf(address(this)) >= _withdrAmount){ 
                IERC20(vest.vest1.token1).transfer(msg.sender, _withdrAmount.sub( _withdrAmount.mul(fee).div(1000)));            
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);
            } else {
                _withdrAmount =  IERC20(vest.vest1.token1 ).balanceOf(address(this));
                IERC20(vest.vest1.token1).transfer(msg.sender, _withdrAmount.sub( _withdrAmount.mul(fee).div(1000)));            
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);
                if (penalty > 0 && block.timestamp - lastPaymentDate > vest.vest2.penaltyPeriod ) { ///@notice creditor get NFT pledge 
                    IERC721(vest.vest1.token2).transferFrom(address(this), msg.sender, vest.vest1.token2Id);
                    emit Claimed(address(this), vest.vest1.token2, msg.sender, vest.vest1.token2Id);
                }
            }

        withdrawed[vest.vest1.token1][msg.sender] = withdrawed[vest.vest1.token1][msg.sender].add(_withdrAmount);
        withdrawedRefund1 = withdrawedRefund1.add(_withdrAmount);
        // withdrawed[vest.vest1.token2][msg.sender] = withdrawed[vest.vest1.token2][msg.sender].add(withdrAmount2);
        // withdrawedToken2 = withdrawedToken2.add(withdrAmount2);

        if (raisedToken1 <= refundToken1){ 
            status = FINISHED;
            emit Finished (address(this));
        }
        
    }
    

    function pauseWithdraw(string calldata _reason) public override {
        revert ("not used here ");
    } 
    

    function voteAbort(bool _vote) public override {

        revert ("not used here "); //TBD
    }

    function refund () public override {
        /// @notice returning NFT to borrower if all ok
        
        require(status == FINISHED , "not finished yet, can't refund" );
          IERC721(vest.vest1.token2).safeTransferFrom( address(this), vest.vest2.borrowerWallet,  vest.vest1.token2Id);

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
