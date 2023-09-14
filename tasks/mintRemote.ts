import { ethers, Wallet, getDefaultProvider, BigNumber, utils } from "ethers";
//import { wallet } from "../config/constants";
require("dotenv").config();
import { HyperlaneSenderAdapter__factory, HyperlaneReceiverAdapter__factory, ReceiverNFT__factory, SenderNFT__factory } from "../typechain-types";
const privateKey = process.env.NEXT_PUBLIC_EVM_PRIVATE_KEY as string;
const wallet = new Wallet(privateKey);
//const rpc = "https://polygon-mumbai.g.alchemy.com/v2/Ksd4J1QVWaOJAJJNbr_nzTcJBJU-6uP3";
const dummyAddress = "0x0000000000000000000000000000000000000000"; // Replace with a valid Ethereum address
const dummyData = "0x"; // Replace with any data if required

const tokenURI = "bafkreihfweuclvhaozl7q6zsjjyrkh262vlbzqyd5m3lijrnjefh6pxy3i";

const hyperlaneSenderAdapterAddr = "0xdCecfC53FF1257D4f8482Bc66EA206B03e064F56";
const senderNftAddr = "0x7C1dd7B95108B9C4C4d71BeaAf0485698beCf1A9";
const hyperlaneReceiverAdapterAddr = "0xAe01a07143656121d34496a7bcFf5129eCB32397";
const receiverNftAddr = "0x296cbAF3b5A78C21FA0dF6Ac2473C7242E8Cec8e";

const chainNames = ["Avalanche"];
const chainsInfo: any = [];
const chains = [
    {
        name: "Avalanche",
        rpc: "https://rpc.ankr.com/avalanche_fuji",
        mailbox: "0xCC737a94FecaeC165AbCf12dED095BB13F037685",
        multiSigIsm: "0xD713Db664509bd057aC2b378F4B65Db468F634A5",
        igp: "0x8f9C3888bFC8a5B25AED115A82eCbb788b196d2a",
        chainId: "",
        domainId: ""
    },
    {
        name: "Mumbai",
        rpc: "https://rpc-mumbai.maticvigil.com",
        mailbox: "0xCC737a94FecaeC165AbCf12dED095BB13F037685",
        multiSigIsm: "0xd71f1A64659beC0781b2aa21bc7a72F7290F6Bf3",
        igp: "0x8f9C3888bFC8a5B25AED115A82eCbb788b196d2a",
        chainId: "",
        domainId: ""
    }
]

async function main() {
    for (let i = 0; i < chainNames.length; i++) {
        let chainName = chainNames[i];
        let chainInfo = chains.find((chain: any) => {
            if (chain.name === chainName) {
                chainsInfo.push(chain);
                return chain;
            }
        });

        await mintRemote(chainInfo);
        
        //await setupSenderAdapter(chainInfo);
        //await setupReceiverAdapter(chainInfo);
        //await setupReceiverNft(chainInfo);
    }
}


async function setupSenderAdapter(chain: any) {
    const provider = getDefaultProvider(chain.rpc);
    const connectedWallet = wallet.connect(provider);

    const hyperlaneSenderAdapterFactory = new HyperlaneSenderAdapter__factory(connectedWallet);
    const senderAdapterContract = hyperlaneSenderAdapterFactory.attach(hyperlaneSenderAdapterAddr);

    try {
        const tx = await senderAdapterContract.updateReceiverAdapter([80001], [hyperlaneReceiverAdapterAddr]);
        tx.wait();
        console.log("UpdateReceiverAdapter tx successful");

        const tx2 = await senderAdapterContract.updateDestinationDomainIds([80001], [80001]);
        tx2.wait();
        console.log("updateDestinationDomainIds tx successful")
        //    let tx = await senderAdapterContract.getMessageFee(80001, dummyAddress, dummyData);
        //    console.log(tx.toString())

    } catch (error) {
        console.log(`[source] senderAdapterContract.updateReceiverAdapter ERROR!`);
        console.log(`[source]`, error);

    }
}

async function setupReceiverAdapter(chain: any) {
    const provider = getDefaultProvider(chain.rpc);
    const connectedWallet = wallet.connect(provider);

    const hyperlaneReceiverAdapterFactory = new HyperlaneReceiverAdapter__factory(connectedWallet);
    const receiverAdapterContract = hyperlaneReceiverAdapterFactory.attach(hyperlaneReceiverAdapterAddr);

    try {

        //const tx = await receiverAdapterContract.interchainSecurityModule();
        const tx = await receiverAdapterContract.updateSenderAdapter([43113], [hyperlaneSenderAdapterAddr]);
        tx.wait();
        console.log("updateSenderAdapter tx successful")
       
        const tx2 = await receiverAdapterContract.setIsm(chain.multiSigIsm);
        tx2.wait();
        console.log("setIsm tx successful");

    } catch (error) {
        console.log(`[source] receiverAdapterContract.updateSenderAdapter ERROR!`);
        console.log(`[source]`, error);

    }
}


async function setupReceiverNft(chain: any) {
    const provider = getDefaultProvider(chain.rpc);
    const connectedWallet = wallet.connect(provider);

    const receiverNftFactory = new ReceiverNFT__factory(connectedWallet);
    const receiverNftContract = receiverNftFactory.attach(receiverNftAddr);

    try {
        const tx = await receiverNftContract.addTrustedAdapter(hyperlaneReceiverAdapterAddr);
        const txReceipt = tx.wait();
        console.log("addTrustedAdapter tx successful");

    } catch (error) {
        console.log(`[source] receiverAdapterContract.updateSenderAdapter ERROR!`);
        console.log(`[source]`, error);

    }
}


async function mintRemote(chain: any) {
    const provider = getDefaultProvider(chain.rpc);
    const connectedWallet = wallet.connect(provider);

    const senderNftFactory = new SenderNFT__factory(connectedWallet);
    const senderNftContract = senderNftFactory.attach(senderNftAddr);

    const hyperlaneSenderAdapterFactory = new HyperlaneSenderAdapter__factory(connectedWallet);
    const senderAdapterContract = hyperlaneSenderAdapterFactory.attach(hyperlaneSenderAdapterAddr);

    try {

        // const tx = await senderNftContract.mintLocal(tokenURI);
        // await tx.wait();
        // console.log("Token id 2 minted");

        let fee = await senderAdapterContract.getMessageFee(80001, dummyAddress, dummyData);
        //console.log(fee.toString())

        //const feeBigNum: BigNumber =  ethers.BigNumber.from("29250000000000000");

        const multipliedValue = fee.mul(11).div(10)
        console.log(`buffered value = ${multipliedValue.toString()}`)

        //const tx = await senderNftContract.mintRemote(80001, receiverNftAddr, tokenURI, {value: multipliedValue});
        const tx = await senderNftContract.transferRemote(80001, 2, receiverNftAddr, {gasLimit: 9000000, value: multipliedValue});
        const txReceipt = await tx.wait();
        console.log(`Transaction successful and could be seen at this transaction hash: ${txReceipt.transactionHash}`);

    } catch (error) {
        console.log(`[source] receiverAdapterContract.updateSenderAdapter ERROR!`);
        console.log(`[source]`, error);

    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});


