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
costParams.partialStopFraction = 0.3; % This will check only 30% of nodes

% Solve the subproblem
subproblemStartTime = tic;
newPairings = solve_subproblem_multi_label(adjList, M, dualVariables, costParams);
fprintf("Subproblem Solved (%.2f seconds)\n", toc(subproblemStartTime));

% Report total execution time
fprintf("Total Execution Time: %.2f seconds\n", toc);

all_pairings = [initial_pairings, newPairings];
sigma = generate_sigma(all_pairings, M);
c = [all_pairings.Cost]'; 
[xOpt, fval, exitflag, output, dualVariables] = solve_rmp_lp(c, sigma);
reducedCosts = c - sigma' * dualVariables;