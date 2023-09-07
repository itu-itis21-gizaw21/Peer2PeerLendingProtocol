//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Calculator{
    uint256 constant DECIMAL = 10 ** 18;
    uint256 constant SECONDS_IN_YEAR = 365 * 24 * 60 * 60;

    function calcInterestPerSecond(uint256 interestRate) public pure returns(uint256){
        return interestRate / SECONDS_IN_YEAR;
    }

    function calcInterest(uint256 amount, uint256 interestRate, uint256 duration) public pure returns(uint256){
        return amount * interestRate * duration / DECIMAL;
    }

    function calcCollateralAmount(uint256 amount, uint256 collateralRate) public pure returns(uint256){
        return amount * collateralRate / DECIMAL;
    }
}