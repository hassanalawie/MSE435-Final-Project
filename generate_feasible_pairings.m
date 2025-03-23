function pairings = generate_feasible_pairings(M)
    %GENERATE_FEASIBLE_PAIRINGS Produce 1×N struct array of pairings 
    %   M is a table of flight legs with columns: 
    %       FlightNumber, Duration, DepartureTime, ArrivalTime, ...
    %       DepartureAirport, ArrivalAirport
    %
    %   This function returns a 1×N struct array: 
    %       pairings(k).PairingID (string)
    %       pairings(k).Legs      (1×N struct array of flight legs)
    %       pairings(k).Cost      (numeric)

    numLegs = height(M);

    % -- Initialize the pairings array as empty struct --
    pairings = struct('PairingID', {}, 'Legs', {}, 'Cost', {});

    fprintf('Starting pairing generation for %d flights...\n', numLegs);
    tic; % Start timing

    % Iterate over all flights as starting points
    for i = 1:numLegs
        baseStart = M.DepartureAirport{i};

        % Convert row i of M to a single flight-leg struct
        flightLeg = table2struct(M(i,:), 'ToScalar', true);
        flightLeg.DepartureAirport = flightLeg.DepartureAirport{1};
        flightLeg.ArrivalAirport   = flightLeg.ArrivalAirport{1};
        flightLeg.FlightNumber     = flightLeg.FlightNumber(1);

        % Create single-leg pairing
        pairing.PairingID = sprintf('Pairing_Leg_%d', i);
        pairing.Legs      = flightLeg;  % 1×1 struct
        pairing.Cost      = calculate_pairing_cost(pairing.Legs);
        fprintf('Pairing %d: Started from %s at %s...\n', i, baseStart, M.DepartureTime{i});

        % Store the single-leg pairing
        pairings(end+1) = pairing; 

        % Prepare to extend into multi-leg pairing
        multiLeg = pairing; 

        for j = i+1 : numLegs
            % Convert row j of M to nextFlight struct
            if i == 65
                fprintf("Hi")
            end
            nextFlight = table2struct(M(j,:), 'ToScalar', true);
            nextFlight.DepartureAirport = nextFlight.DepartureAirport{1};
            nextFlight.ArrivalAirport   = nextFlight.ArrivalAirport{1};
            nextFlight.FlightNumber     = nextFlight.FlightNumber(1);

            % Check layover and flight hour constraints
            layoverTime = compute_layover(multiLeg.Legs(end), nextFlight);
            if layoverTime < 9
                continue; % Not enough rest
            end

            % Convert Duration strings like "02:34" to hours
            flightHours = str2double(extractBefore(nextFlight.Duration, ':')) + ...
                          str2double(extractAfter(nextFlight.Duration, ':')) / 60;

            % Sum up flight hours in the multiLeg
            durations = cellfun(@(x) str2double(extractBefore(x, ':')) + ...
                                      str2double(extractAfter(x, ':'))/60, ...
                                {multiLeg.Legs.Duration});

            totalFlightTime = sum(durations) + flightHours;
            if totalFlightTime > 8
                continue; % Exceeds daily flight-hour limit
            end

            % Create a snapshot copy to hold the newly extended pairing
            newPairing = multiLeg;

            % Append the flight horizontally (so .Legs is 1×N)
            newPairing.Legs = [newPairing.Legs, nextFlight];
            newPairing.Cost = calculate_pairing_cost(newPairing.Legs);

            % If flight returns to base, consider it a valid multi-leg pairing
            if strcmp(nextFlight.ArrivalAirport, baseStart)
                newPairing.PairingID = sprintf('Multi_Pairing_%d_leg%d', i, j);
                pairings(end+1) = newPairing;
            end

            % If you want to keep extending beyond j, let multiLeg carry the new flight(s)
            multiLeg = newPairing;
        end
    end

    fprintf('Pairing generation complete! %d pairings created in %.2f sec.\n',...
        numel(pairings), toc);
end


function layoverTime = compute_layover(flight1, flight2)
    % Computes layover time between two flights (in hours)
    depTime = duration(flight2.DepartureTime{1}, 'InputFormat', 'hh:mm');
    arrTime = duration(flight1.ArrivalTime{1}, 'InputFormat', 'hh:mm');
    layoverTime = hours(depTime - arrTime);
end

