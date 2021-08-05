pragma solidity ^0.5.8;

import "./Context.sol";
import "./ITRC20.sol";
import "./BaseTRC20.sol";

contract KODX is ITRC20, TRC20Detailed {
    constructor(address gr) public TRC20Detailed("KING OF DEFI", "KODX", 6){
        require(gr != address(0), "invalid gr");
        _mint(gr, 33000 * 10 ** 6);
    }
}