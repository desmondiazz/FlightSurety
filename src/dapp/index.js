
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-list').value;
            let timestamp = parseInt(DOM.elid('flight-depature').value);
            // Write transaction
            contract.fetchFlightStatus(flight, timestamp, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })
        
        DOM.elid('check-status').addEventListener('click', () => {
            let flight = DOM.elid('flight-list').value;
            let timestamp = parseInt(DOM.elid('flight-depature').value);
            // Write transaction
            contract.checkFlightStatus(flight, timestamp, (error, result) => {
                const STATUS_CODE_UNKNOWN = 0;
                const STATUS_CODE_ON_TIME = 10;
                const STATUS_CODE_LATE_AIRLINE = 20;
                const STATUS_CODE_LATE_WEATHER = 30;
                const STATUS_CODE_LATE_TECHNICAL = 40;
                const STATUS_CODE_LATE_OTHER = 50;
            
                const statusCodes = {
                    0:' is UNKNOWN',
                    10:' is ON TIME',
                    20:' is DELAYED',
                    30:' is DELAYED DUE TO WEATHER',
                    40:' is DELAYED DUE TO TECHNICAL FAULT',
                    50:' is DELAYED DUE TO UNKNOWN REASONS',
                };
                display('Oracles', 'Trigger oracles', [ { label: 'Flight Status :', error: error, value: flight + ' ' + timestamp + ' ' + statusCodes[result]} ]);
            });
        })
    
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







