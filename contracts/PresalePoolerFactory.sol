//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
import "hardhat/console.sol";

import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable , SimpleProxy, ReentrancyGuard } from "./SimpleProxy.sol";

contract PresalePoolerFactory is ERC20, Ownable, ReentrancyGuard {
    IERC20 public token;

    address public targetAddr;

    uint256 public limit;
    uint256 public maxLimit;
    uint256 public minSend;
    uint256 public claimPerETH;

    uint FEE = 500;//5%
    uint BASE = 10000;

    bool public bought = false;
    bool public claimedTokens = false;
    bool public forceRetrive;

    mapping(address => uint) deposits;
    SimpleProxy[] deployedProxies;
    address[] depositors;

    constructor(address _token,
                address _presaleAddr,
                uint256 investLimitPerAddr,
                uint256 maxL,
                uint256 _minSend
                ) ERC20
                (string(abi.encodePacked("PrePool ", ERC20(_token).name())),
                string(abi.encodePacked("p", ERC20(_token).symbol())))
    {
            token = IERC20(_token);
            targetAddr = _presaleAddr;
            limit = investLimitPerAddr;
            maxLimit = maxL;//Max hardcap of sale
            minSend = _minSend;
    }

    function getFee(uint value) internal view returns (uint) {
        return (value * FEE) / BASE;
    }

    function getDepositors() external view returns (address[] memory) {
        return depositors;
    }

    receive() external payable nonReentrant {
        if(msg.sender != targetAddr) {
            uint msgval = msg.value;
            uint256 fee = getFee(msgval);
            uint256 amountAfterFee = msgval - fee;
            //Take into account of current supply minus the fee address
            uint256 newAlloc = (totalSupply() - balanceOf(owner())) + amountAfterFee;
            uint256 refundAmount = newAlloc > maxLimit ? newAlloc - maxLimit : 0;
            uint256 mintAmount = amountAfterFee - refundAmount;
            if(refundAmount > 0) {
                //Refund back the difference
                (bool success,) = msg.sender.call{value: refundAmount }("");
                require(success,"!refund");
            }
            //Mint iou tokens to sender
            _mint(msg.sender,mintAmount);
            //Mint iou tokens to gov for fees
            _mint(owner(),fee);
            if(deposits[msg.sender] == 0) depositors.push(msg.sender);//Add depositor to array
            deposits[msg.sender] = (deposits[msg.sender] + msgval) - refundAmount;
        }
        else{
            //Send any eth gotten via refund to owner()
            payable(owner()).transfer(msg.value);
        }
    }

    function deployProxies() internal {
        uint256 bal = address(this).balance;
        uint256 targetProxies = limit != 0 ? bal / limit : 1;//Only deploy 1 proxy if limit is 0 which means no limit per address
        deployedProxies = new SimpleProxy[](targetProxies);
        //Deploy multiple dsproxies to invest
        for(uint i=0;i<targetProxies;i++) {
            deployedProxies[i] = new SimpleProxy();
        }
    }

    function getAvailableBal() internal view returns (uint) {
        uint bal = address(this).balance;
        uint balgov = balanceOf(owner());
        if(bal > balgov) return bal - balgov;
        else if (bal < minSend) return 0;//Dont send if we dont match minsend of sale contract
        else if (bal <= balgov) return 0;
        return 0;
    }

    function buy() external onlyOwner {
        require(!bought,"Already bought");
        deployProxies();
        uint targval = limit;
        uint256 balE = getAvailableBal();
        for(uint i=0;i<deployedProxies.length && balE != 0 ;i++) {
            //Send limit to wallet and execute to buy tokens
            deployedProxies[i].executeWithValue{value: targval}(targetAddr,new bytes(0));
            balE = getAvailableBal();//Update balance
            if(balE <= limit) {targval = balE;}
            //Call approve on target so that we can pull the target tokens
            deployedProxies[i].execute(address(token),abi.encodeWithSignature("approve(address,uint256)", address(this),uint256(-1)));
        }
        bought = true;
    }

    //Call this if you want to opt out of the pool after depositing
    function getETH() external nonReentrant {
        require(!bought,"funds not available to claim");
        uint balCaller = balanceOf(msg.sender);
        require(balCaller > 0,"No Poolshare tokens");
        uint depAmount = deposits[msg.sender];
        require(depAmount > 0,"No deposited eth");

        _burn(msg.sender, balCaller);
        deposits[msg.sender] = 0;//Reset deposits amount
        (bool success,) = msg.sender.call{value : depAmount}("");
        require(success,"!getGovFees");
    }

    //This sends owner() fees,will only send if tokens were bought successfully
    function getGovFees() external {
        require(bought,"Buy didnt complete");
        uint govbal = balanceOf(owner());
        _burn(owner(), govbal);
        (bool success,bytes memory returnData) = owner().call{value : govbal}("");
        require(success,string(returnData));
    }

    function pullTokens() external {
        require(!claimedTokens,"Already claimed");
        //Call transferfrom from all proxies to this addr
        for(uint i=0;i<deployedProxies.length;i++) {
            token.transferFrom(address(deployedProxies[i]), address(this), token.balanceOf(address(deployedProxies[i])));
        }
        require(token.balanceOf(address(this)) > 0,"No tokens gotten");
        claimPerETH = token.balanceOf(address(this)) / totalSupply();
        claimedTokens = true;
    }

    function claimTokens() external {
        require(claimedTokens,"Not claimed yet");
        uint256 claimable = balanceOf(msg.sender) * claimPerETH;
        require(claimable > 0,"No tokens claimable");
        _burn(msg.sender,balanceOf(msg.sender));
        token.transfer(msg.sender,claimable);
    }

    function enableForceRetrive() external onlyOwner {
        forceRetrive = true;
    }

    function retriveBnb() external onlyOwner {
        //Use this to retrive bnb if buy didnt happen or there is excess
        require(bought || totalSupply() == 0 || forceRetrive,"Failed prerequisites");
        (bool success,bytes memory returnData) = owner().call{value : address(this).balance}("");
        require(success,string(returnData));
    }

    function retriveTokens() external onlyOwner {
        require(bought || totalSupply() == 0 || forceRetrive,"Failed prerequisites");
        token.transfer(owner(),token.balanceOf(address(this)));
    }

    //Used to destruct proxies that are not needed
    function destructProxies() external onlyOwner {
        for(uint i=0;i<deployedProxies.length;i++) {
            deployedProxies[i].destruct();
        }
    }

    function retriveTokensFromProxies(address _token) external onlyOwner {
        IERC20 itoken = IERC20(_token);
        for(uint i=0;i<deployedProxies.length;i++) {
            //Transfer to this address
            deployedProxies[i].execute(_token,abi.encodeWithSignature("transfer(address,uint256)", address(this),itoken.balanceOf(address(deployedProxies[i]))));
        }
    }

    function recoverToken(address _token) external onlyOwner {
        IERC20 itoken = IERC20(_token);
        itoken.transfer(owner(),itoken.balanceOf(address(this)));
    }

    //Used by owner to claim tokens if we have to call to proxies manually at some point
    function executeCall(address target,bytes calldata data) external onlyOwner {
        (bool success,) = target.call{value:0}(data);
        require(success,"External call failed");
    }

    function executeCallOnProxy(address target,bytes calldata data,uint index) external onlyOwner {
        deployedProxies[index].execute(target,data);
    }

    function executeCallOnProxies(address target,bytes calldata data) external onlyOwner {
        for(uint i=0;i<deployedProxies.length;i++) {
            deployedProxies[i].execute(target,data);
        }
    }

}