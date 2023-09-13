import { ethers, Wallet, getDefaultProvider } from "ethers";
//import { wallet } from "../config/constants";
require("dotenv").config();
import { HyperlaneSenderAdapter__factory } from "../typechain-types";
//const rpc = "https://alfajores-forno.celo-testnet.org";
const privateKey = process.env.NEXT_PUBLIC_EVM_PRIVATE_KEY as string;
const wallet = new Wallet(privateKey);
//const rpc = "https://polygon-mumbai.g.alchemy.com/v2/Ksd4J1QVWaOJAJJNbr_nzTcJBJU-6uP3"
//const rpc = "https://forno.celo.org"

const chainNames = ["Avalanche"];
const chainsInfo: any = [];

const chains = [
  {
    name: "Avalanche",
    rpc: "https://rpc.ankr.com/avalanche_fuji",
    mailbox: "0xCC737a94FecaeC165AbCf12dED095BB13F037685",
    defaultIsmInterchainGasPaymaster: "0xF90cB82a76492614D07B82a7658917f3aC811Ac1",
    igp: "0x8f9C3888bFC8a5B25AED115A82eCbb788b196d2a"
  },
  {
    name: "Mumbai",
    rpc: "https://rpc-mumbai.maticvigil.com",
    mailbox: "0xCC737a94FecaeC165AbCf12dED095BB13F037685",
    defaultIsmInterchainGasPaymaster: "0xF90cB82a76492614D07B82a7658917f3aC811Ac1",
    igp: "0x8f9C3888bFC8a5B25AED115A82eCbb788b196d2a"
  }
]

const hyperlaneSenderAdapterAddr = "0x69aaA47081B456690996bCaa85601Ea08aEA8326";

async function main() {
  for (let i = 0; i < chainNames.length; i++) {
    let chainName = chainNames[i];
    let chainInfo = chains.find((chain: any) => {
      if (chain.name === chainName) {
        chainsInfo.push(chain);
        return chain;
      }
    });

    await deployHyperlaneSenderAdapter(chainInfo);
  }
}

async function deployHyperlaneSenderAdapter(chain: any) {
  const provider = getDefaultProvider(chain.rpc);
  const connectedWallet = wallet.connect(provider);

  const senderAdapterFactory = new HyperlaneSenderAdapter__factory(connectedWallet);
  const senderAdapterContract = await senderAdapterFactory.deploy(chain.mailbox, chain.igp, { gasLimit: 8000000 });
  console.log(`Deploying sender adapter Contract for ${chain.name}...`)
  const deployTxReceipt = await senderAdapterContract.deployTransaction.wait();
  console.log(`The hyperlane sender adapter Contract has been deployed for ${chain.name} at this address: ${senderAdapterContract.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});