function newL = extendLabel(curLabel, arc, nodeData, costParams, dualValues)
% EXTENDLABEL  Takes curLabel and arc data, returns updated label 
% if feasible; else returns [].

newL = [];  % default if infeasible

% 1) Copy current label
candidate = curLabel;

% 2) Update resource usage
flightTime = arc.flightHours;
departTime = arc.departureTime;
arriveTime = arc.arrivalTime;
duration = (arriveTime - departTime);  % e.g. in hours

% Possibly cross midnight => dayIndex increment
% If crossing midnight, maybe candidate.dayIndex = candidate.dayIndex + 1; etc.
% Or if arrival is next day, handle dailyFlightTime reset if needed.

% Check if adding this flight breaks daily 8h rule:
newDailyFT = candidate.dailyFlightTime + flightTime;
if newDailyFT > 8
    return;  % infeasible
end
candidate.dailyFlightTime = newDailyFT;

% Deadhead logic (just an example)
if arc.isDeadhead
    if candidate.deadheadsUsed >= 1
        return;  % infeasible if we only allow 1 deadhead per duty
    else
        candidate.deadheadsUsed = candidate.deadheadsUsed + 1;
        % add $3000 cost once per duty
        candidate.cost = candidate.cost + costParams.deadheadCost;
    end
end

% Possibly handle 9-hr rest arcs: if arc.isRest, then dailyFlightTime=0, 
% candidate.deadheadsUsed=0, candidate.totalDays++, and add hotel/perdiem, etc.

% Minimum daily pay or normal pay:
% We assume you only apply daily pay once you 'close' a day or you actually 
% do it at the sink.  One approach is to keep track of how many hours 
% were flown so far in a day, and if we exceed or don't reach 5.5, etc.

% 3) Subproblem cost update 
% If arc covers a real flight leg (not deadhead):
%   Subtract the flight’s dual variable from cost
if arc.isRealFlight
    flightID = arc.flightID;
    candidate.cost = candidate.cost - dualValues(flightID);
end

% Add wage cost?  Possibly do that only at the end, or you can approximate 
% a small portion on each flight.  This depends on how you handle 
% the reduced cost in the subproblem.  

% 4) Feasibility checks for total days, if we exceed 4 => infeasible 
% ...
if candidate.totalDays > 4
    return;
end

% 5) Accept the extension
candidate.prevNode = arc.from;
candidate.prevLabelIdx = arc.prevLabelIdx;  % not stored in this snippet
% Append flight ID to flightCovers
if arc.isRealFlight
    candidate.flightCovers = [candidate.flightCovers, arc.flightID];
end

newL = candidate;

end

%------------------------------
function [keepLabel, updatedSet] = purgeDominatedLabels(newLabel, oldSet, isDominated)
% PURGEDOMINATEDLABELS: Insert newLabel in oldSet if it is not 
% dominated.  Also remove from oldSet any labels that are dominated 
% by newLabel.  

keepLabel = true;
updatedSet = oldSet;
i = 1;
while i <= length(updatedSet)
    L = updatedSet(i);
    if isDominated(L, newLabel)
        % existing label L is dominated by newLabel
        updatedSet(i) = [];
    elseif isDominated(newLabel, L)
        % newLabel is dominated by L => discard newLabel
        keepLabel = false;
        return;
    else
        i = i+1;
    end
end

if keepLabel
    updatedSet(end+1) = newLabel;
end
end

%------------------------------
function dom = checkDominance(L1, L2)
% CHECKDOMINANCE: L1 dominates L2 if all resource usage 
% of L1 is <= that of L2, and L1.cost <= L2.cost
%
% Return true if L1 dominates L2.

dom = false;
if (L1.dayIndex <= L2.dayIndex) && ...
   (L1.dailyFlightTime <= L2.dailyFlightTime) && ...
   (L1.deadheadsUsed <= L2.deadheadsUsed) && ...
   (L1.totalDays <= L2.totalDays) && ...
   (L1.cost <= L2.cost)
    dom = true;
end
end

%------------------------------
function pathStruct = reconstructPath(LabelSets, sinkNode, sinkLabelIdx)
% RECONSTRUCTPATH: trace backwards from (sinkNode, sinkLabelIdx) 
% to get flightCovers or the actual route

label = LabelSets{sinkNode}(sinkLabelIdx);
flightIDs = label.flightCovers;

% You can also store predecessor arcs or node references 
% if you want the actual path of arcs
curNode = sinkNode;
curLabIdx = sinkLabelIdx;

pathNodes = [];
while curNode ~= 0 
   pathNodes(end+1) = curNode; %#ok<AGROW>
   pNode = label.prevNode;
   pIdx  = label.prevLabelIdx;
   curNode = pNode;
   if curNode > 0
       label = LabelSets{curNode}(pIdx);
       curLabIdx = pIdx;
   end
end
pathNodes = fliplr(pathNodes);

pathStruct.nodeSeq = pathNodes;
pathStruct.flights = flightIDs;   % the actual covered flights
pathStruct.subproblemCost = LabelSets{sinkNode}(sinkLabelIdx).cost;

end
