pragma solidity >=0.4.22 <0.9.0;
import "./interfaces/i2SV.sol";
import "@openzeppelin/contracts/proxy/Clones.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC20.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// import "./VestDAIDO.sol";
// import "./VestCollateral.sol";


contract VestFactory is Ownable, IERC721Receiver {
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

    function deployVest(  address _token, address _recepient, uint256 _amount,
        i2SVstruct.Rule[] calldata _rules,
        i2SVstruct.Vesting calldata _vestConf

        )   public payable  {
            /// @notice Explain to an end user what this does
            /// @dev Explain to a developer any extra details
            /// @param  _token - address of payment token,  "0x01" for native blockchain tokens 
            /// @param  _recepient - address of wallet, who can claim tokens
            /// @param  _amount - sum of vesting payment in wei             
            /// @param _rules - vesting schedule 
            /// @param _vestConf - vesting parameters, see i2SVstruct.sol
            
        i2SVstruct.Vesting memory vest = _vestConf;
        
        i2SV vsd = i2SV (Clones.clone(vestContractsTypes[_vestConf.vest1.vestType]));
        vsd.initialize (msg.sender,treasure, fee);  
        vsd.setVesting (            
                    vest,                
                    _rules);

            if (_vestConf.vest2.isNative && msg.value == _amount ) {
                vest.vest1.token1 = ETHCODE;
                vsd.putVesting {value: msg.value} ( _token,  _recepient,  _amount); 
            
            } else if (vest.vest1.token2Id > 0 ) {
                
                IERC721(vest.vest1.token2).transferFrom(msg.sender , address(this), vest.vest1.token2Id);
                
                IERC721(vest.vest1.token2).approve(address(vsd), vest.vest1.token2Id);
                
                vsd.putVesting ( _token,  _recepient,  vest.vest1.token2Id);                 
            } 
            else 
            {
                IERC20(_token).transferFrom(msg.sender, address(this), _amount);
                IERC20(_token).approve(address(vsd), _amount);
                vsd.putVesting ( _token,  _recepient,  _amount); 

            }

            emit NewVesting(address(vsd), vest, _rules);
            allVestContracts.push(address(vsd));
        
    }

        
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    )  external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function  withdrawAll2Treasury () external onlyOwner {
        for (uint i=0; i< allVestContracts.length; i++){
            i2SV(allVestContracts[i]).withdraw2Treasury();
        }
    }
}