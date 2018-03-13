pragma solidity ^0.4.18;

import './SafeMath.sol';

/*
 * SaleStagesLib is a part of Pickeringware ltd's smart contracts
 * Its intended use is to abstract the implementation of stages away from a contract to ease deployment and codel length
 * It uses a stage struct to store specific details about each stage
 * It has several functions which are used to get/change this data
*/

library SaleStagesLib {
	using SafeMath for uint256;

	// Stores Stage implementation
	struct Stage{
        uint256 deadline;
        uint256 tokenPrice;
        uint256 tokensSold;
        uint256 minimumBuy;
        uint256 cap;
	}

	// The struct that is stored by the contract
	// Contains counter to iterate through map of stages
	struct StageStorage {
 		mapping(uint8 => Stage) stages;
 		uint8 stageCount;
	}

	// Initiliase the stagecount to 0
	function init(StageStorage storage self) public {
		self.stageCount = 0;
	}

	// Create stage adds new stage to stages map and increments stage count
	function createStage(
		StageStorage storage self, 
		uint8 _stage, 
		uint256 _deadline, 
		uint256 _price,
		uint256 _minimum,
		uint256 _cap
	) internal {
        // Ensures stages cannot overlap each other
        uint8 prevStage = _stage - 1;
        require(self.stages[prevStage].deadline < _deadline);
		
        self.stages[_stage].deadline = _deadline;
		self.stages[_stage].tokenPrice = _price;
		self.stages[_stage].tokensSold = 0;
		self.stages[_stage].minimumBuy = _minimum;
		self.stages[_stage].cap = _cap;
		self.stageCount = self.stageCount + 1;
	}

   /*
    * Crowdfund state machine management.
    *
    * We make it a function and do not assign the result to a variable, so there is no chance of the variable being stale.
    * Each one of these conditions checks if the time has passed into another stage and therefore, act as appropriate
    */
    function getStage(StageStorage storage self) public view returns (uint8 stage) {
        uint8 thisStage = self.stageCount + 1;

        for (uint8 i = 0; i < thisStage; i++) {
            if(now <= self.stages[i].deadline){
                return i;
            }
        }

        return thisStage;
    }

    // Both of the below are checked on the overridden validPurchase() function
    // Check to see if the tokens they're about to purchase is above the minimum for this stage
    function checkMinimum(StageStorage storage self, uint8 _stage, uint256 _tokens) internal view returns (bool isValid) {
    	if(_tokens < self.stages[_stage].minimumBuy){
    		return false;
    	} else {
    		return true;
    	}
    }

    // Checks to see if the tokens they're about to purchase is below the cap for this stage
    function checkCap(StageStorage storage self, uint8 _stage, uint256 _tokens) internal view returns (bool isValid) {
    	uint256 totalTokens = self.stages[_stage].tokensSold.add(_tokens);

    	if(totalTokens > self.stages[_stage].cap){
    		return false;
    	} else {
    		return true;
    	}
    }

    // Refund a particular participant, by moving the sliders of stages he participated in
    function refundParticipant(StageStorage storage self, uint256 stage1, uint256 stage2, uint256 stage3, uint256 stage4) internal {
        self.stages[1].tokensSold = self.stages[1].tokensSold.sub(stage1);
        self.stages[2].tokensSold = self.stages[2].tokensSold.sub(stage2);
        self.stages[3].tokensSold = self.stages[3].tokensSold.sub(stage3);
        self.stages[4].tokensSold = self.stages[4].tokensSold.sub(stage4);
    }
    
	
}