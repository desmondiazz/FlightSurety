pragma solidity ^0.4.25;

contract AirlineControl {
    mapping(address=>Airline) airlines;

    struct Airline {
        AirlineStatus status;
        address[] votedBy;
        uint funds;
    }

    enum AirlineStatus {
        Pending,
        Registered,
        Operational
    }

    uint internal registeredAirlines = 0;

    modifier onlyPending(address account) {
        require(isPending(account), "Airline must be in pending status");
        _;
    }
    
    modifier onlyRegistered(address account) {
        require(isRegistered(account), "Airline must be in registered status");
        _;
    }
    
    modifier onlyOperational(address account) {
        require(isOperational(account), "Airline must be in operational status");
        _;
    }

    function isPending(address account) internal view returns(bool) {
        return airlines[account].status == AirlineStatus.Pending;
    }
    
    function isRegistered(address account) internal view returns(bool) {
        return airlines[account].status == AirlineStatus.Registered;
    }
    
    function isOperational(address account) internal view returns(bool) {
        return airlines[account].status == AirlineStatus.Operational;
    }

    function createPendingAirline(address account)
    internal
    {
        Airline memory newAirline = Airline(AirlineStatus.Pending,new address[](0),0);
        airlines[account] = newAirline;
    }

    function initialRegistration(address account) internal{
        require(registeredAirlines==0,'1 Airline already exists');
        Airline memory newAirline = Airline(AirlineStatus.Registered,new address[](0),0);
        airlines[account] = newAirline;
        registeredAirlines++;
    }

    function register(address account)
    internal
    onlyPending(account)
    {
        airlines[account].status = AirlineStatus.Registered;
        registeredAirlines++;
    }

    function vote(address account,address from)
    internal
    onlyPending(account)
    onlyRegistered(from)
    {
        bool duplicate = false;
        for (uint i = 0; i < airlines[account].votedBy.length; i++) {
            if (airlines[account].votedBy[i] == from) {
                duplicate = true;
                break;
            }
        }
        require(!duplicate, "Already voted from this airline");
        airlines[account].votedBy.push(from);
    }

    function addFunds(address account,uint amount)
    internal
    onlyRegistered(account)
    {
        airlines[account].funds += amount;
    }

    function registerFirstAirline(address account)
    public
    {
        require(registeredAirlines==0,'1st airline already registerd');
        airlines[account].status = AirlineStatus.Registered;
        registeredAirlines++;
    }

    function getRegisteredAirlinesCount()
    public
    view
    returns(uint){
        return registeredAirlines;
    }

    function makeAirlineOperational(address airline)
    public
    {
        airlines[airline].status = AirlineStatus.Operational;
    }
}