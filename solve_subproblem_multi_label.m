function [newPairings] = solve_subproblem_multi_label(adjList, M, dualValues, costParams)
% SOLVE_SUBPROBLEM_MULTI_LABEL  Multi-label resource-constrained subproblem 
% to find negative reduced cost pairings, possibly starting expansions from
% an offset node.

    fprintf('Starting subproblem: Solving for new pairings...\n');

    nNodes = length(adjList);

    % Identify home base from node 1's first arc (as you had)
    homeBase = adjList{1}(1).departureAirport;

    % If user didn't specify partialStopFraction, default to 1.0 (full solve)
    if ~isfield(costParams,'partialStopFraction')
        costParams.partialStopFraction = 1.0;
    end

    % If user didn't specify offsetNodeIndex, default to 0
    if ~isfield(costParams,'offsetNodeIndex')
        costParams.offsetNodeIndex = 0;
    end

    % Clean up offset so it doesn't exceed nNodes
    offset = costParams.offsetNodeIndex;
    if offset < 0
        offset = 0;
    end
    startNode = 1 + offset;
    % Wrap around if needed
    if startNode > nNodes
        startNode = mod(startNode - 1, nNodes) + 1;
    end

    % Figure out how many nodes to process before stopping
    maxProcessed = round(nNodes * costParams.partialStopFraction);
    maxProcessed = max(1, min(maxProcessed, nNodes));

    % Initialize label sets
    LabelSets = cell(nNodes,1);

    % Create initial label for the chosen start node
    initLabel.flightLegs   = [];
    initLabel.dayIndex     = 1;
    initLabel.dailyFT      = 0;
    initLabel.daysUsed     = 1;
    initLabel.deadheads    = 0;
    initLabel.prevNode     = 0;
    initLabel.prevLabelIdx = 0;
    initLabel.sumDuals     = 0;

    LabelSets{startNode} = initLabel;
    openQueue = struct('node',startNode,'labelIdx',1);

    % Tracking
    processedNodes = false(nNodes, 1);
    uniqueNodesProcessed = 0;
    reportInterval = max(1, round(nNodes / 10));

    % Label-setting partial expansions
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

            if mod(uniqueNodesProcessed, reportInterval) == 0
                fprintf('Progress: %d%% complete...\n', ...
                    round((uniqueNodesProcessed / nNodes)*100));
            end

            % Stopping if partialStopFraction reached
            if uniqueNodesProcessed >= maxProcessed
                fprintf('Reached partialStopFraction => stopping expansions.\n');
                break;
            end
        end

        % Expand label from node i
        for a = 1 : numel(adjList{i})
            arc = adjList{i}(a);
            newL = extendLabel(curLabel, arc, costParams, dualValues);
            if ~isempty(newL)
                % Insert and do dominance
                [keep, newSet] = purgeDominatedLabels(newL, LabelSets{arc.to}, @checkDominance);
                if keep
                    newLabelIdx = length(newSet);
                    LabelSets{arc.to} = newSet;
                    openQueue(end+1) = struct('node', arc.to, 'labelIdx', newLabelIdx);
                end
            end
        end
    end

    fprintf('Label-setting done. Now finalizing pairings...\n');

    % Identify valid pairings
    newPairings = [];
    for nodeIdx = 1 : nNodes
        labelsHere = LabelSets{nodeIdx};
        for Lidx = 1 : numel(labelsHere)
            L = labelsHere(Lidx);
            % Must end at home base + within max duty days
            if isSameAirport(nodeIdx, L.flightLegs, homeBase) && ...
               (L.daysUsed <= costParams.maxDutyDays)

                actualCost = calculate_pairing_cost(L.flightLegs);
                redCost    = actualCost - L.sumDuals;
                if redCost < -1e-6
                    % Negative reduced cost => return it
                    pairingStruct.PairingID = "SP_" + string(rand);  
                    pairingStruct.Legs      = L.flightLegs;
                    pairingStruct.Cost      = actualCost;
                    newPairings = [newPairings, pairingStruct]; %#ok<AGROW>
                end
            end
        end
    end

    fprintf('Subproblem complete: Found %d new pairings.\n', length(newPairings));
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
            % Already used a deadhead, can't add second in same duty
            newL = [];
            return; 
        else
            newL.deadheads = newL.deadheads + 1;
        end
    end

    % Append new flight leg
    flightStruct.Date              = arc.flightDate;
    flightStruct.Duration          = arc.flightHours;
    flightStruct.DepartureAirport  = arc.departureAirport;
    flightStruct.ArrivalAirport    = arc.arrivalAirport;
    flightStruct.FlightNumber      = arc.flightNumber; 
    flightStruct.DepartureTime     = datetime(arc.departureTime, ...
                                              'ConvertFrom','posixtime','Format','HH:mm'); 
    flightStruct.ArrivalTime       = datetime(arc.arrivalTime, ...
                                              'ConvertFrom','posixtime','Format','HH:mm');

    newL.flightLegs = [newL.flightLegs, flightStruct];
    newL.dailyFT    = newDailyFT;

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
            % L1 dominates L2 => discard newLabel
            keepIt = false;
            return;
        elseif isDomFunc(newLabel, L)
            % newLabel dominates L => remove L
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
    % L1 dominates L2 if it is at least as good in all dimensions
    % and strictly better in at least one dimension
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
