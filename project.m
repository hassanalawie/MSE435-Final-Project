%%% RESTRICTED MASTER PROBLEM %%%%

filename = 'FlightLegs.csv';
M = readtable(filename);
M = addArrivalDate(M);

% Generate single-leg pairings
% This will give us a 1 x 2512 struct where each struct has properties
% PairingID(string), 
% Legs (1 x 1 struct with properties Date, Duration, DepartureTime, ArrivalTime, DepartureAirport, ArrivalAirport, Aircraft, Airline, FlightNumber), 
% Cost (float)
 disp("Generating Initial Pairings...")
 initial_pairings = generate_initial_pairings(M);
 disp("Initial Pairings Generated")
% Generate multi-leg pairings
% I DITCHED THIS BECAUSE WE DON'T NEED THESE FOR INITIAL, too much work
% multi_leg_pairings = generate_feasible_pairings(M);
% Combine both single-leg and multi-leg pairings
% all_pairings = [initial_pairings, multi_leg_pairings];


all_pairings = initial_pairings;

% Generate sigma matrix. Sigma is a matrix that says if flight f is covered
% by pairing p, in this case initially it is an N x N identity matrix,
% where N is the number of flights
sigma = generate_sigma(all_pairings, M);

% Solve RMP
c = [all_pairings.Cost]'; 
% This will just call linprog and return the relevant variables
[xOpt, fval, exitflag, output, dualVariables] = solve_rmp_lp(c, sigma);

% Compute reduced costs
reducedCosts = c - sigma' * dualVariables;


%%% SUBPROBLEM %%%%
disp("Building Adjacency List...")
adjList = build_adjlist(M);
disp("Adjacency List Built")

% Prepare parameters for subproblem
costParams.deadheadCost = 3000;
costParams.hotelCost = 200;
costParams.perDiem = 4;
costParams.minGuarantee = 5.5 * 45;  % Minimum guarantee pay per duty
costParams.maxDailyFlight = 8;
costParams.maxDutyDays = 4;
costParams.minRestHours = 9;


newPairings = solve_subproblem_multi_label(adjList, M, dualVariables, costParams);

