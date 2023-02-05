const CID = require('cids')
const util = require("util");
const request = util.promisify(require("request"));

task(
    "compute-required-funds",
    "Compute required-funds for a bounty"
  )
    .addParam("contract", "The address of the PerpetualStorageBounties contract")
    .addParam("replicas", "Number of replicas for the data")
    .addParam("period", "Duration of each lease in days")
    .setAction(async (taskArgs) => {
        const contractAddr = taskArgs.contract
        const account = taskArgs.account
        const networkId = network.name
        console.log("Compute required funds for bounty", networkId)
        const PerpetualStorageBounties = await ethers.getContractFactory("PerpetualStorageBounties")
  
        //Get signer information
        const accounts = await ethers.getSigners()
        const signer = accounts[0]

        const priorityFee = await callRpc("eth_maxPriorityFeePerGas");
        console.log("priorityFee " + priorityFee);

    async function callRpc(method, params) {
        var options = {
          method: "POST",
          url: "https://api.hyperspace.node.glif.io/rpc/v1",
          // url: "http://localhost:1234/rpc/v0",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            jsonrpc: "2.0",
            method: method,
            params: params,
            id: 1,
          }),
        };
        const res = await request(options);
        return JSON.parse(res.body).result;
      }

        
        const perpetualStorage = new ethers.Contract(contractAddr, PerpetualStorageBounties.interface, signer)
        const replicas = taskArgs.replicas;
        const period = taskArgs.period;

        requiredFunds = await perpetualStorage.computeRequiredFunds( replicas, period, {
            gasLimit: 1000000000,
            maxPriorityFeePerGas: priorityFee
        });
        let result = BigInt(requiredFunds);
        console.log("Required funds " + result);

    })

  module.exports = {}
  