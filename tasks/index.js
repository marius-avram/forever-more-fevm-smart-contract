exports.getBalance = require("./simple-coin/get-balance")
exports.getAddress = require("./get-address")
exports.sendCoin = require("./simple-coin/send-coin")
exports.storeAll = require("./filecoin-market-consumer/store-all")
exports.addCID = require("./deal-rewarder/add-cid")
exports.fund = require("./deal-rewarder/fund")
exports.claimBounty = require("./deal-rewarder/claim-bounty")
exports.addBounty = require("./perpetual-storage-bounties/add-bounty")
exports.computeRequiredFunds = require("./perpetual-storage-bounties/compute-required-funds");
exports.getFundsLocked = require("./perpetual-storage-bounties/get-funds-locked");
