pragma solidity ^0.4.18;

import './PickToken.sol';
import './CappedCrowdsale.sol';
import './SaleStagesLib.sol';
import './SafeMath.sol';


/*
 * PickCrowdsale and PickToken are a part of Pickeringware ltd's smart contracts
 * This uses the SaleStageLib which is also a part of Pickeringware ltd's smart contracts
 * We create the stages initially in the constructor such that stages cannot be added after the sale has started
 * We then pre-allocate necessary accounts prior to the sale starting
 * This contract implements the stages lib functionality with overriding functions for stages implementation
*/
contract PickCrowdsale is CappedCrowdsale {

  using SaleStagesLib for SaleStagesLib.StageStorage;
  using SafeMath for uint256;

  SaleStagesLib.StageStorage public stages;

  bool preallocated = false;
  bool stagesSet = false;
  address private founders;
  address private bounty;
  address private buyer;
  uint256 public burntBounty;
  uint256 public burntFounder;

  event ParticipantWithdrawal(address participant, uint256 amount, uint256 datetime);

  modifier onlyOnce(bool _check) {
    if(_check) {
      revert();
    }
    _;
  }

  function PickCrowdsale(uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet, address _beneficiary, address _buyer, address _founders, address _bounty, uint256 _softCap, uint256 _hardCap, PickToken _token)
  	CappedCrowdsale(_startTime, _endTime, _rate, _wallet, _beneficiary, _softCap, _hardCap, _token)
     public { 
    stages.init();
    stages.createStage(0, _startTime, 0, 0, 0);
    founders = _founders;
    bounty = _bounty;
    buyer = _buyer;
  }

  function setPreallocations() external onlyOwner onlyOnce(preallocated) {
    preallocate(buyer, 1250000, 10000000000);
    preallocate(founders, 1777777, 0);
    preallocate(bounty, 444445, 0);
    preallocated = true;
  }

  function setStages() external onlyOwner onlyOnce(stagesSet) {
    stages.createStage(1, startTime.add(5 minutes), 10000000000, 9000000, 125000000000);  //Deadline 1 day (86400)  after start - price: 0.001  - min: 90 - cap: 1,250,000
    stages.createStage(2, startTime.add(10 minutes), 11000000000, 6000000, 300000000000); //Deadline 2 days (172800) after start - price: 0.0011 - min: 60 - cap: 3,000,000 
    stages.createStage(3, startTime.add(15 minutes), 12000000000, 100000, 575000000000);  //Deadline 4 days (345600) after start - price: 0.0012 - cap: 5,750,000 
    stages.createStage(4, endTime, 15000000000, 100000, 2000000000000);               //Deadline 1 week after start - price: 0.0015 - cap: 20,000,000 
    stagesSet = true;
  }

  // Creates new stage for the crowdsale
  // Can ONLY be called by the owner of the contract as should never change after creating them on initialisation
  function createStage(uint8 _stage, uint256 _deadline, uint256 _price, uint256 _minimum, uint256 _cap ) internal onlyOwner {
    stages.createStage(_stage, _deadline, _price, _minimum, _cap);
  }

  // Get stage is required to rethen the stage we are currently in
  // This is necessary to check the stage details listed in the below functions
  function getStage() public view returns (uint8 stage) {
    return stages.getStage();
  }

  function getStageDeadline(uint8 _stage) public view returns (uint256 deadline) { 
    return stages.stages[_stage].deadline;
  }

  function getStageTokensSold(uint8 _stage) public view returns (uint256 sold) { 
    return stages.stages[_stage].tokensSold;
  }

  function getStageCap(uint8 _stage) public view returns (uint256 cap) { 
    return stages.stages[_stage].cap;
  }

  function getStageMinimum(uint8 _stage) public view returns (uint256 min) { 
    return stages.stages[_stage].minimumBuy;
  }

  function getStagePrice(uint8 _stage) public view returns (uint256 price) { 
    return stages.stages[_stage].tokenPrice;
  }

  // @Override crowdsale contract to check the current stage price
  // @return tokens investors are due to recieve
  function tokensToRecieve(uint256 _wei) internal view returns (uint256 tokens) {
    uint8 stage = getStage();
    uint256 price = getStagePrice(stage);

    return _wei.div(price);
  }

  // overriding Crowdsale validPurchase to add extra stage logic
  // @return true if investors can buy at the moment
  function validPurchase(uint256 _tokens) internal view returns (bool) {
    bool isValid = false;
    uint8 stage = getStage();

    if(stages.checkMinimum(stage, _tokens) && stages.checkCap(stage, _tokens)){
      isValid = true;
    }

    return super.validPurchase(_tokens) && isValid;
  }

  // Override crowdsale finalizeSale function to log balance change plus tokens sold in that stage
  function finalizeSale(uint256 _weiAmount, uint256 _tokens, uint128 _buyer) internal {
    // Collect ETH and send them a token in return
    balanceOf[msg.sender] = balanceOf[msg.sender].add(_weiAmount);
    tokenBalanceOf[msg.sender] = tokenBalanceOf[msg.sender].add(_tokens);
    balancePerID[_buyer] = balancePerID[_buyer].add(_weiAmount);

    // update state
    weiRaised = weiRaised.add(_weiAmount);
    tokensSent = tokensSent.add(_tokens);

    uint8 stage = getStage();
    stages.stages[stage].tokensSold = stages.stages[stage].tokensSold.add(_tokens);
  }

  /**
   * Preallocate tokens for the early investors.
   */
  function preallocate(address receiver, uint tokens, uint weiPrice) internal {
    uint decimals = token.decimals();
    uint tokenAmount = tokens * 10 ** decimals;
    uint weiAmount = weiPrice * tokens; 

    presaleWeiRaised = presaleWeiRaised.add(weiAmount);
    tokensSent = tokensSent.add(tokenAmount);
    tokenBalanceOf[receiver] = tokenBalanceOf[receiver].add(tokenAmount);

    presaleBalanceOf[receiver] = presaleBalanceOf[receiver].add(weiAmount);

    produceTokens(receiver, weiAmount, tokenAmount);
  }

  // If the sale is unsuccessful (has halted or reached deadline and didnt reach softcap)
  // Allows participants to withdraw their balance
  function unsuccessfulWithdrawal() external {
      require(balanceOf[msg.sender] > 0);
      require(hasEnded() && tokensSent < softCap || hasHalted());
      uint256 withdrawalAmount;

      withdrawalAmount = balanceOf[msg.sender];
      balanceOf[msg.sender] = 0; 

      msg.sender.transfer(withdrawalAmount);
      assert(balanceOf[msg.sender] == 0);

      ParticipantWithdrawal(msg.sender, withdrawalAmount, now);
  }

  // Burn the percentage of tokens not sold from the founders and bounty wallets
  // Must do it this way as solidity doesnt deal with decimals
  function burnFoundersTokens(uint256 _bounty, uint256 _founders) internal {
      require(_founders < 177777700000);
      require(_bounty < 44444500000);

      // Calculate the number of tokens to burn from founders and bounty wallet
      burntFounder = _founders;
      burntBounty = _bounty;

      token.reclaimAndBurn(founders, burntFounder);
      token.reclaimAndBurn(bounty, burntBounty);
  }
}