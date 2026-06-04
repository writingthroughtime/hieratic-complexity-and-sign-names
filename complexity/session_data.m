function [data, meta] = session_data(scriptName, sessionId)
%SESSION_DATA  Fetch, clean, and annotate per-shape data for one session.
%   [data, meta] = session_data(scriptName, sessionId)
%   Requires fetch_json() and parse_xyt_session_json() on the MATLAB path.

    scriptName = lower(string(scriptName));
    sessionId  = string(sessionId);

    endpoint = sprintf( ...
        'https://mjusrdxsfxpvxvcxgpdu.supabase.co/functions/v1/getSessionData?sessionId=%s', ...
        sessionId);

    json = fetch_json(endpoint);
    [xytByShape, meta] = parse_xyt_session_json(json);

    try
        meta.subjectDetails = fetch_subject_details(meta);
    catch ME
        warning('session_data:SubjectDetailsUnavailable', '%s', ME.message);
        meta.subjectDetails = struct('ok', false, 'error', ME.message);
    end

    if ~istable(xytByShape)
        error('session_data:ExpectedTable', 'parse_xyt_session_json must return a table.');
    end

    % --- stroke-count filtering -------------------------------------------
    try
        [lettersAllow, maxStrokes] = stroke_allowances(scriptName);
        i = 1;
        while i <= height(xytByShape)
            lbl = string(xytByShape.label{i});
            idx = find(strcmp(lettersAllow, lbl), 1);
            if isempty(idx)
                warning('session_data:UnknownLabel', 'Label "%s" not in stroke_allowances.', lbl);
                i = i + 1; continue
            end
            if numel(xytByShape.strokes{i}) > maxStrokes(idx)
                xytByShape(i,:) = [];
            else
                i = i + 1;
            end
        end
    catch ME
        warning('session_data:StrokeFilterSkipped', '%s', ME.message);
    end

    % --- attach frequency, information, writingTime -----------------------
    xytByShape.frequency   = nan(height(xytByShape), 1);
    xytByShape.information = nan(height(xytByShape), 1);
    xytByShape.writingTime = nan(height(xytByShape), 1);

    [lettersFreq, frequencies] = script_frequencies(scriptName);
    for i = 1:height(xytByShape)
        lbl = xytByShape.label{i};
        idx = find(strcmp(lettersFreq, lower(lbl)), 1);
        if ~isempty(idx)
            xytByShape.frequency(i)   = frequencies(idx);
            xytByShape.information(i) = -log(frequencies(idx));
        end
        xytByShape.writingTime(i) = getDuration(xytByShape.strokes(i));
    end

    % --- attach skeleton pixel counts ------------------------------------
    xytByShape.skeletonPixelCount = nan(height(xytByShape), 1);
    [lettersSkel, skelCounts] = script_skeleton_counts(scriptName);
    for i = 1:height(xytByShape)
        lbl = xytByShape.label{i};
        idx = find(strcmp(lettersSkel, lower(lbl)), 1);
        if ~isempty(idx)
            xytByShape.skeletonPixelCount(i) = skelCounts(idx);
        end
    end

    data = xytByShape;
end


% =========================================================================
% Local: subject details
% =========================================================================

function subj = fetch_subject_details(meta)
    if ~isstruct(meta) || ~isfield(meta,'subject_id') || isempty(meta.subject_id)
        error('fetch_subject_details:BadInput', 'meta.subject_id missing.');
    end
    endpoint = sprintf( ...
        'https://mjusrdxsfxpvxvcxgpdu.supabase.co/functions/v1/subjectDetails?subjectId=%s', ...
        string(meta.subject_id));
    payload = fetch_json(endpoint);
    if ischar(payload) || (isstring(payload) && isscalar(payload))
        payload = jsondecode(payload);
    end
    if ~isstruct(payload) || ~isfield(payload,'ok')
        error('fetch_subject_details:BadPayload', 'Unexpected payload.');
    end
    subj.ok = logical(payload.ok);
    if ~subj.ok
        subj.error   = get_field_or(payload,'error','Unknown error');
        subj.subject = struct(); subj.secondLanguages = struct([]); subj.scripts = struct([]);
        return
    end
    subj.subject         = normalize_struct_fields(get_field_or(payload,'subject',struct()), ...
        {'id','device_install_id','display_name','age','sex_assigned_at_birth', ...
         'handedness','native_language_code','last_seen_at','created_at'});
    subj.secondLanguages = normalize_array(get_field_or(payload,'secondLanguages',struct([])), ...
        {'language_code','can_read','can_write','created_at','updated_at'});
    subj.scripts         = normalize_array(get_field_or(payload,'scripts',struct([])), ...
        {'script_iso','can_read','can_write','created_at','updated_at'});
