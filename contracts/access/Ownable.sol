// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract Ownable{
    address private owner;

    modifier onlyOwner(){
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(){
        owner = msg.sender;
    }

    function setOwner(address newOwner) public onlyOwner(){    
        owner = newOwner;
    }
}