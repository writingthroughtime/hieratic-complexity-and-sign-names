%% genre_paper_01_validate_against_companion.m
% ========================================================================
%  GENRE PAPER PIPELINE — STEP 1 of 5:  validate the slim analysis set
% ========================================================================
% Port of the "validation" section of genre_analysis.py.
%
% Before trusting any genre analysis, we reproduce the HEADLINE RESULT of
% the companion paper (its Fig. 3: information content vs. change in
% complexity) from the slim table built in step 00. If these numbers come
% out exactly, the slim set is byte-for-byte equivalent to the data behind
% change_in_complexity_tests.m and we can proceed.
%
% VALIDATION TARGETS (companion paper Fig. 3):
%   n = 52 signs,  r = 0.3755,  p = 0.0061
%
% NOTE: this runs on the FULL base set (including instances without genre
% labels) — the companion paper knew nothing about genre.
%
% Requires: genre_paper_analysis_set.mat  (from step 00)

clc; close all;

%% ---- knobs (mirror change_in_complexity_tests.m exactly) --------------
minSignsPerText     = 1;     % keep texts with text_length > this
minCountPerEpoch    = 2;     % sign must appear >= this often in EACH epoch
selectedEpochs      = [ "Altes Reich"; "Mittleres Reich"; ...
                        "Neues Reich"; "Griechisch-römische Zeit" ];

%% ---- load & filter -----------------------------------------------------
load('genre_paper_analysis_set.mat', 'instances');

validationSet = instances(instances.text_length > minSignsPerText, :);
validationSet = validationSet(ismember(validationSet.epoche, selectedEpochs), :);

% Keep only graphemes attested >= minCountPerEpoch times in EVERY epoch
keepMdc = local_mdc_with_min_count_per_epoch(validationSet, ...
    selectedEpochs, minCountPerEpoch);
validationSet = validationSet(ismember(validationSet.mdc, keepMdc), :);

fprintf('Validation set: %d instances, %d graphemes\n', ...
    height(validationSet), numel(keepMdc));

%% ---- per-sign slope and information content ---------------------------
% For each grapheme:
%   informationContent = -log(mean corpus frequency)
%   complexitySlope    = OLS slope of complexity ~ date (px per year)
nSigns = numel(keepMdc);
informationContent = nan(nSigns, 1);
complexitySlope    = nan(nSigns, 1);

for iSign = 1:nSigns
    oneSign = validationSet(validationSet.mdc == keepMdc(iSign), :);
    informationContent(iSign) = -log(mean(oneSign.frequency));

    designMatrix = [ones(height(oneSign),1), oneSign.date];
    coeffs = designMatrix \ oneSign.complexity;
    complexitySlope(iSign) = coeffs(2);
end

%% ---- the check ---------------------------------------------------------
[rValidation, pValidation] = corr(informationContent, complexitySlope);

fprintf('\nVALIDATION (companion paper Fig. 3):\n');
fprintf('  n = %d   (target: 52)\n',     nSigns);
fprintf('  r = %.4f (target: 0.3755)\n', rValidation);
fprintf('  p = %.4f (target: 0.0061)\n', pValidation);

if nSigns == 52 && abs(rValidation - 0.3755) < 5e-4
    fprintf('  PASS — slim analysis set reproduces the companion paper.\n');
    fprintf('\nNext: genre_paper_02_genre_effect_nk.m\n');
else
    warning(['Validation targets NOT reproduced — do not proceed until ', ...
             'this is resolved (check texts.csv / .mat versions).']);
end

%% ---- local functions ---------------------------------------------------
function keepMdc = local_mdc_with_min_count_per_epoch(tbl, epochs, minCount)
% Graphemes attested at least minCount times in EACH of the given epochs.
% (Same logic as the nPerEpoch block of change_in_complexity_tests.m.)
    [signGroup, signNames] = findgroups(tbl.mdc);
    nPerEpoch = zeros(numel(signNames), numel(epochs));
    for iEpoch = 1:numel(epochs)
        inEpoch = tbl.epoche == epochs(iEpoch);
        nPerEpoch(:, iEpoch) = accumarray(signGroup(inEpoch), 1, ...
                                          [numel(signNames), 1]);
    end
    keepMdc = signNames(all(nPerEpoch >= minCount, 2));
end
