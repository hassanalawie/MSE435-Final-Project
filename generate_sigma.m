function sigma = generate_sigma(all_pairings, M)
    % GENERATE_SIGMA Create the sigma matrix linking flights to pairings.
    %   all_pairings is an array of structs, each with a field .Legs
    %   M is the master table of flight legs, with columns:
    %       M.FlightNumber, M.Date, M.DepartureTime, M.ArrivalTime, ...
    %
    % OUTPUT:
    %   sigma: A (numFlights x numPairings) matrix where
    %          sigma(f, p) = 1 if pairing p covers flight f, else 0.
    
    numPairings = numel(all_pairings);
    numFlights  = height(M);  % or 2512 if that is fixed
    sigma       = sparse(numFlights, numPairings);
    
    for p = 1:numPairings
        % Extract the array of flight-legs for this pairing
        legs = all_pairings(p).Legs;

        % Standardize `legs` to be a struct array if it's wrapped inside a cell
        if iscell(legs)
            legs = legs{1};  % Extract the struct array from the cell
        end

        % Debugging for special cases
        if p == 2513
            disp("We are now generating sigma for generated columns");
        end
        
        % Loop over each flight leg correctly
        for i = 1:numel(legs)
            fltNum  = legs(i).FlightNumber;
            fltDate = legs(i).Date;  % e.g. '01-Mar'

            % Ensure DepartureTime is in 'HH:mm' format for comparison
            if isdatetime(legs(i).DepartureTime)
                depT = datestr(legs(i).DepartureTime, 'HH:MM');
            else
                depT = string(legs(i).DepartureTime);
            end

            % Ensure ArrivalTime is in 'HH:mm' format for comparison
            if isdatetime(legs(i).ArrivalTime)
                arrT = datestr(legs(i).ArrivalTime, 'HH:MM');
            else
                arrT = string(legs(i).ArrivalTime);
            end
            
            % Find matching row in M
            rowIndex = find( M.FlightNumber == fltNum & ...
                             strcmp(M.Date, fltDate) & ...
                             strcmp(string(M.DepartureTime), depT) & ...
                             strcmp(string(M.ArrivalTime), arrT) );

            % If match found, mark it in sigma
            if ~isempty(rowIndex)
                sigma(rowIndex, p) = 1;
            end
        end
    end
end
