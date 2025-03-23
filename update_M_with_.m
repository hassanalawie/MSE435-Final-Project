function M = update_M_with_(M)
% BUILD_ADJLIST  Creates an adjacency list from the flight-legs in table M.
%
%   M has columns:
%       M.Date, M.Airline, M.Aircraft, M.DepartureTime,
%       M.ArrivalTime, M.Duration, M.DepartureAirport,
%       M.FlightNumber, M.ArrivalAirport
%
%   Output:
%       adjList : a cell array, where adjList{i} is a struct array of arcs
%                 from flight i to other feasible follow-on flights.

    nFlights = height(M);
    
    % Pre-allocate the adjacency list as a cell array of empty arrays
    adjList = cell(nFlights,1);
    
    % ---- Convert times (strings) to numeric minutes or datetimes ----
    % For simplicity, assume date/time are in M.Date(i) / M.DepartureTime(i).
    % If your table is all 1-Mar, you might do something like:
    flightDepDateTime = zeros(nFlights,1);
    flightArrDateTime = zeros(nFlights,1);
    flightArrAirport  = cell(nFlights,1);
    flightDepAirport  = cell(nFlights,1);
    flightNumbers     = M.FlightNumber;  % For reference
    
    for i=1:nFlights
        % Build a full datetime. Suppose '01-Mar' is in M.Date(i) 
        % and '10:35' is in M.DepartureTime(i).
        % Adjust to your actual format if needed:
        depStr = [string(M.Date(i))," ",string(M.DepartureTime(i))];
        depStr = strjoin(depStr, '');
        arrStr = [string(M.Date(i))," ",string(M.ArrivalTime(i))];
        arrStr = strjoin(arrStr, '');

        
        % Example parse (assuming '01-Mar 10:35' is recognized):
        depDT = datetime(depStr,'InputFormat','dd-MMM HH:mm');
        arrDT = datetime(arrStr,'InputFormat','dd-MMM HH:mm');
        
        flightDepDateTime(i) = posixtime(depDT);  % store as numeric (seconds)
        flightArrDateTime(i) = posixtime(arrDT);
        
        flightArrAirport{i}  = string(M.ArrivalAirport(i));
        flightDepAirport{i}  = string(M.DepartureAirport(i));
    end
    
    % ---- Build adjacency based on matching arrival->departure airports
    %      and any min connection time (say 20 mins).
    minConnectMins = 20;  % example
    for i=1:nFlights
        
        arcsFromI = [];
        
        % i's arrival airport/time
        arrTime_i   = flightArrDateTime(i);
        arrAirportI = flightArrAirport{i};
        
        for j=1:nFlights
            if j==i
                continue;
            end
            % Check if flight j can follow flight i
            depAirportJ = flightDepAirport{j};
            depTime_j   = flightDepDateTime(j);
            
            % Condition: same airport, and the departure is at least
            % arrTime_i + minConnectMins
            % We stored times in posix seconds, so convert minConnectMins
            % into seconds:
            earliestPossible = arrTime_i + (minConnectMins * 60);
            
            if arrAirportI == depAirportJ && depTime_j >= earliestPossible
                % We have a feasible arc i->j
                
                % Build arc struct
                arc.to = j;
                
                % We'll store flight i as "covered flight" on this arc,
                % or store flight j, whichever logic you prefer. Typically,
                % you'd note that taking arc i->j means we ended flight i
                % and are about to do flight j, etc.
                
                arc.flightID = i;  % or you might store j 
                
                % For subproblem cost: convert flight times or read M.Duration, 
                % in hours, etc.
                flightHours = duration_to_hours(string(M.Duration(i)));
                arc.flightHours = flightHours;
                
                % Additional info:
                arc.departureTime = flightDepDateTime(i);
                arc.arrivalTime   = flightArrDateTime(i);
                
                % Example: if you want to label arcs with isDeadhead = false
                arc.isDeadhead = false;
                % ... add other fields as needed ...
                
                arcsFromI = [arcsFromI, arc];
            end
        end
        
        % store
        adjList{i} = arcsFromI;
    end
end

function hrs = duration_to_hours(durStr)
% DURSTR is something like '01:04' meaning 1h 4m. 
% Convert to hours as a float.
    parts = split(durStr,':');
    hh = str2double(parts(1));
    mm = str2double(parts(2));
    hrs = hh + mm/60;
end
