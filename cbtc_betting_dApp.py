# cbtc_betting.py

import os
import json
import sys
import getpass
from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_defunct

CONFIG_FILE = 'wallet_config.json'
CONTRACT_ABI_FILE = 'contract_abi.json'

# Contract Address
CONTRACT_ADDRESS = '0xTheContractAddress'

def create_wallet():
    print("Creating a new wallet...")
    password = getpass.getpass("Set a password: ")
    account = Account.create()
    encrypted = Account.encrypt(account.privateKey, password)
    with open(CONFIG_FILE, 'w') as f:
        json.dump(encrypted, f)
    print(f"¡Successfully created!\nAddress: {account.address}")
    print("Please send some cBTC to this address to use the dApp.")

def load_wallet():
    if not os.path.exists(CONFIG_FILE):
        print("Wallet not found, let's create a new one!.")
        create_wallet()
        sys.exit()
    password = getpass.getpass("Set a password: ")
    with open(CONFIG_FILE, 'r') as f:
        encrypted = json.load(f)
    try:
        private_key = Account.decrypt(encrypted, password)
        account = Account.from_key(private_key)
        return account
    except ValueError:
        print("Wrong password. Try again.")
        sys.exit()

def connect_to_citrea():
    rpc_url = 'https://rpc.testnet.citrea.xyz'
    web3 = Web3(Web3.HTTPProvider(rpc_url))
    if not web3.isConnected():
        print("Unable to connect to Citrea Testnet. Verify your connection status.")
        sys.exit()
    return web3

def load_contract(web3):
    if not os.path.exists(CONTRACT_ABI_FILE):
        print(f"Contract ABI not found: {CONTRACT_ABI_FILE}")
        sys.exit()
    with open(CONTRACT_ABI_FILE, 'r') as f:
        abi = json.load(f)
    contract = web3.eth.contract(address=Web3.toChecksumAddress(CONTRACT_ADDRESS), abi=abi)
    return contract

def main():
    print("=== Wlcome to cBTC Price Prediction Pool ===")
    account = load_wallet()
    web3 = connect_to_citrea()
    contract = load_contract(web3)
    print(f"\nYour wallet address: {account.address}")
    balance = web3.eth.get_balance(account.address)
    print(f"cBTC available: {web3.fromWei(balance, 'ether')} cBTC")

    while True:
        print("\n--- Home Menu ---")
        print("1. Create a new Bet")
        print("2. Join an existing Bet")
        print("3. Settle a Bet")
        print("4. Claim Reward")
        print("5. Get some Bet information")
        print("6. List of active Bets")
        print("7. Exit")

        choice = input("Please choose an option: ")

        if choice == '1':
            create_new_bet(web3, account, contract)
        elif choice == '2':
            place_bet(web3, account, contract)
        elif choice == '3':
            settle_bet(web3, account, contract)
        elif choice == '4':
            claim_reward(web3, account, contract)
        elif choice == '5':
            get_bet_info(contract)
        elif choice == '6':
            list_active_bets(contract)
        elif choice == '7':
            print("See you anon!")
            break
        else:
            print("Invalid option, please choose a valid option.")

def create_new_bet(web3, account, contract):
    try:
        PPP = int(input("Configure max possible variation for this Bet in percentage PPP (1-999): "))
        NNN = int(input("Configure the Bet ID, should be a new one, check availability before (0-999): "))
        if PPP < 1 or PPP > 999 or NNN < 0 or NNN > 999:
            print("PPP or NNN out of range. Try again.")
            return

        PPPNNN = PPP * 1000 + NNN
        value = PPPNNN  # In satoshis (8 decimals)

        tx = contract.functions.createBet().buildTransaction({
            'from': account.address,
            'value': value,
            'nonce': web3.eth.get_transaction_count(account.address),
            'gas': 2000000,
            'gasPrice': web3.toWei('5', 'gwei')
        })

        signed_tx = web3.eth.account.sign_transaction(tx, account.privateKey)
        tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f"Transaction sent: {web3.toHex(tx_hash)}")
        print("Awaiting the transaction confirmation...")
        receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
        if receipt.status:
            print("Bet was successfully created!")
        else:
            print("Transaction failed. Try again.")
    except Exception as e:
        print(f"Error creating the bet: {e}")

