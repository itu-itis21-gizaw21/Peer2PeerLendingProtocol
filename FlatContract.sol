// Sources flattened with hardhat v2.17.1 https://hardhat.org

// SPDX-License-Identifier: MIT AND UNLICENSED

// File contracts/access/Ownable.sol

// Original license: SPDX_License_Identifier: UNLICENSED
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


// File contracts/core/Settings.sol

// Original license: SPDX_License_Identifier: MIT

pragma solidity 0.8.19;

contract Settings is Ownable{

    uint256 public minimumAllowedDeposit;
    mapping( address => uint256) private minimumAllowedDeposits;
    uint256 private exchangeRate;

    function adjustSpecificAddress(address _address, uint256 _minimumAllowedDeposit) public onlyOwner{
        minimumAllowedDeposits[_address] = _minimumAllowedDeposit;
    }

    function setMinimumAllowedDeposit(uint256 _minimumAllowedDeposit) public onlyOwner{
        minimumAllowedDeposit = _minimumAllowedDeposit;
    }

    function getSpecificMinimumDeposit(address _address) public view returns(uint256){
        return minimumAllowedDeposits[_address];
    }

    //Get the minimum allowed deposit
    function getMinimumAllowedDeposit() public view returns (uint256){
        return getSpecificMinimumDeposit(msg.sender) != 0 ?
            getSpecificMinimumDeposit(msg.sender) : minimumAllowedDeposit;
    }
}


// File contracts/interfaces/IERC20.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity 0.8.19;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// File contracts/core/TokenImplementer.sol

// Original license: SPDX_License_Identifier: MIT

pragma solidity 0.8.19;


contract TokenImplementer is Settings{

    address public allowedToken;
    IERC20 public token;

    address public collateralToken;
    IERC20 public collateral;

    //Adjustt the allowed token
    function setAllowedToken(address _tokenAddress) public onlyOwner{
        allowedToken = _tokenAddress;
        token = IERC20(allowedToken);
    }

    //Get the allowed token
    function getAllowedTokenFromUser(address from, uint256 amount) public view returns(bool){
        return token.allowance(from, address(this)) >= amount;
    }

    function getTokensFromUser(address from, uint256 amount) public{
        require(getAllowedTokenFromUser(from, amount), "Not enough allowance");
        token.transferFrom(from, address(this), amount);
    }

    function setCollateralToken(address _collateralToken) public onlyOwner{
        collateralToken = _collateralToken;
        collateral = IERC20(collateralToken);
    }

    function getCollateralFromUser(address from, uint256 amount) public view returns(bool){
        return collateral.allowance(from, address(this)) >= amount;
    }
}


// File contracts/P2PLending.sol

// Original license: SPDX_License_Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract P2PLending is TokenImplementer {

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
    
    
    //array of depositors
    mapping (address=> Depositor) public depositors;
    mapping (address=> CreditOptions[]) public creditOptions;
    mapping (address=> Borrower) public borrowers;

    modifier onlyDepositor(){
        require(depositors[msg.sender].amount > 0, "You are not a depositor");
        _;
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
