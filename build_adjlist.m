function adjList = build_adjlist(M)
% BUILD_ADJLIST  Creates an adjacency list from the flight-legs in table M.
%
%   M has columns:
%       M.Date, M.Airline, M.Aircraft, M.DepartureTime,
%       M.ArrivalTime, M.Duration, M.DepartureAirport,
%       M.FlightNumber, M.ArrivalAirport, M.ArrivalDate
%
%   Output:
%       adjList : a cell array, where adjList{i} is a struct array of arcs
%                 from flight i to other feasible follow-on flights.

    nFlights = height(M);
    
    % Pre-allocate the adjacency list as a cell array of empty arrays
    adjList = cell(nFlights,1);
    
    % ---- Convert times (strings) to datetime ----
    flightDepDateTime = zeros(nFlights,1);
    flightArrDateTime = zeros(nFlights,1);
    flightArrAirport  = cell(nFlights,1);
    flightDepAirport  = cell(nFlights,1);
    flightNumbers     = M.FlightNumber;  % For reference
    flightDates       = cell(nFlights,1);  % Added flightDate storage
    
    for i=1:nFlights
        % Build full datetime using correct dates for departure and arrival
        depStr = strjoin([string(M.Date(i)), string(M.DepartureTime(i))], ' ');
        arrStr = strjoin([string(M.ArrivalDate(i)), string(M.ArrivalTime(i))], ' '); % Use ArrivalDate

        % Parse datetime
        depDT = datetime(depStr,'InputFormat','dd-MMM HH:mm');
        arrDT = datetime(arrStr,'InputFormat','dd-MMM HH:mm');

        flightDepDateTime(i) = posixtime(depDT);  % store as numeric (seconds)
        flightArrDateTime(i) = posixtime(arrDT);

        flightArrAirport{i}  = string(M.ArrivalAirport(i));
        flightDepAirport{i}  = string(M.DepartureAirport(i));
        flightDates{i}       = string(M.Date(i));  % Store original flight date
    end
    
    % ---- Build adjacency list ----
    minConnectMins = 20;  % Minimum layover time in minutes
    for i=1:nFlights
        arcsFromI = [];
        
        % i's arrival airport/time
        arrTime_i   = flightArrDateTime(i);
        arrAirportI = flightArrAirport{i};
        
        for j=1:nFlights
            if j == i
                continue;
            end
            
            % Check if flight j can follow flight i
            depAirportJ = flightDepAirport{j};
            depTime_j   = flightDepDateTime(j);
            
            % Condition: same airport, and departure time respects min connection time
            earliestPossible = arrTime_i + (minConnectMins * 60);  % Convert to seconds
            
            if arrAirportI == depAirportJ && depTime_j >= earliestPossible
                % Create feasible arc i->j
                arc.to = j;
                arc.flightID = i;  % Store flight ID
                arc.flightNumber = M(i, 8).FlightNumber;
                arc.flightHours = duration_to_hours(string(M.Duration(i)));
                arc.departureTime = flightDepDateTime(i);
                arc.arrivalTime   = flightArrDateTime(i);
                arc.departureAirport = flightDepAirport{i}; 
                arc.arrivalAirport = flightArrAirport{i};   
                arc.flightDate = flightDates{i};            
                arc.isDeadhead = false;  % Placeholder for deadhead logic
                
                arcsFromI = [arcsFromI, arc];
            end
        end
        
        % Store adjacency list for flight i
        adjList{i} = arcsFromI;
    end
end

function hrs = duration_to_hours(durStr)
% Convert 'HH:MM' string format to decimal hours
    parts = split(durStr,':');
    hh = str2double(parts(1));
    mm = str2double(parts(2));
    hrs = hh + mm/60;
end
