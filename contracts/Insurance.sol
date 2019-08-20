pragma solidity ^0.4.25;

contract Insurance {
    mapping(bytes32 => uint) private insurances;
    mapping(bytes32 => uint) private payouts;

    function buyInsurance(bytes32 key, uint amount) internal {
        // prevent from buying same insurance twice
        require(insurances[key] == 0, "Already bought this insurance");
        insurances[key] = amount;
    }

    function creditPayout(bytes32 key,uint amount) internal
    {
        payouts[key] = amount;
    }

    function refund(bytes32 key) internal returns(uint) {
        uint amount = payouts[key];
        delete payouts[key];
        return amount;
    }

    function getInsurance(bytes32 key)
    internal
    view
    returns(uint)
    {
        return insurances[key];
    }
    
    function getPayout(bytes32 key)
    internal
    view
    returns(uint)
    {
        return payouts[key];
    }

    function removeInsurance(bytes32 key)
    internal
    {
        delete insurances[key];
    }
}
