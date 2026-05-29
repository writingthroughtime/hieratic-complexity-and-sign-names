%% Load JSON and convert to table

clear; clc

jsonFile = './corpus/corpus_frequency_mdc.json';

% Read JSON
fid = fopen(jsonFile, 'r');
raw = fread(fid, inf, 'uint8=>char')';
fclose(fid);

dataStruct = jsondecode(raw);

texts = dataStruct.data;
textIDs = fieldnames(texts);

% Preallocate (rough guess, will grow if needed)
script = {};
dateNotBefore = [];
dateNotAfter = [];
dateMean = [];
MdC = {};
count = [];
textTotal = [];   % <-- NEW

row = 0;

for i = 1:length(textIDs)

    t = texts.(textIDs{i});

    % Skip if no glyph data
    if ~isfield(t, 'sentenceGlyphs')
        continue
    end

    glyphs = t.sentenceGlyphs;
    glyphKeys = fieldnames(glyphs);

    % Dates
    d1 = t.dateNotBefore;
    d2 = t.dateNotAfter;
    dMean = (d1 + d2) / 2;

    % Script label
    s = t.script;

    % ---- NEW: compute total once per text ----
    vals = struct2array(glyphs);
    total = sum(vals);
    % -----------------------------------------

    for j = 1:length(glyphKeys)

        row = row + 1;

        script{row,1} = s;
        dateNotBefore(row,1) = d1;
        dateNotAfter(row,1) = d2;
        dateMean(row,1) = dMean;

        MdC{row,1} = glyphKeys{j};
        count(row,1) = glyphs.(glyphKeys{j});

        textTotal(row,1) = total;   % <-- NEW

    end
end

% Create table
corpus_data = table( ...
    script, ...
    dateNotBefore, ...
    dateNotAfter, ...
    dateMean, ...
    MdC, ...
    count, ...
    textTotal ...   % <-- NEW
);

% Save
save('corpus_data.mat', 'corpus_data', '-v7.3');

disp('Saved corpus_data.mat')