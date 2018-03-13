pragma solidity ^0.4.18;

import './PickToken.sol';
import './SafeMath.sol';
import './Stoppable.sol';

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 *
 * This base contract has been changed in certain areas by Pickeringware ltd to facilitate extra functionality
 */
contract Crowdsale is Stoppable {
  using SafeMath for uint256;

  // The token being sold
  PickToken public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where funds are collected
  address public wallet;
  address public contractAddr;
  
  // how many token units a buyer gets per wei
  uint256 public rate;

  // amount of raised money in wei
  uint256 public weiRaised;
  uint256 public presaleWeiRaised;

  // amount of tokens sent
  uint256 public tokensSent;

  // These store balances of participants by ID, address and in wei, pre-sale wei and tokens
  mapping(uint128 => uint256) public balancePerID;
  mapping(address => uint256) public balanceOf;
  mapping(address => uint256) public presaleBalanceOf;
  mapping(address => uint256) public tokenBalanceOf;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount, uint256 datetime);

  /*
   * Contructor
   * This initialises the basic crowdsale data
   * It transfers ownership of this token to the chosen beneficiary 
  */
  function Crowdsale(uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet, PickToken _token) public {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_rate > 0);
    require(_wallet != address(0));

    token = _token;
    startTime = _startTime;
    endTime = _endTime;
    rate = _rate;
    wallet = _wallet;
    transferOwnership(_wallet);
  }

  /*
   * This method has been changed by Pickeringware ltd
   * We have split this method down into overidable functions which may affect how users purchase tokens
   * We also take in a customerID (UUiD v4) which we store in our back-end in order to track users participation
  */ 
  function buyTokens(uint128 buyer) internal stopInEmergency {
    require(buyer != 0);

    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 tokens = tokensToRecieve(weiAmount);

    // MUST DO REQUIRE AFTER tokens are calculated to check for cap restrictions in stages
    require(validPurchase(tokens));

    // We move the participants sliders before we mint the tokens to prevent re-entrancy
    finalizeSale(weiAmount, tokens, buyer);
    produceTokens(msg.sender, weiAmount, tokens);
  }

  // This function was created to be overridden by a parent contract
  function produceTokens(address buyer, uint256 weiAmount, uint256 tokens) internal {
    token.mint(buyer, tokens);
    TokenPurchase(msg.sender, buyer, weiAmount, tokens, now);
  }

  // This was created to be overriden by stages implementation
  // It will adjust the stage sliders accordingly if needed
  function finalizeSale(uint256 _weiAmount, uint256 _tokens, uint128 _buyer) internal {
    // Collect ETH and send them a token in return
    balanceOf[msg.sender] = balanceOf[msg.sender].add(_weiAmount);
    tokenBalanceOf[msg.sender] = tokenBalanceOf[msg.sender].add(_tokens);
    balancePerID[_buyer] = balancePerID[_buyer].add(_weiAmount);

    // update state
    weiRaised = weiRaised.add(_weiAmount);
    tokensSent = tokensSent.add(_tokens);
  }
  
  // This was created to be overridden by the stages implementation
  // Again, this is dependent on the price of tokens which may or may not be collected in stages
  function tokensToRecieve(uint256 _wei) internal view returns (uint256 tokens) {
    return _wei.div(rate);
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function successfulWithdraw() external onlyOwner stopInEmergency {
    require(hasEnded());

    owner.transfer(weiRaised);
  }

  // @return true if the transaction can buy tokens
  // Receives tokens to send as variable for custom stage implementation
  // Has an unused variable _tokens which is necessary for capped sale implementation
  function validPurchase(uint256 _tokens) internal view returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  // @return true if crowdsale event has ended
  function hasEnded() public view returns (bool) {
    return now > endTime;
  }
}
