function validate_sigma(sigma, M, all_pairings)
%VALIDATE_SIGMA  Checks that your sigma matrix properly covers flights.
%
%  sigma(f,p) = 1 if pairing p covers flight f; 0 otherwise.
%  M is your flights table of size numFlights-by-?
%  all_pairings is an array of pairings, length = numPairings.
%
%  This function will:
%   * Find any flights that have no coverage
%   * Find any pairings that do not cover any flights
%   * Optionally flag flights that are covered by multiple pairings, etc.

    [numFlights, numPairings] = size(sigma);

    % 1) Check coverage count for each flight
    coveragePerFlight = sum(sigma,2);  % sum across columns
    flightsWithNoCoverage = find(coveragePerFlight == 0);
    flightsWithMultipleCoverage = find(coveragePerFlight > 1);

    if isempty(flightsWithNoCoverage)
        disp('All flights have at least one pairing covering them.');
    else
        warning('The following flights have NO coverage: %s', ...
                mat2str(flightsWithNoCoverage'));
    end

    % (Optional) Check if any flights are covered >1 times
    if ~isempty(flightsWithMultipleCoverage)
        fprintf('Note: The following flights are covered by more than one pairing:\n');
        disp(flightsWithMultipleCoverage');
    end

    % 2) Check how many flights each pairing covers
    coveragePerPairing = sum(sigma,1); % sum across rows
    pairingsNoFlights = find(coveragePerPairing == 0);
    if isempty(pairingsNoFlights)
        disp('All pairings cover at least one flight.');
    else
        warning('The following pairings do not cover any flight: %s', ...
                mat2str(pairingsNoFlights));
    end

    % 3) (Optional) Compare lengths for sanity
    if numFlights ~= height(M)
        warning('sigma has %d rows, but M has %d flights. Check indexing.', ...
                numFlights, height(M));
    end
    if numPairings ~= numel(all_pairings)
        warning('sigma has %d columns, but you passed %d pairings.', ...
                numPairings, numel(all_pairings));
    end

    disp('Validation check complete.');
end
