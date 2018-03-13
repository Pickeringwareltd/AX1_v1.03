pragma solidity ^0.4.18;

/**
 * This smart contract code is Copyright 2017 TokenMarket Ltd. For more information see https://tokenmarket.net
 *
 * Licensed under the Apache License, version 2.0: https://github.com/TokenMarketNet/ico/blob/master/LICENSE.txt
 *
 * Some implementation has been changed by Pickeringware ltd to achieve custom features
 */

import "./KYCPayloadDeserializer.sol";
import "./PickCrowdsale.sol";

/*
 * A crowdsale that allows only signed payload with server-side specified buy in limits.
 *
 * The token distribution happens as in the allocated crowdsale contract
 */
contract KYCCrowdsale is KYCPayloadDeserializer, PickCrowdsale {

  /* Server holds the private key to this address to decide if the AML payload is valid or not. */
  address public signerAddress;
  mapping(address => uint256) public refundable;
  mapping(address => bool) public refunded;
  mapping(address => bool) public blacklist;

  /* A new server-side signer key was set to be effective */
  event SignerChanged(address signer);
  event TokensReclaimed(address user, uint256 amount, uint256 datetime);
  event AddedToBlacklist(address user, uint256 datetime);
  event RemovedFromBlacklist(address user, uint256 datetime);
  event RefundCollected(address user, uint256 datetime);
  event TokensReleased(address agent, uint256 datetime, uint256 bounty, uint256 founders);

  /*
   * Constructor.
   */
  function KYCCrowdsale(uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet, address _beneficiary, address _buyer, address _founders, address _bounty, uint256 _softCap, uint256 _hardCap, PickToken _token) public
  PickCrowdsale(_startTime, _endTime, _rate, _wallet, _beneficiary, _buyer, _founders, _bounty, _softCap, _hardCap, _token)
  {}

  // This sets the token agent to the contract, allowing the contract to reclaim and burn tokens if necessary
  function setTokenAgent() external onlyOwner {
    // contractAddr = token.owner();
    // Give the sale contract rights to reclaim tokens
    token.setReleaseAgent();
  }

 /* 
  * This function was written by Pickeringware ltd to facilitate a refund action upon failure of KYC analysis
  * 
  * It simply allows the participant to withdraw his ether from the sale
  * Moves the crowdsale sliders accordingly
  * Reclaims the users tokens and burns them
  * Blacklists the user to prevent them from buying any more tokens
  *
  * Stage 1, 2, 3, & 4 are all collected from the database prior to calling this function
  * It allows us to calculate how many tokens need to be taken from each individual stage
  */
  function refundParticipant(address participant, uint256 _stage1, uint256 _stage2, uint256 _stage3, uint256 _stage4) external onlyOwner {
    require(balanceOf[participant] > 0);

    uint256 balance = balanceOf[participant];
    uint256 tokens = tokenBalanceOf[participant];

    balanceOf[participant] = 0;
    tokenBalanceOf[participant] = 0;

    // Refund the participant
    refundable[participant] = balance;

    // Move the crowdsale sliders
    weiRaised = weiRaised.sub(balance);
    tokensSent = tokensSent.sub(tokens);

    // Reclaim the participants tokens and burn them
    token.reclaimAllAndBurn(participant);

    // Blacklist participant so they cannot make further purchases
    blacklist[participant] = true;
    AddedToBlacklist(participant, now);

    stages.refundParticipant(_stage1, _stage2, _stage3, _stage4);

    TokensReclaimed(participant, tokens, now);
  }

  // Allows only the beneficiary to release tokens to people
  // This is needed as the token is owned by the contract, in order to mint tokens
  // therefore, the owner essentially gives permission for the contract to release tokens
  function releaseTokens(uint256 _bounty, uint256 _founders) onlyOwner external {
      // Unless the hardcap was reached, theremust be tokens to burn
      require(_bounty > 0 || tokensSent == hardCap);
      require(_founders > 0 || tokensSent == hardCap);

      burnFoundersTokens(_bounty, _founders);

      token.releaseTokenTransfer();

      canWithdraw = true;

      TokensReleased(msg.sender, now, _bounty, _founders);
  }
  
  // overriding Crowdsale#validPurchase to add extra KYC blacklist logic
  // @return true if investors can buy at the moment
  function validPurchase(uint256 _tokens) internal view returns (bool) {
    bool onBlackList;

    if(blacklist[msg.sender] == true){
      onBlackList = true;
    } else {
      onBlackList = false;
    }
    return super.validPurchase(_tokens) && !onBlackList;
  }

  // This is necessary for the blacklisted user to pull his ether from the contract upon being refunded
  function collectRefund() external {
    require(refundable[msg.sender] > 0);
    require(refunded[msg.sender] == false);

    uint256 theirwei = refundable[msg.sender];
    refundable[msg.sender] = 0;
    refunded[msg.sender] == true;

    msg.sender.transfer(theirwei);

    RefundCollected(msg.sender, now);
  }

  /*
   * A token purchase with anti-money laundering and KYC checks
   * This function takes in a dataframe and EC signature to verify if the purchaser has been verified
   * on the server side of our application and has therefore, participated in KYC. 
   * Upon registering to the site, users are supplied with a signature allowing them to purchase tokens, 
   * which can be revoked at any time, this containst their ETH address, a unique ID and the min and max 
   * ETH that user has stated they will purchase. (Any more than the max may be subject to AML checks).
   */
  function buyWithKYCData(bytes dataframe, uint8 v, bytes32 r, bytes32 s) public payable {

      bytes32 hash = sha256(dataframe);

      var (whitelistedAddress, customerId, minETH, maxETH) = getKYCPayload(dataframe);

      // Check that the KYC data is signed by our server
      require(ecrecover(hash, v, r, s) == signerAddress);

      // Check that the user is using his own signature
      require(whitelistedAddress == msg.sender);

      // Check they are buying within their limits - THIS IS ONLY NEEDED IF SPECIFIED BY REGULATORS
      uint256 weiAmount = msg.value;
      uint256 max = maxETH;
      uint256 min = minETH;

      require(weiAmount < (max * 1 ether));
      require(weiAmount > (min * 1 ether));

      buyTokens(customerId);
  }  

  /// @dev This function can set the server side address
  /// @param _signerAddress The address derived from server's private key
  function setSignerAddress(address _signerAddress) external onlyOwner {
    // EC rcover returns 0 in case of error therefore, this CANNOT be 0.
    require(_signerAddress != 0);
    signerAddress = _signerAddress;
    SignerChanged(signerAddress);
  }

  function removeFromBlacklist(address _blacklisted) external onlyOwner {
    require(blacklist[_blacklisted] == true);
    blacklist[_blacklisted] = false;
    RemovedFromBlacklist(_blacklisted, now);
  }

}