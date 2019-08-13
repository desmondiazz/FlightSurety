const FlightSuretyApp = artifacts.require('FlightSuretyApp');
const FlightSuretyData = artifacts.require('FlightSuretyData');
const truffleAssert = require('truffle-assertions');
var Config = require('../config/Config.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  before('setup contract', async () => {
    dataContract = await FlightSuretyData.deployed();
    appContract = await FlightSuretyApp.deployed();
    await dataContract.authorizeContract(FlightSuretyApp.address, { from: accounts[0] });
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  describe('Operations and Settings',()=>{
    it(`(multiparty) has correct initial isOperational() value`, async()=>{
      // Get operating status
      let status = await dataContract.isOperational.call();
      assert.equal(status, true, "Incorrect initial operating status value");
    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
        await dataContract.setOperatingStatus(false, { from: accounts[2] });
      }
      catch(e) {
        accessDenied = true;
      }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
    });
  
    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
        await dataContract.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      await dataContract.setOperatingStatus(true);
    });
  })
});
