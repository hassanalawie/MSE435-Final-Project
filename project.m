%%% RESTRICTED MASTER PROBLEM %%%
tic;  % Start timing the entire script
filename = 'FlightLegs.csv';
M = readtable(filename);
M = addArrivalDate(M);

% Generate single-leg pairings
disp("Generating Initial Pairings...");
pairingStartTime = tic;  % Start timing initial pairing generation
initial_pairings = generate_initial_pairings(M);
fprintf("Initial Pairings Generated (%.2f seconds)\n", toc(pairingStartTime));

% Generate multi-leg pairings (Skipped for now)
all_pairings = initial_pairings;

% Generate sigma matrix
sigmaStartTime = tic;
sigma = generate_sigma(all_pairings, M);
fprintf("Sigma Matrix Generated (%.2f seconds)\n", toc(sigmaStartTime));

% Solve RMP
rmpStartTime = tic;
c = [all_pairings.Cost]'; 
[xOpt, fval, exitflag, output, dualVariables] = solve_rmp_lp(c, sigma);
fprintf("RMP Solved (%.2f seconds)\n", toc(rmpStartTime));

% Compute reduced costs
reducedCosts = c - sigma' * dualVariables;

%%% SUBPROBLEM %%%
disp("Building Adjacency List...");
adjListStartTime = tic;
adjList = build_adjlist(M);
fprintf("Adjacency List Built (%.2f seconds)\n", toc(adjListStartTime));

% Prepare parameters for subproblem
costParams.deadheadCost = 3000;
costParams.hotelCost = 200;
costParams.perDiem = 4;
costParams.minGuarantee = 5.5 * 45;  % Minimum guarantee pay per duty
costParams.maxDailyFlight = 8;
costParams.maxDutyDays = 4;
costParams.minRestHours = 9;
% This is an heuristic I chose to make sure that we don't waste too much
% time searching through nodes
costParams.partialStopFraction = 0.2; % This will check only 20% of nodes

maxIters = 500;
i = 1;

while i <= maxIters
    costParams.offsetNodeIndex = i;

    subproblemStartTime = tic;
    newPairings = solve_subproblem_multi_label(adjList, M, dualVariables, costParams);
    fprintf("Subproblem Call #%d Solved (%.2f seconds)\n", i, toc(subproblemStartTime));

    % Merge new pairings with existing set
    all_pairings = [all_pairings, newPairings];

    % Solve the (LP) restricted master problem with the updated set
    sigma = generate_sigma(all_pairings, M);
    c = [all_pairings.Cost]'; 
    [xOpt, fval, exitflag, output, dualVariables] = solve_rmp_lp(c, sigma);

    % Compute reduced costs
    reducedCosts = c - sigma' * dualVariables;

    % Display iteration info
    fprintf("Loop %d complete. Current RMP objective = %.2f\n", i, fval);

    % -- Check if at least 50% of reducedCosts are strictly > 0
    fracPositive = sum(reducedCosts > 0) / numel(reducedCosts);
    fprintf("Fraction of reducedCosts > 0 is %.2f%%\n", 100 * fracPositive);

    if fracPositive >= 0.50
        fprintf("Stopping: 50%% or more of reduced costs are strictly > 0.\n");
        break;
    end

    fprintf("\n");
    i = i + 1;  % Move to next iteration
end

fprintf("Done. Final RMP objective = %.2f\n", fval);