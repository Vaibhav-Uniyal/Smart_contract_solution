const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying TradeEscrow contract...");

  // Get the ContractFactory
  const TradeEscrow = await ethers.getContractFactory("TradeEscrow");

  // Deploy the contract
  const tradeEscrow = await TradeEscrow.deploy();

  // Wait for deployment to complete
  await tradeEscrow.waitForDeployment();

  const contractAddress = await tradeEscrow.getAddress();
  console.log("TradeEscrow deployed to:", contractAddress);

  // Get network information
  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name);
  console.log("Chain ID:", network.chainId);

  // Get deployer information
  const [deployer] = await ethers.getSigners();
  console.log("Deployed by:", deployer.address);
  console.log("Deployer balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  return tradeEscrow;
}

// Run the deployment
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("Deployment failed:");
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;
