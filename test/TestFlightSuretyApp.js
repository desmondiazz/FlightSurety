const FlightSuretyApp = artifacts.require('FlightSuretyApp');
const FlightSuretyData = artifacts.require('FlightSuretyData');
const truffleAssert = require('truffle-assertions');
// const MockOracle = require('../utils/mockOracle');

contract('FlightSuretyApp', (accounts) => {
    let instance;
    let requestIndex;
    let canPayout = false;

    const [
        airline1,
        airline2,
        airline3,
        airline4,
        airline5,
        notRegistered1,
        notRegistered2,
        passenger1,
        passenger2,
    ] = accounts;

    const oracles = accounts.slice(20, 49);
    const TEST_ORACLES_COUNT = 20;

    const owner = airline1;

    const premium = web3.utils.toWei('1', 'ether');
    const payout = web3.utils.toWei('1.5', 'ether');

    const testFlight = {
        flightNumber: 'ND1309',
        timestamp: Math.floor(Date.now() / 1000),
    };

    // Watch contract events
    const STATUS_CODE_UNKNOWN = 0;
    const STATUS_CODE_ON_TIME = 10;
    const STATUS_CODE_LATE_AIRLINE = 20;
    const STATUS_CODE_LATE_WEATHER = 30;
    const STATUS_CODE_LATE_TECHNICAL = 40;
    const STATUS_CODE_LATE_OTHER = 50;


    before('setup contract', async () => {
        dataContract = await FlightSuretyData.deployed();
        appContract = await FlightSuretyApp.deployed();
        await dataContract.authorizeContract(FlightSuretyApp.address, { from: accounts[0] });
    });

    describe('Airline Registration', () => {

        it('registers first airline when deployed', async () => {
            const registeredCount = await dataContract.registeredAirlinesCount.call();
            assert.equal(registeredCount.toNumber(), 1);
        });

        it('Creates a pending ariline', async() =>{
            const tx = await appContract.registerPendingAirline(airline2);
            truffleAssert.eventEmitted(tx, 'PendingAirlineCreated', event => event.account === airline2);
        }); 

        it('registers a new airline', async () => {
            const tx = await appContract.registerAirline(airline2, { from: airline1 });
            truffleAssert.eventEmitted(tx, 'AirlineRegistered', event => event.account === airline2);
        });
        
        it('cannot register a new airline without the first airline being registered', async () => {
            var status = false;
            try {
                await appContract.registerAirline(airline3, { from: notRegistered1 });
            } catch (error){
                status = true;
            }
            assert.equal(status,true);
        });

        it('registers up to 4th airlines without cousensus', async () => {
            let tx;
            tx = await appContract.registerAirline(airline3, { from: airline1 });
            truffleAssert.eventEmitted(tx, 'AirlineRegistered', event => event.account === airline3);

            tx = await appContract.registerAirline(airline4, { from: airline1 });
            truffleAssert.eventEmitted(tx, 'AirlineRegistered', event => event.account === airline4);
        });

        it('does not register 5th and subsequent airlines without consensus', async () => {
            const tx = await appContract.registerAirline(airline5, { from: airline1 });
            truffleAssert.eventNotEmitted(tx, 'AirlineRegistered', event => event.account === airline5);

            truffleAssert.eventEmitted(tx, 'AirlineVoted', event => (
                event.account === airline5 && event.votedCount.toNumber() === 1
            ));
        });

        it('registers 5th and subsequent airlines when voted by 50% of registered airlines', async () => {
            const tx = await appContract.registerAirline(airline5, { from: airline2 });
            truffleAssert.eventEmitted(tx, 'AirlineRegistered', event => event.account === airline5);
        });
    });

    describe('Airline Funding', () => {        
        it('Is not operational before funding',async()=>{
            const status = await dataContract.isAirlineOperational.call(airline1);
            assert.equal(status,false);
        });
        
        it('accepts ether', async () => {
            const funds = web3.utils.toWei('8', 'ether');
            const tx = await appContract.addFunds({ from: airline1, value: funds });
            truffleAssert.eventEmitted(tx, 'AirlineFunded', event => (
                event.account === airline1 && event.funds.toString() === funds
            ));
            truffleAssert.eventNotEmitted(tx, 'AirlineIsOperational');
        });
        
        it('Is operational after funding of 10 eather',async()=>{
            const funds = web3.utils.toWei('2', 'ether');
            const tx2 = await appContract.addFunds({ from: airline1, value: funds });
            truffleAssert.eventEmitted(tx2, 'AirlineIsOperational');
            const status = await dataContract.isAirlineOperational.call(airline1);
            assert.equal(status,true);
        });
    });

    describe('Flight Registration', () => {
        it('registers a new flight', async () => {
            const { flightNumber, timestamp } = testFlight;
            const tx = await appContract.registerFlight(flightNumber, timestamp, { from: airline1 });
            truffleAssert.eventEmitted(tx, 'FlightRegistered', event => (
                event.airline === airline1
                && event.flight === flightNumber
            ));
        });

        it('Unregistered Airline cannot register a flight', async () => {
            const flightNumber = 'TEST12';
            const timestamp = Date.now();
            var status = false;
            try {
                await appContract.registerFlight(flightNumber, timestamp, { from: notRegistered1 });
            } catch (error) {
                status = true
            }
            assert.equal(status,true);
        });

        it('refuses a request from a airline funded less than 10 ether', async () => {
            const flightNumber = 'TEST999';
            const timestamp = Date.now();
            var status = false;
            try {
                await appContract.registerFlight(flightNumber, timestamp, { from: airline2 });
            } catch (error) {
                status = true
            }
            assert.equal(status,true);
        });
    });

    describe('But Insurance', () => {
        it('allows passengers to purchase insurance', async () => {
            const { flightNumber, timestamp } = testFlight;

            const tx = await appContract.buyInsurance(flightNumber, timestamp, airline1 , {
                from: passenger1,
                value: premium,
            });

            const insurance = await appContract.getInsurance.call(flightNumber, timestamp, airline1 , {
                from: passenger1
            });
            assert.equal(insurance,premium);
        });

        it('refuses a request to pay more than 1 ether', async () => {
            const { flightNumber, timestamp } = testFlight;

            try {
                await appContract.buyInsurance(flightNumber, timestamp, airline1,{
                    from: passenger2,
                    value: web3.utils.toWei('2', 'ether'),
                });
            } catch (error) {
                assert.match(error.message, /Up to 1 ether for purchasing flight insurance/);
            }
        });
    });

    describe('Oracles Registration', async () => {
        it('can register oracles', async () => {
            let fee = await appContract.REGISTRATION_FEE.call();
        
            for(let a=0; a<TEST_ORACLES_COUNT; a++) {
              await appContract.registerOracle({ from: oracles[a], value: fee });
              let result = await appContract.getMyIndexes.call({from: oracles[a]});
              console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
            }
          });

        it('refuses a request without adequet fee', async () => {
            try {
                await appContract.registerOracle({
                    from: oracles[1],
                    value: web3.utils.toWei('.5', 'ether'),
                });
                throw new Error('unreachable error');
            } catch (error) {
                assert.match(error.message, /Registration fee is required/);
            }
        });

        it('refuses a request from not registered oracle', async () => {
            try {
                await appContract.getMyIndexes.call({ from: oracles[21] });
                throw new Error('unreachable error');
            } catch (error) {
                assert.match(error.message, /Not registered as an oracle/);
            }
        });

    });

    describe('Oracle Response',()=>{
        const flight = testFlight.flightNumber;
        const timestamp = testFlight.timestamp;
        var requestedIndex = null;
        const minumumValidResponses = 3;

        it('Should be able to request for a flight status',async()=>{
            const statusRequest = await appContract.fetchFlightStatus(airline1, flight, timestamp,{from:passenger1});
            truffleAssert.eventEmitted(statusRequest,'OracleRequest',event=>{
                requestedIndex = event.index;
                return event.airline==airline1
            });
        });

        it('Should not accept request from a non registered oracle',async()=>{
            try {
                await appContract.submitOracleResponse(1, airline1, flight, timestamp, STATUS_CODE_ON_TIME, { from: oracles[21] });
                throw new Error('unreachable error');
            } catch (error) {
                assert.match(error.message, /Not registered as an oracle/);
            }
        });

        it(`Should accept atleast ${minumumValidResponses} requests with valid index`,async()=>{
            const promises = [];
            for(let a=1; a<TEST_ORACLES_COUNT; a++) {
                let oracleIndexes = await appContract.getMyIndexes.call({ from: oracles[a]});
                for(let idx=0;idx<3;idx++) {
                    if(oracleIndexes[idx]==requestedIndex.toString() && promises.length < minumumValidResponses){
                        promises.push(appContract.submitOracleResponse(oracleIndexes[idx], airline1, flight, timestamp, STATUS_CODE_ON_TIME, { from: oracles[a] }).catch(e=>false));
                    }
                }
            }
            const result = await Promise.all(promises);
            assert.equal(result.filter(e=>e==false).length,0);
        });
        
        it(`Should accept only ${minumumValidResponses} requests with valid index`,async()=>{
            const request = await appContract.fetchFlightStatus(airline2, flight, timestamp,{from:passenger1});
            var requestIndex = null;
            truffleAssert.eventEmitted(request,'OracleRequest',event=>{
                requestIndex = event.index;
                return event.airline==airline2
            });
            for(let a=1; a<TEST_ORACLES_COUNT; a++) {
                let oracleIndexes = await appContract.getMyIndexes.call({ from: oracles[a]});
                for(let idx=0;idx<3;idx++) {
                    try {
                        await appContract.submitOracleResponse(oracleIndexes[idx], airline2, flight, timestamp, STATUS_CODE_LATE_AIRLINE, { from: oracles[a] });
                    } catch (error) {}
                }
            }
            const votes = await appContract.getFlightStatusVotes.call(requestIndex.toString(),airline2, flight, timestamp,STATUS_CODE_LATE_AIRLINE);
            assert.equal(votes<=minumumValidResponses,true);
        });

        it(`Should change the flight status to ${STATUS_CODE_LATE_AIRLINE}`,async()=>{
            await appContract.fetchFlightStatus(airline3, flight, timestamp,{from:passenger1});
            for(let a=1; a<TEST_ORACLES_COUNT; a++) {
                let oracleIndexes = await appContract.getMyIndexes.call({ from: oracles[a]});
                for(let idx=0;idx<3;idx++) {
                    try {
                        await appContract.submitOracleResponse(oracleIndexes[idx], airline3, flight, timestamp, STATUS_CODE_LATE_AIRLINE, { from: oracles[a] });
                    } catch (error) {}
                }
            }
            const status = await appContract.getFlightStatus.call(airline3, flight, timestamp);
            assert.equal(status,STATUS_CODE_LATE_AIRLINE);
        });
    });

    // describe('withdrawalRefund function', () => {
    //     it('allows passengers to withdrawal payout', async () => {
    //         if (!canPayout) {
    //             // eslint-disable-next-line no-console
    //             console.log('There are no flights to pay back credit. Please rerun test.');
    //             return;
    //         }

    //         const { flightNumber, timestamp } = testFlight;
    //         const balanceBefore = await web3.eth.getBalance(passenger1);

    //         await instance.withdrawalRefund(
    //             flightNumber,
    //             timestamp,
    //             { from: passenger1, gasPrice: 0 },
    //         );

    //         const balanceAfter = await web3.eth.getBalance(passenger1);

    //         assert.equal(
    //             Number(balanceAfter) - Number(balanceBefore),
    //             Number(payout),
    //         );
    //     });

    //     it('does not allow to withdrawal if flight does not delay', async () => {
    //         const flightNumber = 'TEST234';
    //         const timestamp = Date.parse('02 Jan 2009 09:00:00 GMT');

    //         await instance.registerFlight(flightNumber, timestamp, { from: airline1 });
    //         await instance.buyInsurance(flightNumber, timestamp, {
    //             from: passenger1,
    //             value: premium,
    //         });

    //         try {
    //             await instance.withdrawalRefund(
    //                 flightNumber,
    //                 timestamp,
    //                 { from: passenger1, gasPrice: 0 },
    //             );
    //             throw new Error('unreachable error');
    //         } catch (error) {
    //             assert.match(error.message, /Not a flight to payout/);
    //         }
    //     });

    //     it('refuses any requests when the contract is not operational', async () => {
    //         const flightNumber = 'TEST345';
    //         const timestamp = Date.parse('03 Jan 2009 09:00:00 GMT');

    //         await instance.registerFlight(flightNumber, timestamp, { from: airline1 });
    //         await instance.buyInsurance(flightNumber, timestamp, {
    //             from: passenger1,
    //             value: premium,
    //         });

    //         await instance.setOperatingStatus(false, { from: owner });

    //         try {
    //             await instance.withdrawalRefund(
    //                 flightNumber,
    //                 timestamp,
    //                 { from: passenger1, gasPrice: 0 },
    //             );
    //             throw new Error('unreachable error');
    //         } catch (error) {
    //             assert.match(error.message, /Contract is currently not operational/);
    //         }

    //         await instance.setOperatingStatus(true, { from: owner });
    //     });
    // });
});
