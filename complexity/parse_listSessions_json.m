function out = parse_listSessions_json(jsonValue)
%PARSE_LISTSESSIONS_JSON  Parse listSessions payload into a MATLAB structure.
%
%   out = PARSE_LISTSESSIONS_JSON(jsonValue)
%
%   Input
%     jsonValue : either
%       - string/char containing raw JSON text returned by the listSessions endpoint, or
%       - struct already produced by jsondecode
%
%   Output
%     out : struct with fields:
%       - generatedAt : timestamp string from the payload (or "")
%       - filters     : struct containing the request filters (or struct())
%       - sessions    : struct array of session metadata (possibly empty)
%
%   Notes
%     - This function is pure parsing only; no web logic.
%     - Missing fields are filled with empty strings to keep the struct array uniform.
%     - sessions(i).start_at / end_at / uploaded_at are kept as strings (no datetime conversion).

% Decode if needed
if ischar(jsonValue) || isstring(jsonValue)
    data = jsondecode(jsonValue);
else
    data = jsonValue;
end

% Top-level fields
out = struct();
out.generatedAt = getfield_default(data, "generatedAt", "");

% Filters (keep as struct; if missing, return empty struct)
out.filters = struct();
if isfield(data, "filters") && isstruct(data.filters)
    out.filters = data.filters;
end

% Sessions: normalize to a struct array and then enforce uniform fields
out.sessions = struct([]);
if ~isfield(data, "sessions")
    return;
end

sess = ensure_struct_array(data.sessions);
if isempty(sess)
    out.sessions = struct([]);
    return;
end

% Define the fields you expect/use downstream
expected = [ ...
    "id", "subject_id", "experiment_id", ...
    "start_at", "end_at", "uploaded_at", ...
    "app_version", "platform", "device_model", "os_version", "locale", "timezone", ...
    "experimentTitle", "subjectDisplayName", "subjectDeviceInstallId" ...
];

% Build a uniform struct array with missing fields filled in
out.sessions = repmat(cell2struct(repmat({""}, 1, numel(expected)), cellstr(expected), 2), size(sess));

for i = 1:numel(sess)
    for f = 1:numel(expected)
        name = expected(f);
        if isfield(sess(i), name)
            v = sess(i).(name);

            % jsondecode returns [] for null; normalize nulls to ""
            if isempty(v)
                out.sessions(i).(name) = "";
            elseif ischar(v) || isstring(v)
                out.sessions(i).(name) = string(v);
            else
                % Keep non-string scalars as-is (defensive)
                out.sessions(i).(name) = v;
            end
        else
            out.sessions(i).(name) = "";
        end
    end
end

% Keep these as string scalars consistently (including those already char)
out.generatedAt = string(out.generatedAt);

% Ensure filter fields exist even when nulls appear
out.filters = normalize_nulls_to_empty(out.filters);

end

% ---------------- Helpers ----------------

function s = getfield_default(strct, fieldName, defaultVal)
if isstruct(strct) && isfield(strct, fieldName)
    s = strct.(fieldName);
else
    s = defaultVal;
end
end

function arr = ensure_struct_array(v)
% jsondecode can return struct array or cell array of structs depending on shape
if iscell(v)
    if isempty(v)
        arr = struct([]);
    else
        arr = [v{:}];
    end
elseif isstruct(v)
    arr = v;
else
    arr = struct([]);
end
end

function s = normalize_nulls_to_empty(s)
% Replace [] (JSON null) with "" for scalar struct fields.
if ~isstruct(s)
    return;
end
fn = fieldnames(s);
for i = 1:numel(fn)
    name = fn{i};
    v = s.(name);
    if isempty(v)
        s.(name) = "";
    elseif ischar(v) || isstring(v)
        s.(name) = string(v);
    end
end
end
