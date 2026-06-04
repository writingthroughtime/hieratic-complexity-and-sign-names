% step_1_save_all_data.m
%
% Fetch handwriting session data from all writing-system experiments and
% save as allData_step_1.mat. Requires network access and fetch_json /
% parse_listSessions_json / parse_xyt_session_json on the MATLAB path.
%
% Output: allData_step_1.mat

clc; clear all; close all;

scriptNames   = ["Hebrew","Latin","Greek","Cyrillic","Latin Capitals","Phoenician","Aramaic"];
scriptISOs    = ["Hebr","Latn","Grek","Cyrl","Latn","Phnx","Armi"];
experimentIds = ["2c6bcb5e-6d22-42fb-9801-45e2d5ccab31", ...
                 "fc59352e-a251-4187-95dc-fe407bd1ff86", ...
                 "2f58663a-d680-4a9b-881f-d334b4a81d40", ...
                 "8bc5f8f2-117e-4229-9e9d-a5a88911e88e", ...
                 "307846ea-adaa-4cbf-a006-324dcc174d61", ...
                 "111804ec-e4f5-41d7-bb00-a5a3ff7e98e2", ...
                 "1eeff1e8-5fab-40b5-a630-0c005875da69"];

allData = [];

for idxScript = 1:numel(scriptNames)

    scriptName   = scriptNames(idxScript);
    experimentId = experimentIds(idxScript);
    fprintf('\n--- %s ---\n', scriptName);

    endpoint = sprintf( ...
        'https://mjusrdxsfxpvxvcxgpdu.supabase.co/functions/v1/listSessions?experimentId=%s', ...
        experimentId);
    listing   = parse_listSessions_json(fetch_json(endpoint));
    nSessions = numel(listing.sessions);

    sessionIdCol = strings([]);
    shapesCol    = {};
    metaCol      = {};
    expertCol    = [];
    completeCol  = [];

    for i = 1:nSessions
        fprintf('  Session %d / %d\n', i, nSessions);
        sessionId = string(listing.sessions(i).id);
        [data, meta] = session_data(scriptName, sessionId);

        isComplete = length(unique(data.label)) >= n_letters(scriptName);
        scripts    = meta.subjectDetails.scripts;
        if isempty(scripts)
            subjectIsos = strings(0,1);
        else
            subjectIsos = string({scripts([scripts.can_write] == true).script_iso});
        end
        isExpert = any(subjectIsos == scriptISOs(idxScript));

        sessionIdCol(end+1) = sessionId;      %#ok<AGROW>
        shapesCol{end+1}    = data;            %#ok<AGROW>
        metaCol{end+1}      = meta;            %#ok<AGROW>
        expertCol(end+1)    = isExpert;        %#ok<AGROW>
        completeCol(end+1)  = isComplete;      %#ok<AGROW>
    end

    scriptLabels  = repmat(scriptName, length(expertCol), 1);
    allScriptData = table(scriptLabels(:), sessionIdCol(:), shapesCol(:), metaCol(:), ...
        expertCol(:), completeCol(:), ...
        'VariableNames', {'script','sessionId','shapes','meta','expert','complete'});
    allData = [allData; allScriptData]; %#ok<AGROW>
end

save("allData_step_1", "allData", "scriptNames", "scriptISOs", "experimentIds");
fprintf('\nSaved allData_step_1.mat\n');


function n = n_letters(scriptName)
    switch lower(string(scriptName))
        case {"latin","latin_alphabet","english","latin capitals"}, n = 26;
        case {"hebrew","ivrit","phoenician","aramaic"},             n = 27;
        case {"russian","cyrillic"},                                n = 33;
        case {"greek"},                                             n = 25;
        otherwise,                                                  n = 0;
    end
end
