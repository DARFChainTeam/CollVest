/* eslint-disable no-undef */
const VestFactory = artifacts.require("VestFactory")

const TokenSaleVesting = artifacts.require("TokenSaleVesting")


module.exports = async function(deployer,network, addresses) {
  await deployer.deploy(VestFactory);
  const vestFactory = await VestFactory.deployed();
  
  await deployer.deploy(TokenSaleVesting);  
  const tsv = await TokenSaleVesting.deployed();
  
  await vestFactory.setTreasureFee(addresses[0], 0) //TO BE CHANGED TO REAL 
  await vestFactory.setContracts (web3.utils.asciiToHex("TokenSaleVesting"), tsv.address);


  
};
