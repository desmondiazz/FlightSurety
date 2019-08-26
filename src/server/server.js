import "babel-polyfill";
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
var oracles = [];
var registeredOracles = {};

web3.eth.getAccounts((err,accounts)=>{
  oracles = accounts.slice(20, 40);
}).then(()=>{
  registerOracles().then(async()=>{
    var resgistrationStatus = await Promise.all(oracles.map(async(oracle)=>{
      var index = await flightSuretyApp.methods.getMyIndexes().call({from: oracle});
      return {'oracle':oracle,indexes:index};
    }));
    resgistrationStatus.forEach(oracle=>{
      registeredOracles[oracle['oracle']] = oracle['indexes'];
    });
  });
});

function registerOracles(){
  return new Promise(async(resolve,reject)=>{
    const fee = web3.utils.toWei('1', 'ether');
    await Promise.all(oracles.map(oracle=>{
      return flightSuretyApp.methods.registerOracle().
      send({from:oracle,value:fee,gas: 6700000});  
    }));
    resolve(true);
  });
}

async function submitFlightStatus(airline , flight , timestamp){
  const promises = [];
  Object.keys(registeredOracles).forEach((oracle)=>{
    registeredOracles[oracle].forEach((oracleIndex)=>{
        promises.push({index:oracleIndex,airline,flight,timestamp,oracle});
    })
  });

await Promise.all(promises.map(promise=>{
    return flightSuretyApp.methods
    .submitOracleResponse(promise['index'],promise['airline'],promise['flight'],promise['timestamp'],10)
    .send({from:promise['oracle']}).catch(e=>e.message);
  }));
  var result = await flightSuretyApp.methods.getFlightStatus(airline,flight,timestamp).call();
  console.log('Flight status: ',result);
}

flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) {
      console.log(error)
    } else {
      submitFlightStatus(event.returnValues['airline'],event.returnValues['flight'],event.returnValues['timestamp']);
    }
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


