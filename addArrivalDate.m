function M = addArrivalDate(M)
    % Define available dates
    possibleDates = {'01-Mar', '02-Mar', '03-Mar', '04-Mar', '05-Mar', '06-Mar'};
    
    % Map dates to numerical indices for easy increment
    dateMap = containers.Map(possibleDates, 1:numel(possibleDates));

    % Initialize ArrivalDate as Date
    M.ArrivalDate = M.Date;

    % Convert DepartureTime and ArrivalTime from cell strings to datetime
    departureTimes = datetime(strrep(M.DepartureTime, "'", ""), 'InputFormat', 'HH:mm');
    arrivalTimes = datetime(strrep(M.ArrivalTime, "'", ""), 'InputFormat', 'HH:mm');

    % Identify flights that cross midnight
    crossesMidnight = departureTimes > arrivalTimes;

    % Loop through and update ArrivalDate for flights crossing midnight
    for i = find(crossesMidnight)'
        currentDate = strrep(M.Date{i}, "'", ""); % Remove single quotes
        if dateMap.isKey(currentDate) && dateMap(currentDate) < numel(possibleDates)
            M.ArrivalDate{i} = possibleDates{dateMap(currentDate) + 1}; % Increment date
        end
    end
end
