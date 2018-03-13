pragma solidity ^0.4.18;

/*
 * This token is part of Pickeringware ltds smart contracts
 * It is used to specify certain details about the token upon release
 */

import './AMLToken.sol';

contract PickToken is AMLToken {
  string public name = "AX1 Mining token";
  string public symbol = "AX1";
  uint8 public decimals = 5;
}