/* eslint-disable no-undef */
const VestFactory = artifacts.require("VestFactory")
const VestCollateral = artifacts.require("VestCollateral")


module.exports = async function(deployer,network, addresses) {
  await deployer.deploy(VestFactory);
  await deployer.deploy(VestCollateral);

  
};