end

function s = normalize_struct_fields(in, fields)
    s = struct();
    for k = 1:numel(fields), s.(fields{k}) = get_field_or(in, fields{k}, ""); end
end

function out = normalize_array(in, fields)
    if iscell(in), in = [in{:}]; end
    out = struct([]);
    if ~isstruct(in), return; end
    for i = 1:numel(in)
        r = struct();
        for k = 1:numel(fields), r.(fields{k}) = get_field_or(in(i), fields{k}, ""); end
        out(end+1,1) = r; %#ok<AGROW>
    end
end

function v = get_field_or(s, field, defaultVal)
    if isstruct(s) && isfield(s,field) && ~isempty(s.(field))
        v = s.(field);
        if ischar(v), v = string(v); end
    else
        v = defaultVal;
    end
end


% =========================================================================
% Local: per-script lookup tables
% =========================================================================

function [letters, maxStrokes] = stroke_allowances(scriptName)
    switch lower(string(scriptName))
        case {"latin","latin_alphabet","english","latin capitals"}
            letters    = cellstr(char((1:26)+'a'-1)');
            maxStrokes = [1 1 1 1 1 1 1 1 2 2 1 1 1 1 1 1 1 1 1 2 1 1 1 2 1 1]';
        case {"hebrew","ivrit"}
            letters    = cellstr(char((1:27)+'א'-1)');
            maxStrokes = [2 1 1 1 2 1 1 2 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 1 1 1]';
        case {"russian","cyrillic"}
            letters    = {'а' 'б' 'в' 'г' 'д' 'е' 'ё' 'ж' 'з' 'и' 'й' 'к' 'л' 'м' 'н' 'о' ...
                          'п' 'р' 'с' 'т' 'у' 'ф' 'х' 'ц' 'ч' 'ш' 'щ' 'ъ' 'ы' 'ь' 'э' 'ю' 'я'};
            maxStrokes = [1 1 1 1 1 1 3 2 1 1 2 2 1 1 2 1 1 2 1 2 1 2 2 1 1 1 1 1 1 1 2 3 2]';
        case {"greek"}
            letters    = cellstr(char((1:25)+'α'-1)');
            maxStrokes = [1 1 1 1 1 1 1 1 1 1 2 1 1 1 1 1 1 1 1 1 1 1 2 1 1]';
        otherwise
            warning('stroke_allowances:UnknownScript', 'Unknown script "%s".', scriptName);
            letters = {}; maxStrokes = [];
    end
end

function [letters, frequencies] = script_frequencies(scriptName)
    switch lower(string(scriptName))
        case {"latin","latin_alphabet","english","latin capitals"}
            letters     = cellstr(char((1:26)+'a'-1)');
            frequencies = [0.0820 0.0150 0.0280 0.0430 0.1270 0.0220 0.0200 0.0610 0.0700 ...
                           0.0015 0.0077 0.0400 0.0240 0.0670 0.0750 0.0190 0.0010 0.0600 ...
                           0.0630 0.0910 0.0280 0.0098 0.0240 0.0015 0.0200 0.0007]';
        case {"hebrew","ivrit","phoenician","aramaic"}
            letters     = cellstr(char((1:27)+'א'-1)');
            frequencies = [0.0634 0.0474 0.0130 0.0259 0.1087 0.1038 0.0133 0.0248 0.0124 ...
                           0.1106 0.0081 0.0270 0.0739 0.0303 0.0459 0.0110 0.0286 0.0148 ...
                           0.0323 0.0027 0.0169 0.0012 0.0124 0.0214 0.0561 0.0441 0.0501]';
        case {"russian","cyrillic"}
            letters     = {'а' 'б' 'в' 'г' 'д' 'е' 'ё' 'ж' 'з' 'и' 'й' 'к' 'л' 'м' 'н' 'о' ...
                           'п' 'р' 'с' 'т' 'у' 'ф' 'х' 'ц' 'ч' 'ш' 'щ' 'ъ' 'ы' 'ь' 'э' 'ю' 'я'};
            frequencies = [0.0764 0.0201 0.0438 0.0172 0.0309 0.0875 0.0020 0.0101 0.0148 ...
                           0.0709 0.0121 0.0330 0.0496 0.0317 0.0678 0.1118 0.0247 0.0423 ...
                           0.0497 0.0609 0.0222 0.0021 0.0095 0.0039 0.0140 0.0072 0.0030 ...
                           0.0002 0.0236 0.0184 0.0036 0.0047 0.0196]';
        case {"greek"}
            letters     = cellstr(char((1:25)+'α'-1)');
            frequencies = [0.1141 0.0068 0.0173 0.0175 0.0859 0.0034 0.0540 0.0112 0.0925 ...
                           0.0397 0.0273 0.0336 0.0620 0.0040 0.1033 0.0401 0.0429 0.0441 ...
                           0.0342 0.0792 0.0442 0.0081 0.0118 0.0013 0.0215]';
        otherwise
            error('script_frequencies:UnknownScript', 'Unknown script "%s".', scriptName);
    end
end

function [letters, counts] = script_skeleton_counts(scriptName)
    switch lower(string(scriptName))
        case {"latin","latin_alphabet","english"}
            letters = cellstr(char((1:26)+'a'-1)');
            counts  = [90 145 55 106 67 164 140 139 46 95 147 100 131 91 86 128 136 58 69 79 79 79 106 82 145 136]';
        case {"latin capitals"}
            letters = cellstr(char((1:26)+'a'-1)');
            counts  = [506 548 376 538 507 432 460 672 285 289 577 369 743 587 449 423 569 538 324 424 468 420 777 557 420 451]';
        case {"hebrew","ivrit"}
            letters = cellstr(char((1:27)+'א'-1)');
            counts  = [64 67 50 64 66 32 71 80 79 14 69 58 73 68 60 49 58 71 92 114 99 113 78 71 43 101 76]';
        case {"aramaic"}
            letters = cellstr(char((1:27)+'א'-1)');
            counts  = [329 286 235 211 246 110 176 286 321 46 233 239 232 375 362 161 183 321 321 321 337 270 287 303 182 405 372]';
        case {"phoenician"}
            letters = cellstr(char((1:27)+'א'-1)');
            counts  = [546 374 245 342 451 318 306 603 657 358 0 389 283 0 372 0 289 501 332 0 279 0 374 485 356 376 321]';
        case {"russian","cyrillic"}
            letters = {'а' 'б' 'в' 'г' 'д' 'е' 'ё' 'ж' 'з' 'и' 'й' 'к' 'л' 'м' 'н' 'о' ...
                       'п' 'р' 'с' 'т' 'у' 'ф' 'х' 'ц' 'ч' 'ш' 'щ' 'ъ' 'ы' 'ь' 'э' 'ю' 'я'}';
            counts  = [84 113 117 50 130 71 75 148 116 82 90 88 59 98 83 64 76 97 48 117 147 146 78 105 59 123 141 72 96 55 58 100 80]';
        case {"greek"}
            letters = cellstr(char((1:25)+'α'-1)');
            counts  = [107 166 169 131 89 190 125 157 85 132 125 114 97 191 79 137 93 75 74 60 101 95 134 192 137]';
        otherwise
            error('script_skeleton_counts:UnknownScript', 'Unknown script "%s".', scriptName);
    end
    counts = counts(:);
end
