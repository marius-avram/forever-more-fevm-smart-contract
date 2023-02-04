const CID = require('cids')
const util = require("util");
const request = util.promisify(require("request"));

task(
    "add-bounty",
    "Adds a CID (should be a piece ID) of data that you would like to put a storage bounty on."
  )
    .addParam("contract", "The address of the PerpetualStorageBounties contract")
    .addParam("cid", "The piece CID of the data you want to put up a bounty for")
    .addParam("size", "Size of the data you are putting a bounty on")
    .addParam("replicas", "Number of replicas for the data")
    .addParam("period", "Duration of each lease in days")
    .setAction(async (taskArgs) => {
        const contractAddr = taskArgs.contract
        const account = taskArgs.account
        const networkId = network.name
        console.log("Adding CID as a bounty", networkId)
        const PerpetualStorageBounties = await ethers.getContractFactory("PerpetualStorageBounties")
  
        //Get signer information
        const accounts = await ethers.getSigners()
        const signer = accounts[0]

        const priorityFee = await callRpc("eth_maxPriorityFeePerGas")

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
        const cid = taskArgs.cid;
        const size = taskArgs.size;
        const replicas = taskArgs.replicas;
        const period = taskArgs.period;
        const cidHexRaw = new CID(cid).toString('base16').substring(1);
        const cidHex = "0x00" + cidHexRaw;
        console.log("Bytes are:", cidHex)

        await perpetualStorage.addCID(cidHex, cid, size, replicas, period, {
            gasLimit: 1000000000,
            maxPriorityFeePerGas: priorityFee
        })

        console.log("Complete! Please wait about a minute before reading state!" )
    })

  module.exports = {}
  