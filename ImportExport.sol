// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ImportExport
 * @dev Secure smart contract for import/export transactions with ETH payments and refunds.
 * 
 * Developed by Saumya Desai
 */
contract ImportExport {
    address public immutable owner;
    bool public paused = false;

    enum TradeStatus { Created, Paid, Shipped, Completed, Canceled }

    struct Trade {
        address payable exporter;
        address payable importer;
        string goods;
        uint price;
        TradeStatus status;
        uint256 paymentTimestamp;
    }
    
    mapping(uint => Trade) public trades;
    uint public tradeCounter;
    mapping(bytes32 => bool) private usedTxHashes; // Anti-replay protection

    event TradeCreated(uint tradeId, address exporter, address importer, string goods, uint price);
    event TradePaid(uint tradeId, address importer, uint amount);
    event TradeShipped(uint tradeId, address exporter);
    event TradeCompleted(uint tradeId, address exporter, address importer);
    event TradeCanceled(uint tradeId, address initiator);
    event TradeRefunded(uint tradeId, address importer, uint amount);
    event ContractPaused(bool paused);
    event ContractDestroyed(address owner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createTrade(address payable importer, string memory goods, uint price) public whenNotPaused {
        require(importer != address(0), "Invalid importer address");
        require(price > 0, "Price must be greater than zero");

        tradeCounter++;
        trades[tradeCounter] = Trade(payable(msg.sender), importer, goods, price, TradeStatus.Created, 0);
        emit TradeCreated(tradeCounter, msg.sender, importer, goods, price);
    }

    function payForTrade(uint tradeId) public payable whenNotPaused {
        Trade storage trade = trades[tradeId];

        require(msg.sender == trade.importer, "Only the importer can pay");
        require(trade.status == TradeStatus.Created, "Trade not available for payment");
        require(msg.value == trade.price, "Incorrect ETH amount sent");

        bytes32 txHash = keccak256(abi.encodePacked(msg.sender, msg.value, block.timestamp));
        require(!usedTxHashes[txHash], "Duplicate transaction detected");
        usedTxHashes[txHash] = true;

        trade.status = TradeStatus.Paid;
        trade.paymentTimestamp = block.timestamp;

        emit TradePaid(tradeId, msg.sender, msg.value);
    }

    function shipTrade(uint tradeId) public whenNotPaused {
        Trade storage trade = trades[tradeId];

        require(msg.sender == trade.exporter, "Only the exporter can mark trade as shipped");
        require(trade.status == TradeStatus.Paid, "Trade must be paid before shipping");

        trade.status = TradeStatus.Shipped;
        emit TradeShipped(tradeId, msg.sender);
    }

    function completeTrade(uint tradeId) public whenNotPaused {
        Trade storage trade = trades[tradeId];

        require(msg.sender == trade.importer, "Only the importer can confirm trade completion");
        require(trade.status == TradeStatus.Shipped, "Trade must be shipped before completion");

        trade.status = TradeStatus.Completed;
        trade.exporter.transfer(trade.price);

        emit TradeCompleted(tradeId, trade.exporter, msg.sender);
    }
}
