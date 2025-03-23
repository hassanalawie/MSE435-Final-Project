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
        
        % In some code, .Legs might be a struct array or a single struct,
        % so standardize it into a cell array if needed.
        if isstruct(legs)
            legs = {legs};
        end
        
        % For each flight-leg in this pairing, find the matching row in M
        for i = 1:numel(legs)
            fltNum  = legs{i}.FlightNumber;
            fltDate = legs{i}.Date;            % e.g. '01-Mar'
            depT    = legs{i}.DepartureTime;   % e.g. '10:35'
            arrT    = legs{i}.ArrivalTime;     % e.g. '11:39'
            
            % Example match (expand as needed if you also need DepartureAirport, etc.)
            rowIndex = find( M.FlightNumber == fltNum & ...
                             strcmp(M.Date, fltDate) & ...
                             strcmp(M.DepartureTime, depT) & ...
                             strcmp(M.ArrivalTime,   arrT) );
            if ~isempty(rowIndex)
                sigma(rowIndex, p) = 1;
            end
        end
    end
    
    % If you prefer a full matrix rather than sparse:
    % sigma = full(sigma);
end