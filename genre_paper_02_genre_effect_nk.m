%% genre_paper_02_genre_effect_nk.m
% ========================================================================
%  GENRE PAPER PIPELINE — STEP 2 of 5:  the genre effect (paper §4.1)
% ========================================================================
% Port of section §4.1 of genre_analysis.py.
%
% QUESTION: holding SIGN IDENTITY constant, does genre still predict how
% fully a sign is drawn? (New Kingdom only, so time is approximately held
% constant; we also check it explicitly with a date term.)
%
% Four tests, from most to least granular:
%   (a) partial eta^2 of genre after sign fixed effects (instance level)
%   (b) the same with a date control (rules out intra-NK drift)
%   (c) joint Wald test for genre with TEXT-CLUSTERED standard errors
%       (rules out within-text correlation doing the work)
%   (d) most conservative: collapse to ONE observation per text and run
%       a plain ANOVA of text-mean sign-centered complexity on genre
%
% EXPECTED CONSOLE OUTPUT (from the validated Python run):
%   model set: 15932 instances, 376 signs, 19 genres, 481 texts
%   (a) partial eta2(genre | sign) = 0.0365   F(18, ...) = 32.7, p ~ 3.6e-111
%   (b) with date control:           0.0369
%   (c) cluster-robust Wald:         p ~ 7e-156
%   (d) text-level ANOVA: n = 481, R2 = 0.087, F = 2.46, p = 0.0008
%
% Requires: genre_paper_analysis_set.mat (step 00)
%           reference_coded_dummies.m , ols_with_clustered_errors.m
% Saves:    genre_paper_nk_model_set.mat (the filtered NK set, reused by
%           step 03 for the register scale and figures)

clc; close all;

%% ---- knobs -------------------------------------------------------------
anchorEpoch       = "Neues Reich";  % epoch with the widest genre diversity
minTokensPerGenre = 100;            % genre must have >= this many instances
minTextsPerGenre  = 2;              % ...spread over >= this many texts
minGenresPerSign  = 2;              % sign must occur in >= this many genres

%% ---- build the New Kingdom model set ----------------------------------
load('genre_paper_analysis_set.mat', 'instances');

nk = instances(instances.epoche == anchorEpoch & instances.has_genre, :);

% (i) keep well-populated genres...
[genreGroup, genreNames] = findgroups(nk.genre);
tokensPerGenre = splitapply(@numel, nk.complexity, genreGroup);
textsPerGenre  = splitapply(@(t) numel(unique(t)), nk.text, genreGroup);
keepGenres = genreNames(tokensPerGenre >= minTokensPerGenre & ...
                        textsPerGenre  >= minTextsPerGenre);
nkModelSet = nk(ismember(nk.genre, keepGenres), :);

% (ii) ...then keep signs attested in >= 2 of those genres (otherwise the
% sign fixed effect absorbs the genre difference completely)
[signGroup, signNames] = findgroups(nkModelSet.mdc);
genresPerSign = splitapply(@(g) numel(unique(g)), nkModelSet.genre, signGroup);
keepSigns = signNames(genresPerSign >= minGenresPerSign);
nkModelSet = nkModelSet(ismember(nkModelSet.mdc, keepSigns), :);

fprintf('§4.1 model set: %d instances, %d signs, %d genres, %d texts\n', ...
    height(nkModelSet), numel(unique(nkModelSet.mdc)), ...
    numel(unique(nkModelSet.genre)), numel(unique(nkModelSet.text)));
fprintf('  (expected: 15932 instances, 376 signs, 19 genres, 481 texts)\n\n');

%% ---- (a,b) partial eta^2 of genre after sign fixed effects ------------
% Fit nested OLS models with fitlm; categorical() makes fitlm expand the
% factors into dummy variables automatically.
modelTable            = nkModelSet(:, {'complexity', 'date'});
modelTable.mdc        = categorical(nkModelSet.mdc);
modelTable.genre      = categorical(nkModelSet.genre);

modelSignOnly         = fitlm(modelTable, 'complexity ~ mdc');
modelSignGenre        = fitlm(modelTable, 'complexity ~ mdc + genre');
modelSignDate         = fitlm(modelTable, 'complexity ~ mdc + date');
modelSignDateGenre    = fitlm(modelTable, 'complexity ~ mdc + date + genre');

% Partial eta^2 = share of the sign-only model's RESIDUAL variance that
% genre explains: (SSE_reduced - SSE_full) / SSE_reduced
partialEta2       = (modelSignOnly.SSE - modelSignGenre.SSE) / modelSignOnly.SSE;
partialEta2DateCtl = (modelSignDate.SSE - modelSignDateGenre.SSE) / modelSignDate.SSE;

