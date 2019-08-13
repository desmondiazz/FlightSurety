pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./Authorizable.sol";
import "./AirlineControl.sol";

contract FlightSuretyData is Authorizable , AirlineControl {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() Authorizable() public{
        contractOwner = msg.sender;
        AirlineControl.registerFirstAirline(msg.sender);
    }

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
    modifier requireIsOperational(){
        require(operational, "Contract is currently not operational");
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

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational() public view returns(bool) {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus ( bool mode ) external requireContractOwner{
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline(address airline)
    external
    onlyAuthorizedContract
    {
        AirlineControl.register(airline);
    }

    function registeredAirlinesCount()
        external
        view
        onlyAuthorizedContract
        returns(uint)
    {
        return AirlineControl.getRegisteredAirlinesCount();
    }

    function isPendingAirline(address account)
    external
    view
    onlyAuthorizedContract
    returns(bool)
    {
        return AirlineControl.isPending(account);
    }
    
    function isRegisteredAirline(address account)
    external
    view
    onlyAuthorizedContract
    returns(bool)
    {
        return AirlineControl.isRegistered(account);
    }
    
    function isAirlineOperational(address account)
    external
    view
    onlyAuthorizedContract
    returns(bool)
    {
        return AirlineControl.isOperational(account);
    }

    function creatependingAirline(address account)
    external
    requireIsOperational
    onlyAuthorizedContract
    {
        AirlineControl.createPendingAirline(account);
    }

    function voteAirline(address account, address from)
    external
    requireIsOperational
    onlyAuthorizedContract
    returns(uint)
    {
        AirlineControl.vote(account, from);
        return airlines[account].votedBy.length;
    }

    function addFund(address account,uint amount)
    external
    requireIsOperational
    onlyAuthorizedContract
    returns(uint)
    {
        AirlineControl.addFunds(account,amount);
        return airlines[account].funds;
    }

    function setAirlineOperational(address airline)
    external
    {
        AirlineControl.makeAirlineOperational(airline);
    }

    function getFunds(address airline)
    external
    view
    returns(uint)
    {
        return airlines[airline].funds;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy()external payable{

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees( ) external pure {
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay ( ) external pure {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund () public payable {
    }

    function getFlightKey ( address airline, string memory flight, uint256 timestamp ) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable{
        fund();
    }


}

