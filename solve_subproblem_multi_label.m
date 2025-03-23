function [newPairings] = solve_subproblem_multi_label(adjList, M, dualValues, costParams)
% SOLVE_SUBPROBLEM_MULTI_LABEL  Multi-label resource-constrained subproblem 
% to find negative reduced cost pairings that start and end at the same base.
%
% This version demonstrates a simple partial/dynamic pricing approach:
%   - We do not necessarily process all nodes in the label-setting queue.
%   - Instead, we have a heuristic "stop fraction" that halts expansions early.
%
% costParams fields possibly used here:
%   - maxDailyFlight
%   - maxDutyDays
%   - partialStopFraction (in range (0,1]) => fraction of 'nNodes' to process
%     before stopping.

    fprintf('Starting subproblem: Solving for new pairings...\n');
    nNodes   = length(adjList);
    homeBase = adjList{1}(1).departureAirport;  % Identify home base

    % If user didn't specify a partialStopFraction, default to 1.0 (meaning full solve)
    if ~isfield(costParams,'partialStopFraction')
        costParams.partialStopFraction = 1.0;
    end

    % Maximum count of unique nodes we plan to fully process
    maxProcessed = round( nNodes * costParams.partialStopFraction );
    maxProcessed = max(1, min(maxProcessed, nNodes)); 
    % Ensure it's at least 1, and cannot exceed nNodes

    % Initialize label structure
    LabelSets = cell(nNodes,1);

    % Initialize first label at node 1 (SOURCE)
    initLabel.flightLegs   = []; 
    initLabel.dayIndex     = 1;
    initLabel.dailyFT      = 0;
    initLabel.daysUsed     = 1;
    initLabel.deadheads    = 0;
    initLabel.prevNode     = 0;
    initLabel.prevLabelIdx = 0;
    initLabel.sumDuals     = 0;  

    LabelSets{1} = initLabel;
    openQueue = struct('node',1,'labelIdx',1);
    
    % Progress tracking variables
    reportInterval = max(1, round(nNodes / 10));  % Ensure at least every 10%
    uniqueNodesProcessed = 0;
    processedNodes = false(nNodes, 1); % Boolean array to track processed nodes

    % Label-setting process
    while ~isempty(openQueue)
        current = openQueue(end);
        openQueue(end) = [];
        i = current.node;
        labelIdx = current.labelIdx;
        curLabel = LabelSets{i}(labelIdx);

        % Only count unique nodes processed
        if ~processedNodes(i)
            processedNodes(i) = true;
            uniqueNodesProcessed = uniqueNodesProcessed + 1;
            
            % Ensure progress never exceeds 100%
            progress = min(100, (uniqueNodesProcessed / nNodes) * 100);
            if mod(uniqueNodesProcessed, reportInterval) == 0
                fprintf('Progress: %.0f%% complete...\n', progress);
            end

            % --- PARTIAL PRICING HEURISTIC: STOP IF WE'VE PROCESSED ENOUGH NODES ---
            if uniqueNodesProcessed >= maxProcessed
                fprintf('Reached partialStopFraction: stopping label expansions early.\n');
                % We could break out of the entire while-loop
                break; 
            end
        end

        % Expand label
        for a=1:numel(adjList{i})
            arc = adjList{i}(a);
            newL = extendLabel(curLabel, arc, costParams, dualValues);

            if ~isempty(newL)
                [keep, newSet] = purgeDominatedLabels(newL, LabelSets{arc.to}, @checkDominance);
                if keep
                    newLabelIdx = length(newSet);
                    LabelSets{arc.to} = newSet;
                    openQueue(end+1) = struct('node', arc.to, 'labelIdx', newLabelIdx);
                end
            end
        end
    end

    fprintf('Label-setting (partial) complete. Now finalizing pairings...\n');

    % Post-processing: identify valid pairings
    newPairings = [];
    for nodeIdx = 1:nNodes
        labArr = LabelSets{nodeIdx};
        for Lidx = 1:numel(labArr)
            L = labArr(Lidx);
            if isSameAirport(nodeIdx, L.flightLegs, homeBase) && (L.daysUsed <= costParams.maxDutyDays)
                actualCost = calculate_pairing_cost(L.flightLegs);
                redCost = actualCost - L.sumDuals;
                
                if redCost < -1e-6
                    pairingStruct.PairingID = "SP_" + string(rand);  
                    pairingStruct.Legs = L.flightLegs;
                    pairingStruct.Cost = actualCost;
                    newPairings = [newPairings, pairingStruct]; %#ok<AGROW>
                end
            end
        end
    end

    fprintf('Subproblem (partial pricing) complete: Found %d new pairings.\n', length(newPairings));
end


%==================================================================
function newL = extendLabel(curLabel, arc, costParams, dualValues)
    newL = curLabel;
    
    % Add flight hours
    newDailyFT = newL.dailyFT + arc.flightHours;
    if newDailyFT > costParams.maxDailyFlight
        newL = [];
        return;
    end

    % Handle deadheads
    if arc.isDeadhead
       if newL.deadheads >= 1
           newL = []; 
           return; 
       else
           newL.deadheads = newL.deadheads + 1;
       end
    end

    % Append new flight leg
    flightStruct.Date = arc.flightDate;
    flightStruct.Duration = arc.flightHours;
    flightStruct.DepartureAirport = arc.departureAirport;
    flightStruct.ArrivalAirport = arc.arrivalAirport;
    flightStruct.FlightNumber = arc.flightNumber; 
    flightStruct.DepartureTime = datetime(arc.departureTime, 'ConvertFrom', 'posixtime', 'Format', 'HH:mm'); 
    flightStruct.ArrivalTime = datetime(arc.arrivalTime, 'ConvertFrom', 'posixtime', 'Format', 'HH:mm');

    newL.flightLegs = [newL.flightLegs, flightStruct];
    newL.dailyFT = newDailyFT;

    % Update dual variable sum
    newL.sumDuals = newL.sumDuals + dualValues(arc.flightID);

    % Check max duty days
    if newL.daysUsed > costParams.maxDutyDays
        newL = [];
    end
end

%==================================================================
function [keepIt, newSet] = purgeDominatedLabels(newLabel, labelSet, isDomFunc)
    keepIt = true;
    
    if isempty(labelSet)
        newSet = newLabel;  
        return;
    else
        newSet = labelSet;  
    end

    i = 1;
    while i <= length(newSet)
        L = newSet(i);
        if isDomFunc(L, newLabel)
            keepIt = false;
            return;
        elseif isDomFunc(newLabel, L)
            newSet(i) = [];
        else
            i = i + 1;
        end
    end

    if keepIt
        newSet(end+1) = newLabel;  
    end
end

%==================================================================
function dom = checkDominance(L1, L2)
    dom = (L1.dayIndex <= L2.dayIndex) && ...
          (L1.dailyFT <= L2.dailyFT) && ...
          (L1.deadheads <= L2.deadheads) && ...
          (L1.daysUsed <= L2.daysUsed) && ...
          (L1.sumDuals >= L2.sumDuals);
end

%==================================================================
function yes = isSameAirport(nodeIdx, flightLegs, base)
    if isempty(flightLegs)
        yes = false;
        return;
    end

    lastLeg = flightLegs(end);
    yes = strcmp(lastLeg.ArrivalAirport, base);
end