def place_bet(web3, account, contract):
    try:
        betId = int(input("Insert the Bet ID NNN (0-999): "))
        option = int(input("Insert the value option (0-999): "))
        amount = float(input("Amount to bet (in cBTC): "))
        if betId < 0 or betId > 999 or option < 0 or option > 999 or amount <= 0:
            print("Parameters are out of range. Try again!")
            return

        betInfo = contract.functions.getBetInfo(betId).call()
        if option > betInfo['variation']:
            print(f"PPP should be <= {betInfo['variation']} for this Bet.")
            return

        amount_wei = web3.toWei(amount, 'ether')
        PPPNNN = option * 1000 + betId
        total_value = amount_wei + PPPNNN

        tx = contract.functions.placeBet(option, betId).buildTransaction({
            'from': account.address,
            'value': total_value,
            'nonce': web3.eth.get_transaction_count(account.address),
            'gas': 2000000,
            'gasPrice': web3.toWei('5', 'gwei')
        })

        signed_tx = web3.eth.account.sign_transaction(tx, account.privateKey)
        tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f"Transaction sent: {web3.toHex(tx_hash)}")
        print("Awaiting transaction confirmation...")
        receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
        if receipt.status:
            print("Your bet was successfully submitted!")
        else:
            print("Transaction failed. Try again.")
    except Exception as e:
        print(f"Error participating in the bet: {e}")

def settle_bet(web3, account, contract):
    try:
        betId = int(input("Insert the Bet ID to settle NNN (0-999): "))
        if betId < 0 or betId > 999:
            print("Bet ID out of range. Try again.")
            return

        tx = contract.functions.settleBet(betId).buildTransaction({
            'from': account.address,
            'nonce': web3.eth.get_transaction_count(account.address),
            'gas': 2000000,
            'gasPrice': web3.toWei('5', 'gwei')
        })

        signed_tx = web3.eth.account.sign_transaction(tx, account.privateKey)
        tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f"Transaction sent: {web3.toHex(tx_hash)}")
        print("Awaiting transaction confirmation...")
        receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
        if receipt.status:
            print("Bet successfully setted!")
        else:
            print("Transaction fail. Try again.")
    except Exception as e:
        print(f"Error found while settling the Bet: {e}")

def claim_reward(web3, account, contract):
    try:
        betId = int(input("Enter the Bet ID NNN to claim your rewards (0-999): "))
        if betId < 0 or betId > 999:
            print("Bet ID out of range. Try again.")
            return

        tx = contract.functions.claimReward(betId).buildTransaction({
            'from': account.address,
            'nonce': web3.eth.get_transaction_count(account.address),
            'gas': 2000000,
            'gasPrice': web3.toWei('5', 'gwei')
        })

        signed_tx = web3.eth.account.sign_transaction(tx, account.privateKey)
        tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f"Transacción enviada: {web3.toHex(tx_hash)}")
        print("Esperando confirmación de la transacción...")
        receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
        if receipt.status:
            print("Reward was claimed successfully!")
        else:
            print("Transaction failed. Try again")
    except Exception as e:
        print(f"Error while claiming your rewards: {e}")

def get_bet_info(contract):
    try:
        betId = int(input("Enter the Bet ID NNN to get the Bet info (0-999): "))
        if betId < 0 or betId > 999:
            print("Bet ID out of range. Try again.")
            return

        betInfo = contract.functions.getBetInfo(betId).call()
        print("\n--- Bet Info ---")
        print(f"ID: {betInfo[0]}")
        print(f"Variation (PPP): {betInfo[1]}")
        print(f"Starting time: {web3.toTimestamp(betInfo[2])}")
        print(f"Ending time: {web3.toTimestamp(betInfo[3])}")
        print(f"Initial prize: {betInfo[4]}")
        print(f"Status: {'Liquidada' if betInfo[5] else 'Activa'}")
        print(f"Total on Pot: {web3.fromWei(betInfo[6], 'ether')} cBTC")
        print(f"Total betted by Winners (if any): {web3.fromWei(betInfo[7], 'ether')} cBTC")
        print(f"Winning Optons (if any): {betInfo[8]}")
        print(f"Executor Reward: {web3.fromWei(betInfo[9], 'ether')} cBTC")
    except Exception as e:
        print(f"Error getting the Bet info: {e}")

def list_active_bets(contract):
    try:
        activeBets = contract.functions.getActiveBetIds().call()
        if len(activeBets) == 0:
            print("No active Bets at this time.")
            return
        print("\n--- Active Bets ---")
        for betId in activeBets:
            print(f"Bet ID: {betId}")
    except Exception as e:
        print(f"Error listing active Bets: {e}")

if __name__ == '__main__':
    main()
