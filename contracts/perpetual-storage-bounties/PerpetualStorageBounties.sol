// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { MarketAPI, MarketAPIOld } from "../lib/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
import { CommonTypes } from "../lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import { MarketTypes } from "../lib/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";
import { Actor, HyperActor } from "../lib/filecoin-solidity/contracts/v0.8/utils/Actor.sol";
import { Misc } from "../lib/filecoin-solidity/contracts/v0.8/utils/Misc.sol";


contract PerpetualStorageBounties {

    struct FileBounty {
        bytes32 id;
        uint createdAt;
        address owner;
        bytes cidRaw;
        string cidReadable;
        uint cidSize;
        uint desiredReplicas;
        uint storedReplicas;
        uint desiredStoragePeriod;
    }

    struct FileDeal {
        bytes32 bountyId;
        uint64 provider;
        uint64 dealId;
        uint expirationTimestamp;
    }

    mapping(address => uint) public funds;

    mapping(bytes32 => FileBounty) public bounties;
    bytes32[] public bountiesIds;
    uint public bountiesCount;

    mapping(bytes32 => FileDeal[]) public deals;
    mapping(bytes => mapping(uint64 => uint)) public cidDealProviders; // { cid : { provider : expirationTimestamp } }

    address public owner;

    // Constants
    address constant CALL_ACTOR_ID = 0xfe00000000000000000000000000000000000005;
    uint64 constant DEFAULT_FLAG = 0x00000000;
    uint64 constant METHOD_SEND = 0;


    /* The reward for a sector replica for one STORAGE_QUANTUM_PERIOD : 0.1 FIL */
    uint REWARD_PER_SECTOR_REPLICA = 100000000000000000;
    /* 
       The reward is paid in 180 days quantums, if somebody wants to store a file for
       200 days it will have to prefund the contract with 2 * REWARD_PER_SECTOR_REPLICA.
       360 days it will have to prefund the contract with 2 * REWARD_PER_SECTOR_REPLICA.
       361 days it will have to prefund the contract with 3 * REWARD_PER_SECTOR_REPLICA.
    */
    uint STORAGE_QUANTUM_PERIOD = 180; 

    constructor() {
        owner = msg.sender;
    }

    function preFund() public payable {
        /* Add funds that a required for the creation of a bounty */
        funds[msg.sender] += msg.value;
    }

    function getFundsLocked(address account) public view returns (uint) {
        /* Get the amount of funds locked by the given account in the current contract */
        return funds[account];
    }

    function computeRequiredFunds(uint replicas, uint period) public view returns (uint) {
        /* Compute the required funds that a sender needs to store a file based on replicas and storage period */
        uint period_quantums = (period + STORAGE_QUANTUM_PERIOD - 1) / STORAGE_QUANTUM_PERIOD; // round up 
        uint minimum_required_funds = REWARD_PER_SECTOR_REPLICA * replicas * period_quantums;
        return minimum_required_funds;
    }

    function computeBountyId(address account, bytes memory cidRaw) internal view returns (bytes32) {
        /* Computer a unique bounty id based on cid and the sender address */
        return keccak256(abi.encode(cidRaw, account));
    }

    function addBounty(
        address account, 
        bytes calldata cidRaw, string calldata cidReadable, uint size, uint replicas, uint period
    ) public {
        // Verify if the sender has prefunded enough funds for this bounty
        uint sender_funds = funds[account];
        uint minimum_required_funds = computeRequiredFunds(replicas, period);
        require(sender_funds >= minimum_required_funds, "Not enough funds deposited to add bounty");

        // Create the bounty
        bytes32 bountyId = computeBountyId(account, cidRaw);
        FileBounty memory bounty = FileBounty({
            id: bountyId,
            createdAt: block.timestamp,
            owner: account,
            cidRaw: cidRaw,
            cidReadable: cidReadable,
            cidSize: size,
            desiredReplicas: replicas,
            storedReplicas: 0,
            desiredStoragePeriod: period
        });
        bounties[bountyId] = bounty;
        bountiesIds.push(bountyId);
        bountiesCount++;
    }

    function getBounties() public view returns (FileBounty[] memory) {
        /*
            This method can potentially use a lot of gas when the number of bounties increases.
            Its purpose is to be used in the dApp frontend for now.
        */
        FileBounty[] memory bountiesArray = new FileBounty[](bountiesCount);
        for (uint i=0; i<bountiesCount; i++) {
            bytes32 bountyId = bountiesIds[i];
            bountiesArray[i] = bounties[bountyId];
        }
        return bountiesArray;
    }

    /* Utility function to compare two bytes */
    function compareBytes(bytes memory a, bytes memory b) internal returns (int) {
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;
        for (uint i = 0; i < minLength; i ++)
            if (a[i] < b[i])
                return -1;
            else if (a[i] > b[i])
                return 1;
        if (a.length < b.length)
            return -1;
        else if (a.length > b.length)
            return 1;
        else
            return 0;
    }

    /* Utility function to compare two bytes and returns true if they are equal. */
    function equalBytes(bytes memory a, bytes memory b ) internal returns (bool) {
        return compareBytes(a, b) == 0;
    }

    function computeDealDurationDays(int64 start, int64 end) internal returns (int64) {
        /*
          Compute the duration in days between epochsStart and epochEnd in a deal.
          Assuming the duration of an epoch is 30 seconds on the FILECOIN network.
        */
        int64 ONE_EPOCH = 30; // 30 seconds
        int64 SECONDS_IN_DAY = 86400;
        int64 durationInEpochs = end - start;
        int64 durationInDays = (durationInEpochs * ONE_EPOCH) / SECONDS_IN_DAY;
        return durationInDays;
    }

    function isProviderUnique(bytes memory cidraw, uint64 provider) internal view returns (bool) {
        uint dealTimestampEnd = cidDealProviders[cidraw][provider];
        if (dealTimestampEnd == 0) {
          // No deal yet
          return true;
        }
        else if (dealTimestampEnd < block.timestamp) {
          // There was a deal for the given provider, but it expired
          return true;
        }
        else {
          return false;
        }
    }

    function computeDealExpirationTimestamp(bytes32 bountyId) internal returns (uint) {
        uint SECONDS_IN_DAY = 86400;
        return block.timestamp + bounties[bountyId].desiredStoragePeriod * SECONDS_IN_DAY;
    }

    function authorizeDeal(bytes32 bountyId, bytes memory cidRaw, uint64 provider, uint size, int64 duration) public {
        require(equalBytes(bounties[bountyId].cidRaw,cidRaw), "deal cid should match bounty cid");
        require(bounties[bountyId].cidSize == size, "data size should match bounty file size");
        require(duration >= int64(uint64(bounties[bountyId].desiredStoragePeriod)), "duration of deals does not match bounty storage period");
        require(isProviderUnique(cidRaw, provider), "deal failed policy check, the provider already claimed this cid");

        // Store the end timestamp of the deal
        cidDealProviders[cidRaw][provider] = computeDealExpirationTimestamp(bountyId);
    }

    function createDealEntry(bytes32 bountyId, uint64 dealId, uint64 provider) internal {
      FileDeal memory deal = FileDeal({
        bountyId: bountyId,
        provider: provider,
        dealId: dealId,
        expirationTimestamp: computeDealExpirationTimestamp(bountyId)
      });
      // TODO: remove deals that are expired when we add a new one
      deals[bountyId].push(deal);
      
      // Update stored replicas
      bounties[bountyId].storedReplicas = deals[bountyId].length;
    }

    /* Public function to claim a bounty for an existing bountyId, given a dealId */
    function claimBounty(bytes32 bountyId, uint64 dealId) public {
        MarketTypes.GetDealDataCommitmentReturn memory commitmentRet = MarketAPI.getDealDataCommitment(MarketTypes.GetDealDataCommitmentParams({id: dealId}));
        MarketTypes.GetDealProviderReturn memory providerRet = MarketAPI.getDealProvider(MarketTypes.GetDealProviderParams({id: dealId}));
        MarketTypes.GetDealTermReturn memory dealTerm = MarketAPIOld.getDealTerm(MarketTypes.GetDealTermParams({id: dealId}));

        int64 dealDurationInDays = computeDealDurationDays(dealTerm.start, dealTerm.end);
        authorizeDeal(bountyId, commitmentRet.data, providerRet.provider, commitmentRet.size, dealDurationInDays);

        // get dealer (bounty hunter client)
        MarketTypes.GetDealClientReturn memory clientRet = MarketAPI.getDealClient(MarketTypes.GetDealClientParams({id: dealId}));

        // create a deal entry
        createDealEntry(bountyId, dealId, providerRet.provider);

        // send reward to client 
        send(bountyId, clientRet.client);
    }

    function call_actor_id(uint64 method, uint256 value, uint64 flags, uint64 codec, bytes memory params, uint64 id) public returns (bool, int256, uint64, bytes memory) {
        (bool success, bytes memory data) = address(CALL_ACTOR_ID).delegatecall(abi.encode(method, value, flags, codec, params, id));
        (int256 exit, uint64 return_codec, bytes memory return_value) = abi.decode(data, (int256, uint64, bytes));
        return (success, exit, return_codec, return_value);
    }

    /* Send reward for bounty for actor ad actorID */
    function send(bytes32 bountyId, uint64 actorID) internal {
        bytes memory emptyParams = "";
        delete emptyParams;
        
        uint bountyPrice = computeRequiredFunds(bounties[bountyId].desiredReplicas, bounties[bountyId].desiredStoragePeriod);
        HyperActor.call_actor_id(METHOD_SEND, bountyPrice, DEFAULT_FLAG, Misc.NONE_CODEC, emptyParams, actorID);

    }

}

