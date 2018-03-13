/**
 * This contract has been written by Pickeringware ltd in some areas to facilitate custom crwodsale features
 */

pragma solidity ^0.4.18;

import "./MintableToken.sol";


/**
 * The AML Token
 *
 * This subset of MintableCrowdsaleToken gives the Owner a possibility to
 * reclaim tokens from a participant before the token is released
 * after a participant has failed a prolonged AML process.
 *
 * It is assumed that the anti-money laundering process depends on blockchain data.
 * The data is not available before the transaction and not for the smart contract.
 * Thus, we need to implement logic to handle AML failure cases post payment.
 * We give a time window before the token release for the token sale owners to
 * complete the AML and claw back all token transactions that were
 * caused by rejected purchases.
 */
contract AMLToken is MintableToken {

  // An event when the owner has reclaimed non-released tokens
  event ReclaimedAllAndBurned(address claimedBy, address fromWhom, uint amount);

    // An event when the owner has reclaimed non-released tokens
  event ReclaimAndBurned(address claimedBy, address fromWhom, uint amount);

  /// @dev Here the owner can reclaim the tokens from a participant if
  ///      the token is not released yet. Refund will be handled in sale contract.
  /// We also burn the tokens in the interest of economic value to the token holder
  /// @param fromWhom address of the participant whose tokens we want to claim
  function reclaimAllAndBurn(address fromWhom) public onlyReleaseAgent inReleaseState(false) {
    uint amount = balanceOf(fromWhom);    
    balances[fromWhom] = 0;
    totalSupply = totalSupply.sub(amount);
    
    ReclaimedAllAndBurned(msg.sender, fromWhom, amount);
  }

  /// @dev Here the owner can reclaim the tokens from a participant if
  ///      the token is not released yet. Refund will be handled in sale contract.
  /// We also burn the tokens in the interest of economic value to the token holder
  /// @param fromWhom address of the participant whose tokens we want to claim
  function reclaimAndBurn(address fromWhom, uint256 amount) public onlyReleaseAgent inReleaseState(false) {       
    balances[fromWhom] = balances[fromWhom].sub(amount);
    totalSupply = totalSupply.sub(amount);
    
    ReclaimAndBurned(msg.sender, fromWhom, amount);
  }
}