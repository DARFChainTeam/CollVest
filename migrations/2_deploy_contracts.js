/* eslint-disable no-undef */
const VestFactory = artifacts.require("VestFactory")
const VestDAIDO = artifacts.require("VestDAIDO")
const VestCollateral = artifacts.require("VestCollateral")
const VestCollateralNFT121 = artifacts.require("VestNFTasCollateral1to1")



module.exports = async function(deployer,network, addresses) {
  await deployer.deploy(VestFactory);
  const vestFactory = await VestFactory.deployed();
  
  await deployer.deploy(VestDAIDO);
  const vestDAIDO = await VestDAIDO.deployed();
  
  await deployer.deploy(VestCollateral);
  const vestCollateral = await VestCollateral.deployed();

  await deployer.deploy(VestCollateralNFT121);
  const vestCollateralNFT121 = await VestCollateralNFT121.deployed();
  await vestFactory.setTreasureFee(addresses[0], 0) //TO BE CHANGED TO REAL 
  await vestFactory.setContracts (web3.utils.asciiToHex("DAIDO"), vestDAIDO.address);
  await vestFactory.setContracts (web3.utils.asciiToHex("Collateral"), vestCollateral.address);
  await vestFactory.setContracts (web3.utils.asciiToHex("NFTCollateral121"), vestCollateralNFT121.address);

  
};
