pragma solidity ^0.5.10;
// SPDX-License-Identifier: MIT
contract ownable {
    address payable owner;
    modifier isOwner {
        require(owner == msg.sender,"XXYou should be owner to call this function.XX");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function changeOwner(address payable _owner) public isOwner {
        require(owner != _owner,"XXYou must enter a new value.XX");
        owner = _owner;
    }

    function getOwner() public view returns(address) {
        return(owner);
    }

}