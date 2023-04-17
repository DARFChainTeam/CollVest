pragma solidity >=0.4.22 <0.9.0;
import "./interfaces/i2SVstruct.sol";
import "@openzeppelin/contracts/proxy/Clones.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TokenSaleVesting.sol";


// import "./VestDAIDO.sol";
// import "./VestCollateral.sol";


contract VestFactory is Ownable {
    event NewVesting(address,  i2SVstruct.Vesting, i2SVstruct.Rule[]);
    address constant ETHCODE = address(0x0000000000000000000000000000000000000001);
    address private treasure;
    uint8  fee ; // 5/1000 = 0,5%
    address[] allVestContracts;

    mapping (bytes => address) vestContractsTypes;

    function setContracts (bytes calldata  _name, address _contract) onlyOwner public {
        vestContractsTypes[_name] =  _contract;
    }
    function setTreasureFee ( address _tresr,  uint8 _fee) public onlyOwner {
        treasure = _tresr;
        fee = _fee;
    }

    function deployVest(  address _token, address _recipient, uint256 _amount,
        i2SVstruct.Rule[] calldata _rules,
        i2SVstruct.Vesting calldata _vestConf

        )   public payable  {
            /// @notice Explain to an end user what this does
            /// @dev Explain to a developer any extra details
            /// @param  _token - address of payment token,  "0x01" for native blockchain tokens 
            /// @param  _recipient - address of wallet, who can claim tokens
            /// @param  _amount - sum of vesting payment in wei             
            /// @param _rules - vesting schedule 
            /// @param _vestConf - vesting parameters, see i2SVstruct.sol
            
        i2SVstruct.Vesting memory vest = _vestConf;
        
        TokenSaleVesting vsd = TokenSaleVesting (Clones.clone(vestContractsTypes[_vestConf.vest1.vestType]));
        vsd.initialize (msg.sender,treasure, fee);  
        vsd.setVesting (            
                    vest,                
                    _rules);

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        IERC20(_token).transfer(address(vsd), _amount);

        emit NewVesting(address(vsd), vest, _rules);
        allVestContracts.push(address(vsd));
        
    }
   function  withdrawAll2Treasury () external onlyOwner {
        for (uint i=0; i< allVestContracts.length; i++){
            TokenSaleVesting(allVestContracts[i]).withdraw2Treasury();
        }
    }

}