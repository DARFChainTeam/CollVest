/* eslint-disable no-undef */
const VestFactory = artifacts.require("VestFactory")



module.exports = async function(deployer,network, addresses) {
  await deployer.deploy(VestFactory);
  
};
