%% genre_paper_04_diachrony_genre_control.m
% ========================================================================
%  GENRE PAPER PIPELINE — STEP 4 of 5:  diachrony under genre control (§4.3)
% ========================================================================
% Port of section §4.3 of genre_analysis.py, plus paper Figs 3, 5, 6.
%
% QUESTION: does the companion paper's diachronic result — rarer signs
% simplify faster (IC ~ slope correlation) — survive once genre is
% controlled? Three complementary tests:
%
%   (1) GENRE-CONTROLLED SLOPES. Per-sign rates of change estimated with
%       and without genre fixed effects; correlate each set with
%       information content. (Fig 3)
%   (2) VARIANCE DECOMPOSITION (commonality analysis) of within-sign
%       complexity into: uniquely genre / shared / uniquely date. (Fig 5)
%   (3) WITHIN-GENRE DIACHRONY. Hold genre constant entirely: does
%       complexity still decline over time INSIDE single genres with real
%       time depth? Sign fixed effects, text-clustered errors. (Fig 6)
%
% EXPECTED CONSOLE OUTPUT (from the validated Python run):
%   model set: 7698 instances, 43 signs
%   (1) IC ~ slope raw:       r = 0.3936, p = 0.0090
%       IC ~ slope genre-FE:  r = 0.3863, p = 0.0105 ; slopes corr = 0.9953
%   (2) unique(genre) = 0.0774  unique(date) = 0.0098  shared = 0.0332
%   (3) Lehre                 -1.238 px/yr (p = 8.5e-10)
%       Brief                 -0.840 px/yr (p = 0.0245)
%       Administrativer Text  -0.500 px/yr (p = 0.0424)
%       Kemit                 +0.401 px/yr (p = 0.3085)   <- book-hand resists
%
% Requires: genre_paper_analysis_set.mat (step 00)
%           genre_paper_representative_shapes.mat (step 00)
%           reference_coded_dummies.m , ols_with_clustered_errors.m
%           shapescatter.m (in this folder), iris.m (on the path)

clc; close all;
set(groot, 'defaultAxesFontName', 'Times New Roman');

%% ---- knobs -------------------------------------------------------------
minSignsPerText   = 1;      % texts with text_length > this (companion-paper filter)
minCountPerEpoch  = 2;      % sign attested >= this often in EACH epoch
selectedEpochs    = [ "Altes Reich"; "Mittleres Reich"; ...
                      "Neues Reich"; "Griechisch-römische Zeit" ];

% Within-genre diachrony: only genres where a slope is even estimable
minYearSpanWithinGenre  = 300;    % genre must span >= this many years
minInstancesWithinGenre = 300;    % ...with >= this many instances
minTextsWithinGenre     = 5;      % ...from >= this many texts

saveFigures    = true;
figureFolder   = fullfile('figures', 'genre_paper');
figurePosition = [1 1 20 12]*2;
signScalePx    = 22;    % approx drawn size of each sign in screen pixels (shapescatter)
shapeColorSeed = 4;     % rng seed for shapescatter's shuffled colormap; resetting
                        % it before each Fig 3 panel gives the SAME sign the SAME
                        % color in both panels
slopeViolinSeed  = 7;     % rng seed for the Fig 6 sampling-distribution draws
nSlopeViolinDraws = 4000; % draws per genre from N(slope, se) for the Fig 6 violins
varianceFigurePosition = [1 1 20 4.5]*2;   % short: Fig 5 is a single bar

%% ---- build the diachronic model set -----------------------------------
% Same filters as the companion paper (step 01), PLUS the genre labels.
% The sign count drops from 52 to 43 purely because unlabeled instances
% fall away.
load('genre_paper_analysis_set.mat', 'instances');
if saveFigures && ~exist(figureFolder, 'dir'); mkdir(figureFolder); end

diachronicSet = instances(instances.has_genre & ...
                          instances.text_length > minSignsPerText, :);
diachronicSet = diachronicSet(ismember(diachronicSet.epoche, selectedEpochs), :);
keepMdc = local_mdc_with_min_count_per_epoch(diachronicSet, ...
    selectedEpochs, minCountPerEpoch);
diachronicSet = diachronicSet(ismember(diachronicSet.mdc, keepMdc), :);

signNames = unique(diachronicSet.mdc);   % sorted; defines row order below
nSigns    = numel(signNames);
fprintf('§4.3 model set: %d instances, %d signs (expected 7698, 43)\n\n', ...
    height(diachronicSet), nSigns);

