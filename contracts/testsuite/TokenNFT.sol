// SPDX-License-Identifier: MIT
pragma solidity >=0.4.25 <0.9.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


// This is just a simple example of a coin-like contract.
// It is not standards compatible and cannot be expected to talk to other
// coin/token contracts. If you want to create a standards-compliant
// token, see: https://github.com/ConsenSys/Tokens. Cheers!

contract TokenNFT is ERC721 {

	constructor() ERC721("NFT4collateraltest", "NFTclt")  {
	        super._mint(msg.sender, 1 );

	}


}
