pragma solidity ^0.4.18;
/**
 * This smart contract code is Copyright 2017 TokenMarket Ltd. For more information see https://tokenmarket.net
 *
 * Licensed under the Apache License, version 2.0: https://github.com/TokenMarketNet/ico/blob/master/LICENSE.txt
 */


import "./BytesDeserializer.sol";

/**
 * A mix-in contract to decode AML payloads.
 *
 * @notice This should be a library, but for the complexity and toolchain fragility risks involving of linking library inside library, we put this as a mix-in.
 */
contract KYCPayloadDeserializer {

  using BytesDeserializer for bytes;

  /**
   * This function takes the dataframe and unpacks it
   * We have the users ETH address for verification that they are using their own signature
   * CustomerID so we can track customer purchases
   * Min/Max ETH to invest for AML/CTF purposes - this can be supplied by the user OR by the back-end.
   */
  function getKYCPayload(bytes dataframe) public pure returns(address whitelistedAddress, uint128 customerId, uint32 minEth, uint32 maxEth) {
    address _whitelistedAddress = dataframe.sliceAddress(0);
    uint128 _customerId = uint128(dataframe.slice16(20));
    uint32 _minETH = uint32(dataframe.slice4(36));
    uint32 _maxETH = uint32(dataframe.slice4(40));
    return (_whitelistedAddress, _customerId, _minETH, _maxETH);
  }

}