pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";
/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData flightSuretyData;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint private constant REGISTERING_AIRLINE_WITHOUT_CONSENSUS = 4;
    uint private constant MAX_INSURANCE = 1 ether;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    event PendingAirlineCreated(address indexed account);
    event AirlineRegistered(address indexed account);
    event AirlineVoted(address indexed account, uint votedCount);
    event AirlineFunded(address indexed account, uint funds);
    event AirlineIsOperational(address indexed airline);
    event FlightRegistered(string flight,address airline);



    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
         // Modify to call data contract's status
        require(isOperational(), "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsPendingAirline(address airline){
        require(flightSuretyData.isPendingAirline(airline),'Airline needs to be in pending state');
        _;
    }

    modifier requireIsRegisterdAirline(address airline){
        require(flightSuretyData.isRegisteredAirline(airline),'Airline needs to be registered');
        _;
    }

    modifier airlineIsOperational(address airline){
        require(flightSuretyData.isAirlineOperational(airline),'Airline must be operational');
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address dataContractAddress) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public returns(bool) {
        return flightSuretyData.isOperational();
    }

    function isFlightStatusToPayout(bytes32 flightKey)
    internal
    view
    returns(bool)
    {
        uint8 statusCode = flights[flightKey].statusCode;
        return (
            statusCode == STATUS_CODE_LATE_AIRLINE ||
            statusCode == STATUS_CODE_LATE_TECHNICAL
        );
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline(address airline)
    external
    requireIsOperational
    requireIsPendingAirline(airline)
    requireIsRegisterdAirline(msg.sender)
    {
        uint registeredCount = flightSuretyData.registeredAirlinesCount();
        if(registeredCount < REGISTERING_AIRLINE_WITHOUT_CONSENSUS){
            _registerAirline(airline);
        } else {
            _voteAirline(airline,registeredCount.div(2));
        }
    }

    function registerPendingAirline(address airline)
    external
    requireIsOperational
    {
        _createPendingAirline(airline);
    }

    function addFunds()
    public
    payable
    requireIsOperational
    requireIsRegisterdAirline(msg.sender)
    {
        uint funds = flightSuretyData.addFund(msg.sender, msg.value);
        if(funds >= 10 ether ){
            _makeAirlineOperational(msg.sender);
        }
        emit AirlineFunded(msg.sender, funds);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight(string memory flight, uint timestamp)
    public
    requireIsOperational
    airlineIsOperational(msg.sender)
    {
        bytes32 flightKey = getFlightKey(msg.sender,flight,timestamp);
        Flight memory newFlight = Flight(true, STATUS_CODE_UNKNOWN, now, msg.sender);
        flights[flightKey] = newFlight;
        emit FlightRegistered(flight,msg.sender);
    }

    function buyInsurance(string memory flight, uint timestamp,address airline)
    public
    payable
    requireIsOperational
    airlineIsOperational(airline)
    {
        require(msg.value > 0 ether,'Insurance Amount should be greater then 0 Ether');
        require(msg.value <= MAX_INSURANCE, "Up to 1 ether for purchasing flight insurance");
        bytes32 insuranceKey = _buildInsuranceKey(msg.sender, flight, timestamp);
        flightSuretyData.buy(insuranceKey, msg.value);
    }

    function getInsurance(string memory flight, uint timestamp)
    public
    view
    returns(uint)
    {
        bytes32 insuranceKey = _buildInsuranceKey(msg.sender, flight, timestamp);
        return flightSuretyData.getinsurance(insuranceKey);
    }


    function getInsurancePayout(string memory flight, uint timestamp)
    public
    view
    returns(uint)
    {
        bytes32 insuranceKey = _buildInsuranceKey(msg.sender, flight, timestamp);
        return flightSuretyData.getinsurancePayout(insuranceKey);
    }

    function validateInsurance(bytes32 key)
    internal
    returns(bool)
    {
        uint amount = flightSuretyData.getinsurance(key);
        return amount > 0 ether;
    }

    function validateWithdrawRequest(bytes32 key)
    internal
    returns(bool)
    {
        uint amount = flightSuretyData.getinsurancePayout(key);
        return amount > 0 ether;
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */

    function processFlightStatus(address airline,string memory flight,uint256 timestamp,uint8 statusCode) internal {
        bytes32 flightKey = getFlightKey(airline,flight,timestamp);
        flights[flightKey].statusCode = statusCode;
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus ( address airline, string flight, uint256 timestamp)
    external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({ requester: msg.sender, isOpen: true });
        emit OracleRequest(index, airline, flight, timestamp);
    }

    function getFlightStatusVotes(uint8 index,address airline,string flight,uint256 timestamp,uint8 statusCode)
    public
    view
    returns(uint)
    {
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        return oracleResponses[key].responses[statusCode].length;
    }

    function getFlightStatus(address airline,string memory flight,uint256 timestamp)
    public
    view
    returns(uint)
    {
        bytes32 flightKey = getFlightKey(airline,flight,timestamp);
        return flights[flightKey].statusCode;
    }

    function requestCreditInsurance(address airline,string memory flight,uint256 timestamp)
    public
    requireIsOperational
    {
        bytes32 insuranceKey = _buildInsuranceKey(msg.sender,flight,timestamp);
        require(validateInsurance(insuranceKey),'No insurance Found');

        bytes32 flightKey = getFlightKey(airline,flight,timestamp);
        require(isFlightStatusToPayout(flightKey),'Flight is not availaible for payout');

        uint insuranceAmount = flightSuretyData.getinsurance(insuranceKey);
        uint payout = insuranceAmount.mul(3).div(2);

        flightSuretyData.deleteInsurance(insuranceKey);
        flightSuretyData.creditInsurees(insuranceKey,payout);
    }

    function withdrawAmount(string memory flight,uint timestamp)
    public
    requireIsOperational
    {
        bytes32 insuranceKey = _buildInsuranceKey(msg.sender,flight,timestamp);
        require(validateWithdrawRequest(insuranceKey),'No payout Availaible');
        uint payoutAmt = flightSuretyData.pay(insuranceKey);
        msg.sender.transfer(payoutAmt);
    }

    /********************************************************************************************/
    /*                                     Private FUNCTIONS                             */
    /********************************************************************************************/

    function _createPendingAirline(address account)
    private
    {
        flightSuretyData.creatependingAirline(account);
        emit PendingAirlineCreated(account);
    }

    function _registerAirline(address account)
    private
    {
        flightSuretyData.registerAirline(account);
        emit AirlineRegistered(account);
    }

    function _voteAirline(address account, uint approvalThreshold) private {
        uint votedCount = flightSuretyData.voteAirline(account, msg.sender);
        emit AirlineVoted(account, votedCount);

        if (votedCount >= approvalThreshold) {
            _registerAirline(account);
        }
    }

    function _makeAirlineOperational(address airline)
    private
    {
        flightSuretyData.setAirlineOperational(airline);
        emit AirlineIsOperational(airline);
    }

    function _buildInsuranceKey(address passenger, string memory flight, uint timestamp)
    private
    pure
    returns(bytes32)
    {
        return keccak256(abi.encodePacked(passenger, flight, timestamp));
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle()
    external
    payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true,indexes: indexes});
    }

    function getMyIndexes()
    view
    external
    returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index,address airline,string flight,uint256 timestamp,uint8 statusCode)
    external
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
            oracleResponses[key].isOpen = false;
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey(address airline,string flight, uint256 timestamp)
    pure
    internal
    returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account)
    internal
    returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account)
    internal
    returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}
