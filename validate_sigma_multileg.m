function validate_sigma_multileg(sigma, all_pairings)
%VALIDATE_SIGMA_MULTILEG Checks multi-leg pairings for zero coverage in sigma.
%
%   sigma is (numFlights x numPairings).
%   all_pairings is a struct array of size numPairings.
%
%   For each pairing that has multiple legs, we see whether it covers
%   any row in sigma. If coverage is zero, we warn the user.

    % Number of flights covered by each pairing:
    coverageCount = sum(sigma, 1);

    for p = 1:numel(all_pairings)
        % If the pairing has more than one leg...
        if numel(all_pairings(p).Legs) > 1
            % Check how many flights it covers in sigma
            if coverageCount(p) == 0
                warning('Multi-leg pairing p=%d does NOT cover any flights in sigma.', p);
            end
        end
    end

    disp('Finished checking multi-leg coverage in sigma.');
end
