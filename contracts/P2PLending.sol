// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./core/TokenImplementer.sol";
import "./core/Calculator.sol";

contract P2PLending is TokenImplementer, Calculator {

    struct Depositor{
        uint256 amount; //amount of money deposited
        uint256 availableAmount; //amount of money available to be borrowed
    }

    struct CreditOptions{
        uint256 maxAmount;
        uint256 minAmount;
        uint256 interestRate;
        uint256 maxDuration;
        uint256 collateralRate;
        bool isActive;
    } 

    struct Borrower{
        uint256 collateralAmount; //amount of collateral deposited
        uint256 availableCollateralAmount; //amount of collateral available to be borrowed
        uint256 loanAmount;
        uint256 loanRepaid;
    }
    
    struct Credit{
        uint256 amount;
        uint256 repaidAmount;
        uint256 startedAt;
        uint256 endsAt;
        uint256 interestRate;
        uint256 collateralRate;
        address depositor;
        bool isActive;
    }

    
    
    //array of depositors
    mapping (address=> Depositor) public depositors;
    mapping (address=> CreditOptions[]) public creditOptions;
    mapping (address=> Borrower) public borrowers;
    mapping (address=> Credit[]) public credits;

    modifier onlyDepositor(){
        require(depositors[msg.sender].amount > 0, "You are not a depositor");
        _;
    }

    modifier onlyBorrower(){
        require(borrowers[msg.sender].collateralAmount > 0, "You are not a borrower");
        _;
    }

    modifier onlyValidCreditOption(address _depositor, uint256 _index){
        require(creditOptions[_depositor][_index].isActive , "Credit option is not active");
        _;
    }

    function _getAvailableCollateral(address _borrower) internal view returns(uint256){
        return borrowers[_borrower].availableCollateralAmount;
    }

    function _getRequiredCollateral(address _depositor, uint256 _index, uint256 _loanAmount) internal view returns(uint256){
        return calcCollateralAmount(_loanAmount, creditOptions[_depositor][_index].collateralRate);
    }
    function repay(uint _index, uint _amount) public onlyBorrower{
    

        require(credits[msg.sender][_index].isActive, "Amount is too high");
        uint256 leftAmount = credits[msg.sender][_index].amount - credits[msg.sender][_index].repaidAmount;

        uint256 timeDifference = block.timestamp - credits[msg.sender][_index].startedAt;
        uint256 interestRatePerSecond = calcInterestPerSecond(credits[msg.sender][_index].interestRate);
        uint256 interest = calcInterest(leftAmount, interestRatePerSecond, timeDifference);

        uint256 totalDebt = leftAmount + interest;

        require(_amount <= totalDebt, "Amount is too high");
        require(_amount >= interest, "Amount is too low");
        getTokensFromUser(msg.sender, _amount);
        uint256 amountAfterInterest = _amount - interest;
        borrowers[msg.sender].loanRepaid += amountAfterInterest;

        credits[msg.sender][_index].repaidAmount += amountAfterInterest;

        depositors[credits[msg.sender][_index].depositor].availableAmount += _amount;
        depositors[credits[msg.sender][_index].depositor].amount += interest;
    }

    function borrowMoney(
        address _depositor,
        uint256 _index,
        uint256 _amount,
        uint256 _duration    
    ) public onlyBorrower  onlyValidCreditOption(_depositor, _index){

        uint256 requiredCollateral =  _getRequiredCollateral(_depositor, _index, _amount) ;

       require(
       _getAvailableCollateral(msg.sender) >= requiredCollateral,
       "Collateral is too low"
        );
        require(
        creditOptions[_depositor][_index].maxAmount >= _amount && 
        creditOptions[_depositor][_index].minAmount <= _amount,
        "Amount is too high or too low"
        );
         require(
        creditOptions[_depositor][_index].maxDuration >= _duration,
        "Duration is too high"
        );
         require(
        depositors[_depositor].availableAmount >= _amount,
        "Amount is too high"
        );

    // Check if the duration is within the range of the credit option
    require(
      creditOptions[_depositor][_index].maxDuration >= _duration,
      "Duration is too high"
    );

    // Krediyi artık kullanidiriyoruz

    // Update depositor balances
    depositors[_depositor].availableAmount -= _amount;

    // Update borrower balances
    borrowers[msg.sender].availableCollateralAmount -= requiredCollateral;
    borrowers[msg.sender].loanAmount += _amount;

    // Add New Credit
    credits[msg.sender].push(Credit(
      _amount,
      0,
      block.timestamp,
      block.timestamp + _duration,
      creditOptions[_depositor][_index].interestRate,
      creditOptions[_depositor][_index].collateralRate,
      _depositor,
      true
    ));

    // Transfer the tokens to the borrower
    transferTokensToUser(msg.sender, _amount);
    
  }


    function depositMoney(uint256 _amount)public{

        require(_amount >= getMinimumAllowedDeposit() , "Amount is too low");
       
        getTokensFromUser(msg.sender, _amount);
        depositors[msg.sender].amount += _amount;
        depositors[msg.sender].availableAmount += _amount;

    }

    function withdrawMoney(uint256 _amount) public onlyDepositor{
        require(depositors[msg.sender].availableAmount >= _amount, "Amount is too high");
        depositors[msg.sender].availableAmount -= _amount;
        depositors[msg.sender].amount -= _amount;
        token.transfer(msg.sender, _amount);
    }

    function addCreditOptions(
        uint256 _maxAmount,
        uint256 _minAmount,
        uint256 _interestRate,
        uint256 _maxDuration,
        uint256 _collateralRate) public onlyDepositor{
            creditOptions[msg.sender].push(
                CreditOptions(
                _maxAmount,
                _minAmount,
                _interestRate,
                _maxDuration,
                _collateralRate,
                 true
                )
            );
        }

    function adjustCreditOption(uint256 index, bool isActive) public onlyDepositor{
        creditOptions[msg.sender][index].isActive = isActive;
    }

    function depositCollateral(uint256 _amount) public{
        require(_amount > getMinimumAllowedDeposit() , "Amount is too low");
        getCollateralFromUser(msg.sender, _amount);
        borrowers[msg.sender].collateralAmount += _amount;
        borrowers[msg.sender].availableCollateralAmount += _amount;
    }

    function withdrawCollateral(uint256 _amount) public{
        require(borrowers[msg.sender].availableCollateralAmount >= _amount, "Amount is too high");
        borrowers[msg.sender].availableCollateralAmount -= _amount;
        borrowers[msg.sender].collateralAmount -= _amount;
        collateral.transfer(msg.sender, _amount);
    }

}


