function totalCost = calculate_pairing_cost(P)
% CALCULATE_PAIRING_COST  Compute the total cost of a pairing.
%
%   P is an array of structs, each representing one flight leg.
%   Fields expected :
%     P(l).Date              (string '01-Mar')
%     P(l).Duration          (flight duration in hours, numeric)
%     P(l).DepartureAirport
%     P(l).ArrivalAirport
%     [Optionally: P(l).HotelNights or something similar]
%
% Returns:
%   totalCost = The total computed cost, accounting for:
%       * flight pay (45$/hr),
%       * per diem (4$/hr),
%       * deadhead cost (3000$ at most once),
%       * min guarantee (5.5 hr * 45$/hr),
%       * hotel cost (200$/night if known),
%       * penalty (3000$ if first departure ≠ final arrival).
%

    % Separate flight legs into daily duties.
    duties = separate_pairing_into_duties(P);
    
    totalDutyCost = 0.0;

    % Loop over each duty
    for d = 1:numel(duties)
        usedDeadhead = false;  % track whether we've used the one allowed deadhead
        duty = duties{d};

        % Basic flight pay
        flightHours = duty.total_flight_hours;
        flightPay = hours(flightHours) * 45.0;

        % Per diem cost
        perDiem = evaluate_per_diem(duty);

        % Sum of flight pay + per diem for this duty
        costForDuty = flightPay + perDiem;

        % Check if this duty triggers deadhead
        if evaluate_deadhead(duty, usedDeadhead)
            costForDuty = costForDuty + 3000.0;
            usedDeadhead = true; % only once
        end

        if require_hotel_from_duty(duty)
            costForDuty = costForDuty + 200.0;
        end

        % Check min. guarantee (5.5 hr pay)
        minGuaranteeCost = 5.5 * 45.0;
        if costForDuty < minGuaranteeCost
            costForDuty = minGuaranteeCost;
        end

        totalDutyCost = totalDutyCost + costForDuty;
    end

    % === Apply penalty if pairing does NOT return to starting base ===
    if ~isempty(P) && ~strcmp(P(1).DepartureAirport, P(end).ArrivalAirport)
        fprintf('Penalty applied: First departure (%s) != Final arrival (%s)\n', ...
                P(1).DepartureAirport, P(end).ArrivalAirport);
        totalDutyCost = totalDutyCost + 3000.0;
    end

    % Final cost
    totalCost = totalDutyCost;
end

%======================================================================
function duties = separate_pairing_into_duties(P)
% SEPARATE_PAIRING_INTO_DUTIES Splits flight legs by "Date" into distinct duties.
%   P is an array of legs.  We'll group them by P(l).Date.
%
% Returns a cell array of duty-structs: duties{d}.legs, duties{d}.total_flight_hours
%
    if isempty(P)
        duties = {};
        return;
    end

    % Build a map: day -> legs
    legsByDay = containers.Map('KeyType','double','ValueType','any');

    for l = 1:length(P)
        dayNum = date_parser(P(l).Date);
        if ~isKey(legsByDay, dayNum)
            legsByDay(dayNum) = [];
        end
        legsByDay(dayNum) = [legsByDay(dayNum), P(l)];
    end

    % For each day key, create one duty
    keysSorted = sort(cell2mat(keys(legsByDay)));
    duties = cell(1, numel(keysSorted));

    for i = 1:numel(keysSorted)
        dayKey = keysSorted(i);
        dayLegs = legsByDay(dayKey);

        % sum flight hours
        totalHrs = 0.0;
        for j = 1:length(dayLegs)
            if isnumeric(dayLegs(j).Duration)
                dur = dayLegs(j).Duration; % Use the float value directly
            else
                dur = duration(dayLegs(j).Duration{1}, 'InputFormat', 'hh:mm'); % Convert from string
            end
            totalHrs = totalHrs + dur;
        end

        dutyStruct.legs = dayLegs;
        dutyStruct.total_flight_hours = totalHrs;

        duties{i} = dutyStruct;
    end
end

%======================================================================
function yesDeadhead = evaluate_deadhead(duty, alreadyUsedDeadhead)
% EVALUATE_DEADHEAD  Return true if this duty implies a "deadhead" cost
%   policy: if any consecutive legs in the duty do not match origin->destination,
%   and we haven't used a deadhead yet, we treat that as a deadhead occurrence.
%
    if alreadyUsedDeadhead
        yesDeadhead = false;
        return;
    end

    yesDeadhead = false;
    legs = duty.legs;
    for i = 1:numel(legs)-1
        if ~strcmp(legs(i).ArrivalAirport, legs(i+1).DepartureAirport)
            yesDeadhead = true;
            break;
        end
    end
end

%======================================================================
function pd = evaluate_per_diem(duty)
% EVALUATE_PER_DIEM returns cost = $4 per flight hour for entire duty
    pd = 4.0 * hours(duty.total_flight_hours);
end

%======================================================================

function date = date_parser(d)
    if strcmp(d,'01-Mar')
        date = 1;
    elseif strcmp(d,'02-Mar')
        date = 2;
    elseif strcmp(d,'03-Mar')
        date = 3;
    elseif strcmp(d,'04-Mar')
        date = 4;
    else
        date = 5;
    end
end

%======================================================================
function yesHotel = require_hotel_from_duty(duty)
% If the start airport of the duty doesn't match the end of the duty
% airport,
% DUN DUN DUNNNNN we need to get them an airport
    if strcmp(duty.legs(1).DepartureAirport, duty.legs(numel(duty.legs)).ArrivalAirport)
        yesHotel = false;
    else
        yesHotel = true;
    end
end
