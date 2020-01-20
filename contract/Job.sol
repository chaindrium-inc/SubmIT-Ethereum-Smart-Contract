pragma solidity >=0.5.1 <0.6.0;
import './SafeMath.sol';
/**
 * this is version v2 of the smart contract 
 * for graphics delivery on submit
 */
contract Job {

    enum state {
        CREATED, 
        DEPOSITED, 
        SUBMITTED, 
        CHANGE_REQUESTED, 
        FINISHED, 
        CANCELED
    }
    
    /**
     * the address that created this job
     * 
     * also gets the percentage cut of the submission money
     */
    address payable _creator;
    
    /**
     * cut amount, is given to the creator, is calculated at contract creation
     */
    uint256 _cut_amount;
    
    /**
     * the address that deposited ether to this job
     */
    address payable _buyer;
    
    
    /**
     * expectted deposit amount, is calculated at contract creation
     */
    uint256 _expected_deposit;
    
    
    /**
     * the address that is funded with the money on this job
     * after the buyer accepted the submission
     */
    address payable _seller;
    
    /**
     * the name given by the seller of this job
     */
    string _name;
    
    /**
     * The amount in ether the seller expects to be getting
     */
    uint256 _amount;
    
    /**
     * the current state of this job
     */
    state _state;
    
    /**
     * hash of the last submission
     */
    string _last_submission_hash;
    
    /**
     * string reason for rejecting this job
     */
    string _rejection_reason;
    
    /**
     * this contract should only be editable by the creator
     */
    modifier creator_only() {
        require(msg.sender == _creator);
        _;
    }
    
    /**
     * constructor
     * 
     * @param name the given name
     * @param seller the seller 
     * @param amount the amount in ether
     * @param cut_percentage the amount (in %) that the creator gets as cut, range(0,100)
     * @param deposit_percentage the amount (int %) that the buyer needs to deposit before the seller will start working on this job
     */
    constructor(string memory name, address payable seller, uint256 amount, uint256 cut_percentage, uint256 deposit_percentage) public {
        require(0 <= cut_percentage && cut_percentage <= 100, "Job: percentages need to be between 0 and 100");
        require(0 <= deposit_percentage && deposit_percentage <= 100, "Job: percentages need to be between 0 and 100");
        
        _state = state.CREATED;
        _creator = msg.sender;
        _name = name;
        
        _seller = seller;
        
        _amount = amount;
        //due to flooring with integer precision we multiply by factor and then devide by 100 and not the other way around
        _expected_deposit = SafeMath.div(SafeMath.mul(amount, deposit_percentage), 100);
        _cut_amount = SafeMath.div(SafeMath.mul(amount, cut_percentage), 100);
    }
    
    /**
     * function () is syntatctic "sugar" for the function that is called once a payment is received by this contract
     * 
     * this function is called when a payment is made to the address of this contract
     * this function should be as lightweight as possible, because otherwise fees just rise up
     * therefore the _expected_deposit is already calculated in the constructor
     * 
     * @dev This function might fail to accept payments. Have a look at
     * https://ethereum.stackexchange.com/questions/29553/fallback-function-uses-too-much-gas
     */
    function () external payable {
        if (_state == state.CREATED) {
            //check that at least the expected amount was deposited
            require(msg.value >= _expected_deposit, "Job: deposit-amount less than expected deposit-amount");
            //store the buyer
            _buyer = msg.sender;
            //set the state accordingly
            _state = state.DEPOSITED;
        } else if (_state == state.SUBMITTED) {
            //check that the payment was enough
            require(address(this).balance >= _amount,"Job: final-payment + deposit-amount less than expected amount");
            //send the cut to the creator
            if (_cut_amount > 0) {
                _creator.transfer(_cut_amount);
            }
            //pay the seller with the current balance (this is deposit plus msg.value)
            _seller.transfer(address(this).balance);
            //set the state to finished
            _state = state.FINISHED;
        } else {
            revert("Job: this contract is in the wrong state to be payed");
        }
    }
    
    
    /**
     * this function changes the internal state from 'deposited' to 'submitted'
     * 
     * @param submission_hash the hash of the submission, might be multiple files
     */
    function submit (string memory submission_hash) creator_only public {
        require(_state == state.DEPOSITED || _state == state.CHANGE_REQUESTED);
        _last_submission_hash = submission_hash;
        _state = state.SUBMITTED;
    }
    
    /**
     * this function updates the state from submitted to change_requested 
     */
    function request_change() creator_only public {
        require(_state == state.SUBMITTED);
        _state = state.CHANGE_REQUESTED;
    }
    
    /**
     * returns the money to the buyer
     */
    function cancel (string memory reason) creator_only public {
        require(_state != state.SUBMITTED);
        require(_state != state.CHANGE_REQUESTED);
        if(address(this).balance > 0) {
            _buyer.transfer(address(this).balance);
        }
        _rejection_reason = reason;
    }
    
    /**
     * returns current state
     */
    function get_state() public view returns(state) {
        return _state;
    }
    
    /**
     * returns the person that made the first payment
     */
    function get_buyer() public view returns(address) {
        return _buyer;
    }
    
    /**
     * returns the amount that is expected form this contract
     */
    function get_deposit_amount() public view returns (uint256) {
        return _expected_deposit;
    }
    
    /**
     * returns the submission_hash
     */
    function get_submission_hash() public view returns(string memory) {
        return _last_submission_hash;
    }
    
    /**
     * returns the rejection reason
     */
    function get_rejection_reason() public view returns(string memory) {
        return _rejection_reason;
    }
}