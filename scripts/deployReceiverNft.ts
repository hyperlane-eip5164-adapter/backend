import { ethers, Wallet, getDefaultProvider } from "ethers";
//import { wallet } from "../config/constants";
require("dotenv").config();
import { ReceiverNFT__factory} from "../typechain-types";
//const rpc = "https://alfajores-forno.celo-testnet.org";
const privateKey = process.env.NEXT_PUBLIC_EVM_PRIVATE_KEY as string;
const wallet = new Wallet(privateKey);
//const rpc = "https://polygon-mumbai.g.alchemy.com/v2/Ksd4J1QVWaOJAJJNbr_nzTcJBJU-6uP3"
//const rpc = "https://forno.celo.org"

const chainNames = ["Mumbai"];
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

const hyperlaneReceiverAdapter = "";
const receiverNftAddr = "0xBa2bAEaEC8B739be77C2F13D9B2a51ba8Eb01166";
const nftName = "Big Token"
const nftSymbol = "BTK"

async function main() {
  for (let i = 0; i < chainNames.length; i++) {
    let chainName = chainNames[i];
    let chainInfo = chains.find((chain: any) => {
      if (chain.name === chainName) {
        chainsInfo.push(chain);
        return chain;
      }
    });

    await deployReceiverNft(chainInfo);
  }
}

async function deployReceiverNft(chain: any) {
  const provider = getDefaultProvider(chain.rpc);
  const connectedWallet = wallet.connect(provider);

  const receiverNftFactory = new ReceiverNFT__factory(connectedWallet);
  const receiverNftContract = await receiverNftFactory.deploy(nftName, nftSymbol, { gasLimit: 8000000 });
  
  console.log(`Deploying sender Nft Contract for ${chain.name}...`)
  const deployTxReceipt = await receiverNftContract.deployTransaction.wait();
  console.log(`The sender Nft Contract has been deployed for ${chain.name} at this address: ${receiverNftContract.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});