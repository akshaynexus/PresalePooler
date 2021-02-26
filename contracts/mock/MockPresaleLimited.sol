// SPDX-License-Identifier: MIT

pragma solidity >=0.6.8;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IToken is IERC20 {
    function transferOwnership(address newOwner) external;
}

contract MockPresaleLimited is Ownable, ReentrancyGuard {
    using SafeMath for uint;

    uint256 startTime = 0;

    IToken public Token = IToken(address(0));

    bool public isStopped = false;
    bool public isRefundEnabled = false;
    bool public distStarted = false;

    uint public tokensBought = 0;

    uint256 public timeWhitelistSale = 15 minutes;

    bool public teamClaimed = false;


    uint256 constant hardCap = 370 ether;
    uint256 constant minSend = 0.1 ether;
    uint256 constant maxAddrCap = 10 ether;

    uint256 constant tokensPerETH = 602;
    uint256 constant listingPriceTokensPerETH = 542;

    uint256 public ethSent;

    uint256 public lockedLiquidityAmount;
    uint256 public timeTowithdrawTeamTokens;
    uint256 public refundTime;

    mapping(address => uint) ethSpent;
    mapping(address => bool) public PRIVLIST;


    constructor() {
        //Add refund time to 2 days from now,incase we need to refund
        refundTime = block.timestamp.add(2 days);
        PRIVLIST[msg.sender] = true;
    }


    receive() external payable {
        buyTokens();
    }

    function enableRefunds() external onlyOwner nonReentrant {
        isRefundEnabled = true;
        isStopped = true;
    }

    function batchAddWhitelisted(address[] calldata addrs) public onlyOwner {
        for(uint i=0;i<addrs.length;i++) {
            PRIVLIST[addrs[i]] = true;
        }
    }

    function isPrivsalePhase() public view returns (bool) {
        return block.timestamp < startTime.add(timeWhitelistSale);
    }

    function getRefund() external nonReentrant {
        // Refund should be enabled by the owner OR 7 days passed
        require(isRefundEnabled || block.timestamp >= refundTime,"Cannot refund");
        address payable user = msg.sender;
        uint256 amount = ethSpent[user];
        ethSpent[user] = 0;
        user.transfer(amount);
    }

    function setToken( address addr) external onlyOwner nonReentrant {
        require(address(Token) == address(0), "You can set the address only once");
        Token = IToken(addr);
    }

    function setPrivatesaleDuration(uint256 newDuration) public onlyOwner {
        timeWhitelistSale = newDuration;
    }

    function startDistribution() external onlyOwner {
        startTime = block.timestamp;
        distStarted = true;
    }

     function pauseDistribution() external onlyOwner {
        distStarted = false;
    }

    function buyTokens() public payable nonReentrant {
        require(distStarted == true, "!distStarted");
        require(Token != IToken(address(0)), "!Token");
        require(!isStopped, "stopped");
        require(msg.value >= minSend, "<minsend");
        require(msg.value <= maxAddrCap, ">maxaddrcap");
        require(ethSent < hardCap, "Hard cap reaches");
        require (msg.value.add(ethSent) <= hardCap, "Hardcap will be reached");
        require(ethSpent[msg.sender].add(msg.value) <= maxAddrCap, "You cannot buy more");

        uint256 tokens = msg.value.mul(tokensPerETH);
        require(Token.balanceOf(address(this)) >= tokens, "Not enough tokens in the contract");

        ethSpent[msg.sender] = ethSpent[msg.sender].add(msg.value);
        tokensBought = tokensBought.add(tokens);
        ethSent = ethSent.add(msg.value);
        Token.transfer(msg.sender, tokens);
    }

    function userEthSpenttInDistribution(address user) external view returns (uint) {
        return ethSpent[user];
    }

    function claimTeamFeeAndAddLiquidity() external onlyOwner  {
       require(!teamClaimed);
       uint256 amountETH = address(this).balance;
       payable(owner()).transfer(amountETH);
       teamClaimed = true;
    }
}