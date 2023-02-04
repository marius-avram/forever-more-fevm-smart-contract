// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { MarketAPI } from "../lib/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
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
        uint desiredStoragePeriod;
    }

    struct FileDeal {
        bytes32 bountyId;
        uint64 dealId;
        uint createdAt;
    }

    mapping(address => uint) public funds;

    mapping(bytes32 => FileBounty) public bounties;
    bytes32[] public bountiesIds;
    uint public bountiesCount;

    mapping(bytes32 => FileDeal) public deals;

    address public owner;

    // TODO: Deprecated should remove following 3 lines
    mapping(bytes => bool) public cidSet;
    mapping(bytes => uint) public cidSizes;
    mapping(bytes => mapping(uint64 => bool)) public cidProviders;

    // Constants
    address constant CALL_ACTOR_ID = 0xfe00000000000000000000000000000000000005;
    uint64 constant DEFAULT_FLAG = 0x00000000;
    uint64 constant METHOD_SEND = 0;


    /* The reward for a sector replica for one STORAGE_QUANTUM_PERIOD */
    uint REWARD_PER_SECTOR_REPLICA = 1000000000000000000;
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

    function fund() public payable {
        funds[msg.sender] += msg.value;
    }

    function computeRequiredFunds(uint replicas, uint period) public view returns (uint) {
        uint period_quantums = (period + STORAGE_QUANTUM_PERIOD - 1) / STORAGE_QUANTUM_PERIOD; // round up 
        uint minimum_required_funds = REWARD_PER_SECTOR_REPLICA * replicas * period_quantums;
        return minimum_required_funds;
    }

    function computeBountyId(bytes memory cidRaw) internal view returns (bytes32) {
        return keccak256(abi.encode(cidRaw, msg.sender));
    }

    function addBounty(bytes calldata cidRaw, string calldata cidReadable, uint size, uint replicas, uint period) public {
        // Verify if the sender has prefunded enough funds for this bounty
        uint sender_funds = funds[msg.sender];
        uint minimum_required_funds = computeRequiredFunds(replicas, period);
        require(sender_funds > minimum_required_funds, "Not enough funds deposited to add bounty");

        bytes32 bountyId = computeBountyId(cidRaw);
        FileBounty memory bounty = FileBounty({
            id: bountyId,
            createdAt: block.timestamp,
            owner: msg.sender,
            cidRaw: cidRaw,
            cidReadable: cidReadable,
            cidSize: size,
            desiredReplicas: replicas,
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

    function policyOK(bytes memory cidraw, uint64 provider) internal view returns (bool) {
        bool alreadyStoring = cidProviders[cidraw][provider];
        return !alreadyStoring;
    }

    function authorizeData(bytes memory cidraw, uint64 provider, uint size) public {
        require(cidSet[cidraw], "cid must be added before authorizing");
        require(cidSizes[cidraw] == size, "data size must match expected");
        require(policyOK(cidraw, provider), "deal failed policy check: has provider already claimed this cid?");

        cidProviders[cidraw][provider] = true;
    }

    function claim_bounty(uint64 deal_id) public {
        MarketTypes.GetDealDataCommitmentReturn memory commitmentRet = MarketAPI.getDealDataCommitment(MarketTypes.GetDealDataCommitmentParams({id: deal_id}));
        MarketTypes.GetDealProviderReturn memory providerRet = MarketAPI.getDealProvider(MarketTypes.GetDealProviderParams({id: deal_id}));

        authorizeData(commitmentRet.data, providerRet.provider, commitmentRet.size);

        // get dealer (bounty hunter client)
        MarketTypes.GetDealClientReturn memory clientRet = MarketAPI.getDealClient(MarketTypes.GetDealClientParams({id: deal_id}));

        // send reward to client 
        send(clientRet.client);
    }

    function call_actor_id(uint64 method, uint256 value, uint64 flags, uint64 codec, bytes memory params, uint64 id) public returns (bool, int256, uint64, bytes memory) {
        (bool success, bytes memory data) = address(CALL_ACTOR_ID).delegatecall(abi.encode(method, value, flags, codec, params, id));
        (int256 exit, uint64 return_codec, bytes memory return_value) = abi.decode(data, (int256, uint64, bytes));
        return (success, exit, return_codec, return_value);
    }

    // send 1 FIL to the filecoin actor at actor_id
    function send(uint64 actorID) internal {
        bytes memory emptyParams = "";
        delete emptyParams;

        uint oneFIL = 1000000000000000000;
        HyperActor.call_actor_id(METHOD_SEND, oneFIL, DEFAULT_FLAG, Misc.NONE_CODEC, emptyParams, actorID);

    }

}

