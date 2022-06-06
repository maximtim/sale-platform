//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./Interfaces/IERC20MintBurn.sol";
import "./Interfaces/IUniswapV2Router01.sol";

contract ACDMPlatform {
    IERC20MintBurn token;
    uint roundDuration;
    
    uint currentSalePriceWei = 10_000_000 wei; // 0,00001 ETH = 10^13 Wei / 1 ACDM = 10^7 Wei / 0,000001 ACDM (decimals=6)
    uint currentSaleVolumeWei = 1 ether;
    uint currentRoundEnd;
    bool currentRoundIsSale;

    struct Order {
        uint amountToken;
        uint priceWei;
        address owner;
    }

    mapping (uint => Order) orders;
    uint orderIdFactory;

    mapping (address => address) referrers;
    uint fractureDenominator = 100_000;
    uint referrer1SaleFracture = 5_000;
    uint referrer2SaleFracture = 3_000;
    uint referrer1TradeFracture = 2_500;
    uint referrer2TradeFracture = 2_500;

    uint public tradeCommissionBank;

    address public owner;
    address public dao;

    constructor(
        IERC20MintBurn token_,
        uint roundDuration_, 
        uint initialSalePriceWei_,
        uint initialSaleVolumeWei_) {
        
        token = token_;
        roundDuration = roundDuration_;
        currentSalePriceWei = initialSalePriceWei_;  // 0,00001 ETH = 10^13 Wei / 1 ACDM = 10^7 Wei / 0,000001 ACDM
        currentSaleVolumeWei = initialSaleVolumeWei_; // 1 ETH = 10^18 Wei
        owner = msg.sender;
    }

    ////////////////////////////////////////////

    modifier roundIsSale {
        require(currentRoundIsSale, "Current round must be sale");
        _;
    }

    modifier roundIsTrade {
        require(currentRoundIsSale == false, "Current round must be trade");
        _;
    }

    modifier roundIsGoing {
        require(block.timestamp <= currentRoundEnd, "Round already ended");
        _;
    }

    modifier roundEnded {
        require(block.timestamp > currentRoundEnd, "Current round is still going");
        _;
    }

    modifier only(address account) {
        require(msg.sender == account, "Restricted access");
        _;
    }

    ////////////////////////////////////////////

    function register(address referrer) external {
        referrers[msg.sender] = referrer;
    }

    function setDAO(address dao_) external only(owner) {
        dao = dao_;
    }

    ////////////////////////////////////////////

    function startSaleRound() external only(owner) roundIsTrade roundEnded {
        currentRoundIsSale = true;
        currentRoundEnd = block.timestamp + roundDuration;

        currentSalePriceWei = currentSalePriceWei/100*103 + 4*10**13;
    }

    function buyACDM() external payable roundIsSale roundIsGoing {
        uint saleVolume = currentSaleVolumeWei;
        uint remainder = msg.value > saleVolume ? msg.value - saleVolume : 0;
        uint amountWei = msg.value - remainder;
        uint amountToken = amountWei / currentSalePriceWei;
        require(amountToken > 0, "Not enough payment to buy token");

        currentSaleVolumeWei -= amountWei;
        token.mint(msg.sender, amountToken);

        if (remainder > 0) {
            payable(msg.sender).transfer(remainder);
        }

        payAllReferrers(
            msg.sender, 
            calcCommission(amountWei, referrer1SaleFracture), 
            calcCommission(amountWei, referrer2SaleFracture));
    }

    ////////////////////////////////////////////

    function startTradeRound() external only(owner) roundIsSale roundEnded {

        currentRoundIsSale = false;
        currentRoundEnd = block.timestamp + roundDuration;

        uint unsoldTokenAmount = currentSaleVolumeWei / currentSalePriceWei;
        currentSaleVolumeWei = 0;

        if (unsoldTokenAmount > 0) {
            token.burn(unsoldTokenAmount);
            // currentSaleVolumeWei -= currentSalePriceWei * unsoldTokenAmount; // remainder
        }
    }

    function addOrder(uint tokenAmount, uint price) external roundIsTrade roundIsGoing {
        require(tokenAmount > 0, "Token amount should be > 0");
        require(price > 0, "Price should be > 0");

        orderIdFactory++;
        orders[orderIdFactory] = Order(tokenAmount, price, msg.sender);

        token.transferFrom(msg.sender, address(this), tokenAmount);
    }

    function removeOrder(uint orderId) external roundIsTrade roundIsGoing {
        Order storage order = orders[orderId];
        address orderOwner = order.owner;
        uint amount = order.amountToken;

        require(orderOwner == msg.sender, "Sender is not order owner");
        require(amount > 0, "Order doesnt exist");

        order.amountToken = 0;
        token.transfer(msg.sender, amount);
    }

    function redeemOrder(uint orderId) external payable roundIsTrade roundIsGoing {
        Order storage order = orders[orderId];
        uint amountOrderToken = order.amountToken;
        require(amountOrderToken > 0, "Order doesnt exist");

        uint orderPrice = order.priceWei;
        uint saleVolume = amountOrderToken * orderPrice;
        uint remainder = msg.value > saleVolume ? msg.value - saleVolume : 0;
        uint amountWei = msg.value - remainder;

        uint amountToken = amountWei / orderPrice;
        require(amountToken > 0, "Not enough payment to buy token");

        order.amountToken -= amountToken;
        currentSaleVolumeWei += amountWei;
        
        token.transfer(msg.sender, amountToken);

        if (remainder > 0) {
            payable(msg.sender).transfer(remainder);
        }

        uint comm1 = calcCommission(amountWei, referrer1TradeFracture);
        uint comm2 = calcCommission(amountWei, referrer2TradeFracture);
        uint paid = payAllReferrers(msg.sender, comm1, comm2);
        uint totalCommission = comm1 + comm2;
        tradeCommissionBank += totalCommission - paid;

        payable(order.owner).transfer(amountWei - totalCommission);
    }

    ////////////////////////////////////////////////////

    function calcCommission(uint amountWei, uint fracture) internal view returns (uint payment) {
        return amountWei * fracture / fractureDenominator;
    }

    function payReferrer(address referrer, uint referrerPayment) internal returns (uint amountPaid) {
        if (referrer != address(0)){
            if (referrerPayment > 0){
                payable(referrer).transfer(referrerPayment);
                return referrerPayment;
            }
        }
    }

    function payAllReferrers(address sender, uint amount1, uint amount2) internal returns (uint amountPaid) {
        address referrer1 = referrers[sender];
        uint paid1 = payReferrer(referrer1, amount1);
        if (paid1 > 0) {
            return paid1 + payReferrer(referrers[referrer1], amount2);
        }
    }

    ///////////////////////////////////////////////////

    function setReferrer1SaleFracture(uint value) external only(dao) {
        referrer1SaleFracture = value;
    }

    function setReferrer2SaleFracture(uint value) external only(dao) {
        referrer2SaleFracture = value;
    }

    function setReferrer1TradeFracture(uint value) external only(dao) {
        referrer1TradeFracture = value;
    }

    function setReferrer2TradeFracture(uint value) external only(dao) {
        referrer2TradeFracture = value;
    }

    function transferCommissionBankToOwner() external only(dao) {
        uint bank = tradeCommissionBank;
        tradeCommissionBank = 0;
        payable(owner).transfer(bank);
    }

    function swapCommBankToTokensAndBurn(IERC20MintBurn token_, IUniswapV2Router01 uniswap, uint slippagePercent, uint deadline) external only(dao) {
        uint bank = tradeCommissionBank;
        address[] memory path = new address[](2);
        path[0] = uniswap.WETH();
        path[1] = address(token_);

        uint[] memory amountsOut = uniswap.getAmountsOut(bank, path);
        uint amountOutMin = amountsOut[1] * (100 - slippagePercent) / 100;

        uint[] memory amounts = uniswap.swapExactETHForTokens{value: bank}(amountOutMin, path, address(this), deadline);
        token_.burn(amounts[1]);
    }
}