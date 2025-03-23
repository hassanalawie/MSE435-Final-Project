function newPairings = solve_subproblem_with_priorityqueue(flight_network, startNode, homeBase, dualValues)
% SOLVE_SUBPROBLEM_WITH_PRIORITYQUEUE
%   Example of the "new approach" using a priority queue & dynamic neighbors.

    fprintf('=== Starting PriorityQueue subproblem approach ===\n');

    % LABELS is a map: nodeID -> array of labels
    LABELS = containers.Map('KeyType','double','ValueType','any');

    % Priority queue for labels
    OPEN = PriorityQueue();  % custom class below

    % Build initial label
    initLabel.cost = 0;                  % cost so far
    initLabel.dayIndex = 1;             % day-based resource
    initLabel.dailyFlight = 0;          % daily flight time
    initLabel.totalDaysSpanned = 1;     % total days in pairing
    initLabel.deadheadsUsed = 0;        % # of deadheads used
    initLabel.path = startNode;         % store the path

    LABELS(startNode) = initLabel;      % store in map
    OPEN.insert(initLabel);             % add to priority queue

    while ~OPEN.isEmpty()
        % Pop label with smallest cost
        currentLabel = OPEN.pop();
        currentNode = currentLabel.path(end);

        % If this label is no longer present in LABELS or is dominated, skip
        if ~LABELS.isKey(currentNode)
            continue;
        end
        existing = LABELS(currentNode);
        if ~any(arrayfun(@(x) isequal(x, currentLabel), existing))
            % means it was dominated or removed
            continue;
        end

        % Expand neighbors
        neighbors = get_neighbors(flight_network, currentNode);
        for i = 1:numel(neighbors)
            nextNode = neighbors(i);
            newLabel = extend_label_priority( currentLabel, currentNode, nextNode, dualValues );

            if ~isempty(newLabel)
                % Dominance check at nextNode
                if LABELS.isKey(nextNode)
                    labelArray = LABELS(nextNode);
                else
                    labelArray = [];
                end

                [keep, updatedArray] = checkDominanceAndInsert(newLabel, labelArray);
                if keep
                    LABELS(nextNode) = updatedArray;
                    OPEN.insert(newLabel);   % push into priority queue
                end
            end
        end
    end

    % Final check: collect negative reduced cost solutions that end at homeBase
    newPairings = [];
    nodeKeys = LABELS.keys();
    for k = 1:numel(nodeKeys)
        nodeID = nodeKeys{k};
        labelArr = LABELS(nodeID);
        for Lidx = 1:numel(labelArr)
            L = labelArr(Lidx);
            % Check if L ends in homeBase & is within day-limit
            if is_terminal_node(nodeID, homeBase, L)
                % If final cost is negative, we have an improving column
                if L.cost < -1e-6
                    pairingStruct.PairingID = "Pq_" + string(rand);
                    pairingStruct.Legs = L.path;
                    pairingStruct.Cost = L.cost;  % or maybe + re-run calc
                    newPairings = [newPairings, pairingStruct]; %#ok<AGROW>
                end
            end
        end
    end
    fprintf('=== PriorityQueue subproblem done. Found %d new pairings.\n', numel(newPairings));
end


%% ------- Helpers below -------

function neighbors = get_neighbors(flight_network, node)
    % Return the list of neighbor nodes from flight_network 
    if isKey(flight_network, node)
        neighbors = flight_network(node);
    else
        neighbors = [];
    end
end

function newLabel = extend_label_priority(curLabel, fromNode, toNode, dualValues)
    % This is analogous to your 'extendLabel' logic. We'll do minimal example:
    newLabel = curLabel; 
    % Suppose cost accounts for flight pay minus dual:
    arcCost = get_arc_cost(fromNode, toNode); % placeholder
    dualVal = dualValues(toNode);            % e.g. subtract dual of flight 'toNode'
    
    newLabel.cost = newLabel.cost + arcCost - dualVal;
    
    % E.g. update flight hours, days, deadhead usage, etc. 
    if newLabel.dailyFlight + 2.0 > 8  % example flight length
        newLabel = [];
        return;
    else
        newLabel.dailyFlight = newLabel.dailyFlight + 2.0;
    end

    % If deadhead, etc. 
    % if isDeadhead(fromNode, toNode)
    %     if newLabel.deadheadsUsed >= 1
    %         newLabel = []; return;
    %     else
    %         newLabel.deadheadsUsed = newLabel.deadheadsUsed + 1;
    %     end
    % end

    newLabel.path = [curLabel.path, toNode];
end

function [keep, updatedArray] = checkDominanceAndInsert(newLabel, labelArray)
    % If dominated, keep= false
    keep = true;
    updatedArray = labelArray;

    i = 1;
    while i <= numel(updatedArray)
        L = updatedArray(i);
        if dominates(L, newLabel)
            keep = false;
            return;
        elseif dominates(newLabel, L)
            updatedArray(i) = []; 
        else
            i = i+1;
        end
    end
    updatedArray(end+1) = newLabel;
end

function flag = dominates(L1, L2)
    % resource wise check
    betterOrEq = (L1.cost <= L2.cost) && ...
                 (L1.dayIndex <= L2.dayIndex) && ...
                 (L1.dailyFlight <= L2.dailyFlight) && ...
                 (L1.totalDaysSpanned <= L2.totalDaysSpanned) && ...
                 (L1.deadheadsUsed <= L2.deadheadsUsed);
    strictlyBetterInOne = (L1.cost < L2.cost) || ...
                          (L1.dayIndex < L2.dayIndex) || ...
                          (L1.dailyFlight < L2.dailyFlight) || ...
                          (L1.totalDaysSpanned < L2.totalDaysSpanned) || ...
                          (L1.deadheadsUsed < L2.deadheadsUsed);
    flag = betterOrEq && strictlyBetterInOne;
end

function yes = is_terminal_node(nodeID, homeBase, label)
    % Return true if nodeID is the home base, and label is feasible
    % E.g. your constraint: label.totalDaysSpanned <= 4
    if nodeID == homeBase && label.totalDaysSpanned <= 4
        yes = true;
    else
        yes = false;
    end
end

function c = get_arc_cost(fromNode, toNode)
    % Just a placeholder. In practice you’d integrate hotel, per-diem, etc.
    % Possibly do: c = costParams.hotelCost + ...
    c = 10; 
end
