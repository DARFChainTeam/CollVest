const Token1 = artifacts.require("Token1");
const Token2 = artifacts.require("Token2");



module.exports = async function(deployer,network, addresses) {

  if (network == 'development'){  
    await deployer.deploy(Token1);
    await deployer.deploy(Token2);
  }
};