%% ---- (1a) per-sign slopes WITHOUT genre control -----------------------
% A pooled model with per-sign intercepts AND per-sign date slopes is
% algebraically identical to fitting each sign separately, so the raw
% slopes are just per-sign OLS fits (as in change_in_complexity_tests.m).
slopeRaw           = nan(nSigns, 1);
informationContent = nan(nSigns, 1);
for iSign = 1:nSigns
    oneSign = diachronicSet(diachronicSet.mdc == signNames(iSign), :);
    coeffs  = [ones(height(oneSign),1), oneSign.date] \ oneSign.complexity;
    slopeRaw(iSign) = coeffs(2);
    informationContent(iSign) = -log2(mean(oneSign.frequency));   % bits
end

%% ---- (1b) per-sign slopes WITH genre fixed effects --------------------
% Joint model: complexity ~ signFE + genreFE + per-sign date slopes.
% Design columns: [intercept | sign dummies | genre dummies | date |
%                  signDummy .* date interactions]
% Per-sign slope = date coefficient (+ that sign's interaction term);
% the reference (alphabetically first) sign's slope is the date
% coefficient itself.
[signDummies, signDummyLevels, referenceSign] = ...
    reference_coded_dummies(diachronicSet.mdc);
[genreDummies, ~, ~] = reference_coded_dummies(diachronicSet.genre);

signDateInteractions = signDummies .* diachronicSet.date;

designMatrix = [ones(height(diachronicSet),1), signDummies, genreDummies, ...
                diachronicSet.date, signDateInteractions];
beta = designMatrix \ diachronicSet.complexity;

dateColumn         = 1 + size(signDummies,2) + size(genreDummies,2) + 1;
interactionColumns = dateColumn + 1 : size(designMatrix, 2);

slopeGenreControlled = nan(nSigns, 1);
slopeGenreControlled(signNames == referenceSign) = beta(dateColumn);
for iLevel = 1:numel(signDummyLevels)
    slopeGenreControlled(signNames == signDummyLevels(iLevel)) = ...
        beta(dateColumn) + beta(interactionColumns(iLevel));
end

%% ---- (1c) does the IC gradient survive? -------------------------------
[rRaw, pRaw] = corr(informationContent, slopeRaw);
[rAdj, pAdj] = corr(informationContent, slopeGenreControlled);
[rSlopes, ~] = corr(slopeRaw, slopeGenreControlled);

fprintf('(1) IC ~ slope, raw:       r = %.4f, p = %.4g  (expected 0.3936, 0.0090)\n', rRaw, pRaw);
fprintf('    IC ~ slope, genre-FE:  r = %.4f, p = %.4g  (expected 0.3863, 0.0105)\n', rAdj, pAdj);
fprintf('    raw vs controlled slopes: r = %.4f          (expected 0.9953)\n\n', rSlopes);

genreControlledSlopes = table(signNames, informationContent, ...
    slopeRaw, slopeGenreControlled, 'VariableNames', ...
    {'mdc','information_content','slope_raw','slope_genre_controlled'});
writetable(genreControlledSlopes, 'genre_paper_genre_controlled_slopes.csv');

%% ---- (2) variance decomposition (commonality analysis) ----------------
% Within-sign complexity = instance minus its grapheme's mean. How much of
% it does genre vs. date explain, and how much is shared (confounded)?
[signGroup, ~] = findgroups(diachronicSet.mdc);
signMeans = splitapply(@mean, diachronicSet.complexity, signGroup);
diachronicSet.complexity_sign_centered = ...
    diachronicSet.complexity - signMeans(signGroup);

commonalityTable       = diachronicSet(:, {'complexity_sign_centered', 'date'});
commonalityTable.genre = categorical(diachronicSet.genre);

rSquaredDate  = fitlm(commonalityTable, 'complexity_sign_centered ~ date').Rsquared.Ordinary;
rSquaredGenre = fitlm(commonalityTable, 'complexity_sign_centered ~ genre').Rsquared.Ordinary;
rSquaredBoth  = fitlm(commonalityTable, 'complexity_sign_centered ~ date + genre').Rsquared.Ordinary;

uniqueGenre = rSquaredBoth - rSquaredDate;
uniqueDate  = rSquaredBoth - rSquaredGenre;
sharedPart  = rSquaredDate + rSquaredGenre - rSquaredBoth;

fprintf('(2) commonality: unique(genre) = %.4f  unique(date) = %.4f  shared = %.4f\n', ...
    uniqueGenre, uniqueDate, sharedPart);
fprintf('    (expected: 0.0774, 0.0098, 0.0332)\n');
fprintf('    Reading: at any moment genre is the stronger influence; across\n');
fprintf('    centuries time is the steadier one.\n\n');

%% ---- (3) within-genre diachrony ---------------------------------------
% Inside each single genre with real time depth: sign fixed effects + date,
% standard errors clustered by text. (p-values use the normal
% approximation, matching statsmodels cluster defaults.)
fprintf('(3) within-genre slopes (sign FE, text-clustered SEs):\n');
genreList = unique(diachronicSet.genre);
withinGenreRows = {};

for iGenre = 1:numel(genreList)
    genreData = diachronicSet(diachronicSet.genre == genreList(iGenre), :);
    yearSpan  = max(genreData.date) - min(genreData.date);

    if yearSpan < minYearSpanWithinGenre || ...
       height(genreData) < minInstancesWithinGenre || ...
       numel(unique(genreData.text)) < minTextsWithinGenre
        continue;
    end

    [signDummiesG, ~, ~] = reference_coded_dummies(genreData.mdc);
    designG = [ones(height(genreData),1), signDummiesG, genreData.date];
    clustered = ols_with_clustered_errors(genreData.complexity, designG, ...
        genreData.text);
    dateCoefIndex = size(designG, 2);   % date is the last column

    fprintf('      %-24s %+.3f px/yr  (se %.3f, p = %.4g; %d inst, %d texts, %.0f yr)\n', ...
        genreList(iGenre), clustered.beta(dateCoefIndex), ...
        clustered.se(dateCoefIndex), clustered.p(dateCoefIndex), ...
        height(genreData), clustered.nClusters, yearSpan);

    withinGenreRows(end+1, :) = {char(genreList(iGenre)), height(genreData), ...
        clustered.nClusters, yearSpan, clustered.beta(dateCoefIndex), ...
        clustered.se(dateCoefIndex), clustered.p(dateCoefIndex)}; %#ok<SAGROW>
end

withinGenreSlopes = cell2table(withinGenreRows, 'VariableNames', ...
    {'genre','n_instances','n_texts','year_span','date_slope','se','p'});
withinGenreSlopes.genre = string(withinGenreSlopes.genre);
writetable(withinGenreSlopes, 'genre_paper_within_genre_slopes.csv');
fprintf('    (expected: Lehre -1.238***, Brief -0.840*, Admin -0.500*, Kemit +0.401 n.s.)\n');

%% ======================================================================
%  FIG 3  IC vs change in complexity, without / with genre control
%% ======================================================================
% Each grapheme is drawn as its actual sign outline (representative shape
% = earliest-dated attestation, saved by step 00), not as a dot.
load('genre_paper_representative_shapes.mat', 'representative_shapes');
[~, representativeRow] = ismember(signNames, representative_shapes.mdc);
assert(all(representativeRow > 0), 'Missing representative shapes for some signs.');
signShapes = representative_shapes.shapes(representativeRow);

figure('Name', 'Fig 3: IC vs slope, genre control'); clf;
% shapescatter counter-scales against the on-screen axes geometry, so the
% figure must have its final size BEFORE the signs are drawn.
set(gcf, 'Units', 'centimeters', 'Position', figurePosition);
tiledlayout(1, 2, 'TileSpacing', 'compact');

panelSpecs = { slopeRaw,             rRaw, pRaw, 'No genre control';
               slopeGenreControlled, rAdj, pAdj, 'Genre fixed effects' };
for iPanel = 1:2
    ax = nexttile; hold(ax, 'on');
    slopes = panelSpecs{iPanel, 1};

    % shapescatter freezes the limits it finds, so set them first
    xPad = 0.06 * (max(informationContent) - min(informationContent));
    yPad = 0.10 * (max(slopes) - min(slopes));
    xlim(ax, [min(informationContent) - xPad, max(informationContent) + xPad]);
    ylim(ax, [min(slopes) - yPad, max(slopes) + yPad]);

    fitCoeffs = polyfit(informationContent, slopes, 1);
    xFit = linspace(min(informationContent), max(informationContent), 20);
    plot(ax, xFit, polyval(fitCoeffs, xFit), 'r-', 'LineWidth', 1.2);
    yline(ax, 0, 'k:');
    rng(shapeColorSeed);   % same color for the same sign in both panels
    shapescatter(signShapes, informationContent, slopes, signScalePx, [], ax);
    xlabel(ax, 'Information content  -log_2(freq)  [bits]', 'FontName', 'Times New Roman');
    ylabel(ax, 'Change in complexity (px/yr)', 'FontName', 'Times New Roman');
    title(ax, sprintf('%s\nr = %.3f, p = %.4f', panelSpecs{iPanel, 4}, ...
        panelSpecs{iPanel, 2}, panelSpecs{iPanel, 3}), ...
        'FontName', 'Times New Roman');
    grid(ax, 'on');
end
local_save_figure(saveFigures, figureFolder, 'fig3_ic_slope_genre_control', figurePosition);

%% ======================================================================
%  FIG 5  Variance decomposition of within-sign complexity
%% ======================================================================
figure('Name', 'Fig 5: Variance decomposition'); clf;
ax = gca;
segments = [uniqueGenre, sharedPart, uniqueDate] * 100;   % percent
barHandle = barh(ax, 1, segments, 'stacked');
if exist('iris', 'file')
    segmentColors = iris(numel(segments));
else
    segmentColors = jet(numel(segments));
end
for iSegment = 1:numel(segments)
    barHandle(iSegment).FaceColor = segmentColors(iSegment, :);
	barHandle(iSegment).FaceAlpha = 0.8;
end

% Fit the axes to the bar exactly: no vertical whitespace above or below.
barHalfHeight = barHandle(1).BarWidth / 2;
ylim(ax, [1 - barHalfHeight, 1 + barHalfHeight]);

legend(ax, {'genre alone', 'shared (confounded)', 'date alone'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', ...
    'FontName', 'Times New Roman');
xlabel(ax, 'Share of within-sign complexity variance (%)', ...
    'FontName', 'Times New Roman');
set(ax, 'YTick', []);
title(ax, 'What moves a sign''s complexity around its own mean?', ...
    'FontName', 'Times New Roman');
grid(ax, 'on');
local_save_figure(saveFigures, figureFolder, 'fig5_variance_decomposition', ...
    varianceFigurePosition);

%% ======================================================================
%  FIG 6  Within-genre diachronic slopes (horizontal violins)
%% ======================================================================
% One violin per genre. A slope is a regression coefficient, not a cloud
% of observations, so the violin shows the slope's estimated SAMPLING
% distribution, N(slope, se), drawn with the same seed every run. It is
% the distributional rendering of the CI: the black point and whiskers
% on top give the point estimate and the 95% interval exactly.
figure('Name', 'Fig 6: Within-genre slopes'); clf;
[~, slopeOrder] = sort(withinGenreSlopes.date_slope);
orderedSlopes = withinGenreSlopes(slopeOrder, :);
nWithinGenres = height(orderedSlopes);
yPositions = 1:nWithinGenres;

rng(slopeViolinSeed);
slopeDraws = repmat(orderedSlopes.date_slope', nSlopeViolinDraws, 1) + ...
             repmat(orderedSlopes.se',         nSlopeViolinDraws, 1) .* ...
             randn(nSlopeViolinDraws, nWithinGenres);
drawRows   = repmat(yPositions, nSlopeViolinDraws, 1);

if exist('iris', 'file')
    slopeRowColors = iris(nWithinGenres);
else
    slopeRowColors = jet(nWithinGenres);
end

violinh(slopeDraws(:), drawRows(:), [], ...
    'Colormap', slopeRowColors, ...
    'Bandwidth', [], ...        % per-genre automatic ksdensity bandwidth
    'ViolinWidth', 0.38, ...
    'FontName', 'Times New Roman');
ax = gca; hold(ax, 'on');

errorbar(ax, orderedSlopes.date_slope, yPositions, ...
    1.96 * orderedSlopes.se, 'horizontal', 'o', ...
    'Color', 'k', 'MarkerFaceColor', 'k', 'MarkerSize', 4, ...
    'LineWidth', 1, 'CapSize', 0);
xline(ax, 0, 'k--');
% Display spelling: the paper uses "Kemyt", the AKU-PAL data label is "Kemit"
set(ax, 'YTick', yPositions, 'YTickLabel', ...
    replace(orderedSlopes.genre, "Kemit", "Kemyt"));
ylim(ax, [0.4, nWithinGenres + 0.6]);
xlabel(ax, 'Diachronic slope inside the genre (px/yr, sign FE, 95% CI)', ...
    'FontName', 'Times New Roman');
title(ax, 'Simplification persists within genres (except the book-hand)', ...
    'FontName', 'Times New Roman');
grid(ax, 'on');
hold(ax, 'off');
local_save_figure(saveFigures, figureFolder, 'fig6_within_genre_slopes', figurePosition);

fprintf('\nNext: genre_paper_05_range_hypothesis.m\n');

%% ---- local functions ---------------------------------------------------
function keepMdc = local_mdc_with_min_count_per_epoch(tbl, epochs, minCount)
% Graphemes attested at least minCount times in EACH of the given epochs.
    [signGroup, signNames] = findgroups(tbl.mdc);
    nPerEpoch = zeros(numel(signNames), numel(epochs));
    for iEpoch = 1:numel(epochs)
        inEpoch = tbl.epoche == epochs(iEpoch);
        nPerEpoch(:, iEpoch) = accumarray(signGroup(inEpoch), 1, ...
                                          [numel(signNames), 1]);
    end
    keepMdc = signNames(all(nPerEpoch >= minCount, 2));
end

function local_save_figure(saveFigures, figureFolder, name, figurePosition)
    if saveFigures
        set(gcf, 'Units', 'centimeters', 'Position', figurePosition);
        exportgraphics(gcf, fullfile(figureFolder, [name '.svg']), ...
            'ContentType', 'vector');
    end
end

%% Run the next in sequence

genre_paper_05_range_hypothesis;