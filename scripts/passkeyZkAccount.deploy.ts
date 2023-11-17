const fs = require('fs');
import { ethers } from "hardhat";
import { EntryPoint__factory, PasskeyZkAccountFactory__factory } from "../typechain-types";

async function main() {
  const [deployerWallet] = await ethers.getSigners();
  console.log(`PasskeyZkAccount Factory Deployer : ${deployerWallet.address}`)

  const entryPointAddress = '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789'
  // const entryPointArtifact = (await ethers.getContractFactory("EntryPoint")) 
	const entryPoint = EntryPoint__factory.connect(entryPointAddress)
  
  console.log("Deploying SessionVerifier")

  const zkSessionAccountVerifierArtifact = await ethers.getContractFactory("SimpleZkSessionAccountVerifier");
  // const zkSessionAccountVerifier = await zkSessionAccountVerifierArtifact.deploy({ gasPrice: 10e10  });
  const zkSessionAccountVerifier = await zkSessionAccountVerifierArtifact.attach("0xCb4AcACe7De55D13e5979C4Ad4205f1fc818af1f");
  console.log(`SimpleZkAccountVerifier contract address: ${await zkSessionAccountVerifier.getAddress()} \n`)

  console.log("Deploying PasskeyZkAccountFactory")
  const passkeyZkAccountFactoryArtifacts = await ethers.getContractFactory("PasskeyZkAccountFactory");
  const passkeyZkAccountFactory = await passkeyZkAccountFactoryArtifacts.deploy(entryPointAddress,await zkSessionAccountVerifier.getAddress(),{ gasPrice: 10e10  })
  // const passkeyZkAccountFactory = await PasskeyZkAccountFactory__factory.connect("0x00022c2Ff80cfAA0E5eC703B0e163981a2B6AE30",deployerWallet)
  
  console.log(`PasskeyZkAccountFactory contract address: ${await passkeyZkAccountFactory.getAddress()} \n`)

  const passkeyId = ethers.encodeBytes32String("passkey1")
  const pubKeyX = "58640826831948292943175879036424064544903064261202148179375876287662359819382"
  const pubKeyY = "35488965690999393053537793469671322029993511314321148723800137444087697436355"

  const deployerSCWAddress = await passkeyZkAccountFactory.getCounterfactualAddress(passkeyId,pubKeyX,pubKeyY,0)
  console.log(`Deployer SCW address: ${deployerSCWAddress}`)
  
  
  // client data Json :
  // {type: 'webauthn.get', challenge: 'NTo-1aBEGRnxxjmkaTHehyrDNX3izlqi1owmOd9UGJ0', origin: 'http://localhost:3001', crossOrigin: false}
  // Authenticator data:
  //
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
