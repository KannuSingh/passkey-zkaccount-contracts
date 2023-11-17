import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import { NetworksUserConfig } from "hardhat/types";
import { config as dotenvConfig } from 'dotenv';
import { resolve } from 'path';

dotenvConfig({ path: resolve(__dirname, './.env') });

function getNetworks(): NetworksUserConfig {
  if (process.env.ALCHEMY_API_KEY && process.env.PAYMASTERSIGNER_PRIVATE_KEY) {
      const alchemyApiKey = process.env.ALCHEMY_API_KEY
      const accounts = [`0x${process.env.PAYMASTERSIGNER_PRIVATE_KEY}`]
      return {
          goerli: {
              url: `${process.env.ETHEREUM_URL}`,
              chainId: 5,
              accounts
          },
          arbitrum: {
              url: "https://arb1.arbitrum.io/rpc",
              chainId: 42161,
              accounts
          },
          polygon: {
              url: `https://polygon-mumbai.g.alchemy.com/v2/${alchemyApiKey}`,
              chainId: 80001,
              accounts
          },
          gnosis: {
            url: "https://rpc.gnosischain.com",
            accounts: accounts,
          },
          linea: {
            url: "https://rpc.goerli.linea.build",
            accounts: accounts,
          },
          base: {
            url: 'https://goerli.base.org',
            accounts: accounts,
          },
          optimism: {
            url: `${process.env.OPRIMISM_GOERLI_RPC}`,
            accounts: accounts,
          },

          
      }
  }

  return {}
}
const config: HardhatUserConfig = {
    solidity: {
        compilers: [{
            version: '0.8.21',
            settings: {
            optimizer: { enabled: true, runs: 1000000 },
            viaIR: true
            }
        }],
    },
  networks: {
      hardhat: {
          chainId: 1337
      },
      ...getNetworks()
  },
  
};


export default config;
