# cBTC Price Prediction Pool Integration Guide

## Contract Integration into Your dApp

### Contract Address
MockFeedRegistry: 0x767dad5e959f206fb6671cc3419497c1f0bb8329

BTCPriceBetting: 0xfb3f44c8125c37f5746bdce8d6149ab9676b140d

### Contract ABI
```
[
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "base",
                "type": "address"
            },
            {
                "internalType": "address",
                "name": "quote",
                "type": "address"
            },
            {
                "internalType": "int256",
                "name": "price",
                "type": "int256"
            }
        ],
        "name": "setMockPrice",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "base",
                "type": "address"
            },
            {
                "internalType": "address",
                "name": "quote",
                "type": "address"
            }
        ],
        "name": "latestRoundData",
        "outputs": [
            {
                "internalType": "uint80",
                "name": "roundId",
                "type": "uint80"
            },
            {
                "internalType": "int256",
                "name": "answer",
                "type": "int256"
            },
            {
                "internalType": "uint256",
                "name": "startedAt",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "updatedAt",
                "type": "uint256"
            },
            {
                "internalType": "uint80",
                "name": "answeredInRound",
                "type": "uint80"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    }
]
```




## Prerequisites

- **Basic Knowledge of Solidity and Smart Contract Development**
- **Access to a Citrea Testnet Node** (e.g., `https://rpc.testnet.citrea.xyz`)
- **Development Tools** such as Truffle, Hardhat, or similar frameworks
- **cBTC Tokens for Testing**

## Setup Steps

### 1. Connect to Citrea Testnet Node

Configure your Web3 provider to connect to the Citrea Testnet node.

```javascript
const Web3 = require('web3');
const web3 = new Web3('https://rpc.testnet.citrea.xyz');
```

### 2. Create a Contract Instance

Use the contract's ABI and address to create an instance in your application.

```javascript
const contractABI = [ /* ABI JSON */ ];
const contractAddress = '0xYourContractAddress';
const contract = new web3.eth.Contract(contractABI, contractAddress);
```

### 3. Main Functions to Integrate

#### Create a Bet

```javascript
async function createBet(PPP, NNN, fromAddress, privateKey) {
    const PPPNNN = PPP * 1000 + NNN;
    const value = PPPNNN; // In satoshis (considering 8 decimals)
    
    const tx = {
        from: fromAddress,
        to: contractAddress,
        value: web3.utils.toWei(value.toString(), 'wei'),
        gas: 2000000,
    };

    const signedTx = await web3.eth.accounts.signTransaction(tx, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
    console.log('Bet Created:', receipt.transactionHash);
}
```

#### Place a Bet

```javascript
async function placeBet(option, betId, amount, fromAddress, privateKey) {
    const PPPNNN = option * 1000 + betId;
    const value = web3.utils.toWei(amount.toString(), 'ether') + PPPNNN.toString();

    const tx = {
        from: fromAddress,
        to: contractAddress,
        value: value,
        gas: 2000000,
    };

    const signedTx = await web3.eth.accounts.signTransaction(tx, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
    console.log('Bet Placed:', receipt.transactionHash);
}
```

#### Settle a Bet

```javascript
async function settleBet(betId, fromAddress, privateKey) {
    const tx = {
        from: fromAddress,
        to: contractAddress,
        data: contract.methods.settleBet(betId).encodeABI(),
        gas: 2000000,
    };

    const signedTx = await web3.eth.accounts.signTransaction(tx, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
    console.log('Bet Settled:', receipt.transactionHash);
}
```

#### Claim a Reward

```javascript
async function claimReward(betId, fromAddress, privateKey) {
    const tx = {
        from: fromAddress,
        to: contractAddress,
        data: contract.methods.claimReward(betId).encodeABI(),
        gas: 2000000,
    };

    const signedTx = await web3.eth.accounts.signTransaction(tx, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
    console.log('Reward Claimed:', receipt.transactionHash);
}
```

#### Get Bet Information

```javascript
async function getBetInfo(betId) {
    const betInfo = await contract.methods.getBetInfo(betId).call();
    console.log('Bet Info:', betInfo);
}
```

#### List Active Bets

```javascript
async function getActiveBetIds() {
    const activeBets = await contract.methods.getActiveBetIds().call();
    console.log('Active Bets:', activeBets);
}
```

### License
#### This project is licensed under the MIT License.






