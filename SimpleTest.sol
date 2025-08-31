// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Ultra-simple contract to test deployment
contract SimpleTest {
    uint256 public testNumber;
    string public testString;
    
    constructor() {
        testNumber = 42;
        testString = "Hello Remix";
    }
    
    function setNumber(uint256 _number) external {
        testNumber = _number;
    }
    
    function setString(string memory _text) external {
        testString = _text;
    }
    
    function getValues() external view returns (uint256, string memory) {
        return (testNumber, testString);
    }
}
