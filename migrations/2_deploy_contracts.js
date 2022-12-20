/* eslint-disable no-undef */
const VestFactory = artifacts.require("VestFactory")
const VestDAIDO = artifacts.require("VestDAIDO")
const VestCollateral = artifacts.require("VestCollateral")


module.exports = async function(deployer,network, addresses) {
  await deployer.deploy(VestFactory);
  const vestFactory = await VestFactory.deployed();
  await deployer.deploy(VestDAIDO);
  const vestDAIDO = await VestDAIDO.deployed();

  await deployer.deploy(VestCollateral);
  const vestCollateral = await VestCollateral.deployed();

  await vestFactory.setContracts (web3.utils.asciiToHex("DAIDO    "), vestDAIDO.address);
  await vestFactory.setContracts (web3.utils.asciiToHex("Collateral"), vestCollateral.address);

  
};
