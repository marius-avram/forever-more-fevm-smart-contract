# ForeverMore smart contract

## Summary

A Solidity FEVM smart contract that can be used as a starting point for a DAO operating on the Filecoin network.
The objective of the smart contract is to manage the deals between two actors:
- simple users of the network, that want to store some files
- service providers that offer up their space in exchange of currency

At the same time the contract aims to allow its users the option to store in a convenient way files, that are replicated over the network at any point in time. While for the storage providers it aims to provide a steady source of income from new storage bounties.

In current verion the basic user can create a storage deal offer/bounty for a file based on its CID. For each bounty he can
select:
- the desired amount of replicas that he wants to achive on the filecoin network
- the minimum storage period desired for each replica

Once the storage period for a replica has passed/expired it will try to make a new replica in the network for the same storage period that was first defined at the creation of the bounty. That will happen only if there are storage providers on the network willing to still take up the offer, and if the user that initiated the storage bounty has enough funds deposited in the contract.

This project has been developed as part of the [Spacewarp Virtual Hackaton 2023](https://ethglobal.com/events/spacewarp) and it was deployed on the Filecoint Hyperspace testnet.

## Usage scenarios

A typical usage scenario of the contract will look like this (involving the two actors mentioned earlier):

- User1 wants to create a bounty for storing a file:
  - calls the contract to find out the amount of FIL he needs to pre-deposit to allow the creation of the bounty (based on the number of replicas, size and basic storage period)
  - deposits the amount of FIL specified by the contract
  - creates the file bounty, if the pre-deposit was not made the bounty will fail creation

- The Service Provider:
  - will get a list with the available bounties that don't have the replica expectation met.
  - selects one of the bounties it wants to complete
  - does the storage deal for the specified period of time in the bounty (outside the contract)
  - specifies the deal id for the bounty selected and if CID from the deal matches the one from the bounty he will get paid with the price of one replica.

## Smart contract

The smart contract can be found at `contracts/perpetual-storage-bounties/PerpetualStorageBounties.sol`.
It was deployed on the hyperspace testnet at adress: `0x0aA7309C29a937dDf81E0E0aF8175d43519be9ef`.

It makes use of [Zondax MarketAPI library](https://github.com/Zondax/filecoin-solidity).

## Further developments
- Right now the way bounties are filled is by manual interaction with the dapp frontend. This could be automated by a script that checks existing deals and finds out if they match existing offers. If this becomes too computational intensive an option would be for service providers to have their address registered in the contract and check only for the deals that are created by those addresses.
- Only the account of the service provider that made the deal (outside the contract) should be able to claim bounties. This way there won't be ways for uninvolved actors in the whole process to fill bounty offers and get paid.
- Automated renewal of expired replicas, which are past their storage period.
- A function that retrives the amount required to pre-fund in case created replicas will expire soon (14 days) and the user doesn't have any more funds left in the contract. This could be attached to a cron job that notifies the user about the possiblity of data loss if they don't continue to add funds.




## Developement and local testing

The project is based on the [fevm-hardhad-kit] (https://github.com/filecoin-project/fevm-hardhat-kit.git)

To run, execute the following steps:

### Cloning

```
git clone https://github.com/marius-avram/forever-more-fevm-smart-contract
cd fevm-hardhat-kit
yarn install
```

### Add private key

Add your private key as an environment variable by running this command:

 ```
export PRIVATE_KEY='abcdef'
```

If you use a .env file, don't commit and push any changes to .env files that may contain sensitive information, such as a private key! If this information reaches a public GitHub repository, someone can use it to check if you have any Mainnet funds in that wallet address, and steal them!


### Get the Deployer Address

Run this command:
```
yarn hardhat get-address
```

The will show you the ethereum-style address associated with that private key and the filecoin-style f4 address (also known as t4 address on testnets)! The Ethereum address can now be exclusively used for almost all FEVM tools, including the faucet.


### Fund the Deployer Address

Go to the [Hyperspace testnet faucet](https://hyperspace.yoga/#faucet), and paste in the Ethereum address from the previous step. This will send some hyperspace testnet FIL to the account.


### Deploy the Contract

Run: 

 ```
yarn hardhat deploy
```


### Interact with the Contracts

You can interact with contracts via hardhat tasks, found in the 'tasks' folder. More specifically for the PerpetualStorageBounties contract type in the following command in the terminal:

 ```
 yarn hardhat add-bounty --contract  'THE DEPLOYED CONTRACT ADDRESS HERE' --cid 'CID' --size 'FILE_SIZE' --replicas 'DESIRED_REPLICAS' --period 'STORAGE_PERIOD_PER_REPLICA'
```

The console should read that your account has 12000 SimpleCoin!

# Known problems

- There are still some bugs in the claimBounty function as the limited time available for the hackaton did not permit enough debugging. 