% F test comparing the nested models (equivalent of anova_lm(m0, m1))
[fStat, fPValue, dfGenre, dfResidual] = ...
    local_nested_model_f_test(modelSignOnly, modelSignGenre);

fprintf('(a) partial eta2(genre | sign) = %.4f   (expected 0.0365)\n', partialEta2);
fprintf('    F(%d, %d) = %.1f, p = %.3g       (expected F = 32.7, p ~ 3.6e-111)\n', ...
    dfGenre, dfResidual, fStat, fPValue);
fprintf('(b) with date control:           %.4f   (expected 0.0369)\n\n', partialEta2DateCtl);

%% ---- (c) joint Wald test for genre, text-clustered errors -------------
% Instances from the same text share a scribe, a writing occasion, and a
% patch of papyrus — their errors are correlated. We rebuild the sign+genre
% model with an explicit design matrix so we can (i) cluster standard
% errors by text and (ii) Wald-test the genre block jointly.
[signDummies,  ~, ~] = reference_coded_dummies(nkModelSet.mdc);
[genreDummies, genreLevels, ~] = reference_coded_dummies(nkModelSet.genre);

designMatrix = [ones(height(nkModelSet),1), signDummies, genreDummies];
genreColumns = size(designMatrix,2) - size(genreDummies,2) + 1 : size(designMatrix,2);

clusteredModel = ols_with_clustered_errors( ...
    nkModelSet.complexity, designMatrix, nkModelSet.text, ...
    ["intercept"; "mdc_" + (1:size(signDummies,2))'; "genre_" + genreLevels]);

genreBeta  = clusteredModel.beta(genreColumns);
genreVcov  = clusteredModel.Vclustered(genreColumns, genreColumns);
waldStat   = genreBeta' / genreVcov * genreBeta;   % beta' * inv(V) * beta
waldP      = chi2cdf(waldStat, numel(genreColumns), 'upper');

fprintf('(c) cluster-robust Wald (all genre coefs = 0):\n');
fprintf('    chi2(%d) = %.1f, p = %.3g   (expected p ~ 7e-156; %d text clusters)\n\n', ...
    numel(genreColumns), waldStat, waldP, clusteredModel.nClusters);

%% ---- (d) most conservative: one observation per text ------------------
% Sign-centered complexity: each instance relative to its grapheme's mean
% over the WHOLE model set. ("How fully is this sign drawn, for that sign?")
[signGroup2, ~] = findgroups(nkModelSet.mdc);
signMeans = splitapply(@mean, nkModelSet.complexity, signGroup2);
nkModelSet.complexity_sign_centered = nkModelSet.complexity - signMeans(signGroup2);

% Collapse to per-text means, then ANOVA on genre (n = number of TEXTS,
% so no within-text pseudo-replication survives at all).
[textGroup, textGenre, ~] = findgroups(nkModelSet.genre, nkModelSet.text);
textLevel = table;
textLevel.genre   = textGenre;
textLevel.mean_sign_centered = splitapply(@mean, ...
    nkModelSet.complexity_sign_centered, textGroup);
textLevel.genre = categorical(textLevel.genre);

textLevelModel = fitlm(textLevel, 'mean_sign_centered ~ genre');
[textLevelP, textLevelF] = coefTest(textLevelModel);   % all non-intercept = 0

fprintf('(d) text-level ANOVA: n = %d texts, R2 = %.3f, F = %.2f, p = %.4g\n', ...
    height(textLevel), textLevelModel.Rsquared.Ordinary, textLevelF, textLevelP);
fprintf('    (expected: n = 481, R2 = 0.087, F = 2.46, p = 0.0008)\n');

%% ---- save the model set for step 03 -----------------------------------
save('genre_paper_nk_model_set.mat', 'nkModelSet');
fprintf('\nSaved genre_paper_nk_model_set.mat\n');
fprintf('Next: genre_paper_03_register_scale.m\n');

%% ---- local functions ---------------------------------------------------
function [fStat, pValue, dfNumerator, dfDenominator] = ...
        local_nested_model_f_test(reducedModel, fullModel)
% F test for nested fitlm models (same as statsmodels anova_lm(m0, m1)).
    dfNumerator   = reducedModel.DFE - fullModel.DFE;
    dfDenominator = fullModel.DFE;
    fStat  = ((reducedModel.SSE - fullModel.SSE) / dfNumerator) / ...
             (fullModel.SSE / dfDenominator);
    pValue = fcdf(fStat, dfNumerator, dfDenominator, 'upper');
end
