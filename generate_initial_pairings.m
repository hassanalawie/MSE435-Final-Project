function initial_pairings = generate_initial_pairings(M)
% GENERATE_INITIAL_PAIRINGS  Create single-leg pairings from table M
%
%   M - a table of flight-leg data, with columns like:
%       M.Date
%       M.Duration
%       M.DepartureTime
%       M.ArrivalTime
%       M.DepartureAirport
%       M.ArrivalAirport
%       (potentially others like M.FlightNumber)
%
% OUTPUT:
%   initial_pairings - struct array, each element represents a 1-leg pairing
%       fields:
%           .PairingID      (string)
%           .Legs           (1x1 or 1xN struct array of flight legs)
%           .Cost           (numeric, cost computed by calculate_pairing_cost)
%
    numLegs = height(M);
    initial_pairings = cell(numLegs,1);
    for i = 1:numLegs
        % Build a single flight-leg struct with the fields your cost function expects
        singleLeg.Date              = M.Date(i);
        singleLeg.Duration          = M.Duration(i);
        singleLeg.DepartureTime     = M.DepartureTime(i);
        singleLeg.ArrivalTime       = M.ArrivalTime(i);
        singleLeg.DepartureAirport  = M.DepartureAirport{i};
        singleLeg.ArrivalAirport    = M.ArrivalAirport{i};
        singleLeg.Duration          = M.Duration(i);
        singleLeg.ArrivalAirport    = M.ArrivalAirport{i};
        singleLeg.Aircraft          = M.Aircraft{i};
        singleLeg.Airline           = M.Airline{i};
        singleLeg.FlightNumber      = M.FlightNumber(i);
        pairingStruct.PairingID = sprintf('Pairing_Leg_%d', i);
        pairingStruct.Legs      = singleLeg;  % 1x1 struct
        pairingCost = calculate_pairing_cost(pairingStruct.Legs);
        pairingStruct.Cost = pairingCost;
        initial_pairings{i} = pairingStruct;
    end

    % Convert cell array of structs to struct array
    initial_pairings = [initial_pairings{:}];
end