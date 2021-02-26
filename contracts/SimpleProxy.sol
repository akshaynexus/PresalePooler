//SPDX-License-Identifier: Unlicense
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
pragma solidity ^0.7.0;
interface IOwnable {
    function owner() external view returns (address);
}
contract SimpleProxy is Ownable, ReentrancyGuard {
    receive() external payable  {}

    function execute(address target,bytes calldata data) external onlyOwner  nonReentrant {
        _execute(target, 0, data);
    }

    function executeWithValue(address target,bytes calldata data) external payable onlyOwner nonReentrant {
        _execute(target, msg.value, data);
    }

    function _execute(address target,uint256 value,bytes calldata data) internal {
        (bool success,) = target.call{value:value}(data);
        require(success,"External call failed");
    }

    function destruct() external onlyOwner {
        selfdestruct(payable(IOwnable(msg.sender).owner()));
    }
}