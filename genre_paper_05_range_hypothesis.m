%% genre_paper_05_range_hypothesis.m
% ========================================================================
%  GENRE PAPER PIPELINE — STEP 5 of 5:  the range hypothesis (§4.4)
% ========================================================================
% Port of section §4.4 of genre_analysis.py, plus paper Fig 4.
%
% HYPOTHESIS: a sign's susceptibility to genre/register is governed by its
% COMPLEXITY RANGE — signs pinned at the complexity floor (N35, X1) cannot
% respond to register; wide-range signs (A1, B1, G17) are the script's
% register instruments. Extends genre_explore_03/_04 with two safeguards:
%
%   (a) SPLIT-HALF control against circularity: eta^2 measured on one
%       random half of each sign's NK data, range on the disjoint half.
% EXPECTED CONSOLE OUTPUT (from the validated Python run):
%   n = 64 signs
%   eta2 ~ range(P90-P10):  r = 0.643, p ~ 1e-08 ; Spearman rho = 0.483
%   split-half:             r ~ 0.50, p ~ 5e-05   (RNG-dependent, approx.)
%
% Requires: genre_paper_analysis_set.mat (step 00)
%           genre_paper_representative_shapes.mat (step 00)
%           shapescatter.m (in this folder), iris.m (on the path)

clc; close all;
set(groot, 'defaultAxesFontName', 'Times New Roman');

%% ---- knobs -------------------------------------------------------------
anchorEpoch          = "Neues Reich";
minTokensPerCell     = 5;     % genre needs >= this many tokens of the sign
minGenresPerSign     = 3;     % sign needs >= this many qualifying genres
minInstancesOverall  = 15;    % sign needs >= this many instances (all epochs)
minHalfSize          = 10;    % minimum instances in each split half
splitHalfSeed        = 1;     % (Python used pandas random_state=1; different
                              %  RNG stream, so split-half r is approximate)
saveFigures    = true;
figureFolder   = fullfile('figures', 'genre_paper');
figurePosition = [1 1 20 12]*2;
signScalePx    = 22;    % approx drawn size of each sign in screen pixels (shapescatter)

%% ---- load --------------------------------------------------------------
load('genre_paper_analysis_set.mat', 'instances');
if saveFigures && ~exist(figureFolder, 'dir'); mkdir(figureFolder); end

labelledSet = instances(instances.has_genre, :);          % all epochs
nkSet       = labelledSet(labelledSet.epoche == anchorEpoch, :);

%% ---- per-sign susceptibility and range --------------------------------
rng(splitHalfSeed);
allSigns = unique(nkSet.mdc);
rows = {};

for iSign = 1:numel(allSigns)
    signName = allSigns(iSign);
    nkSign   = nkSet(nkSet.mdc == signName, :);

    % --- genre effect (eta^2) within the New Kingdom ---
    [genreGroup, genreNames] = findgroups(nkSign.genre);
    tokensPerGenre = splitapply(@numel, nkSign.complexity, genreGroup);
    bigGenres = genreNames(tokensPerGenre >= minTokensPerCell);
    if numel(bigGenres) < minGenresPerSign
        continue;
    end
    nkEligible = nkSign(ismember(nkSign.genre, bigGenres), :);
    etaSquared = local_eta2(nkEligible.complexity, nkEligible.genre);

    % --- complexity range over the WHOLE labeled corpus (all epochs) ---
    allEpochsSign = labelledSet(labelledSet.mdc == signName, :);
    if height(allEpochsSign) < minInstancesOverall
        continue;
    end
    % type-7 quantiles (numpy/pandas convention) so values match the
    % Python run exactly; MATLAB's quantile() uses a different rule
    range9010 = local_quantile_type7(allEpochsSign.complexity, 0.9) - ...
                local_quantile_type7(allEpochsSign.complexity, 0.1);
    meanComplexity = mean(allEpochsSign.complexity);

    % --- split-half (anti-circularity): per-genre 50/50 split ---
    halfAIndex = false(height(nkEligible), 1);
    [genreGroup2, ~] = findgroups(nkEligible.genre);
    for iGenre = 1:max(genreGroup2)
        genreRowIdx = find(genreGroup2 == iGenre);
        nHalf = round(numel(genreRowIdx) / 2);
        shuffled = genreRowIdx(randperm(numel(genreRowIdx)));
        halfAIndex(shuffled(1:nHalf)) = true;
    end
    halfA = nkEligible(halfAIndex, :);
    halfB = nkEligible(~halfAIndex, :);

    etaHalfA = NaN;
    if height(halfA) >= minHalfSize && numel(unique(halfA.genre)) >= 2
        etaHalfA = local_eta2(halfA.complexity, halfA.genre);
    end
    rangeHalfB = NaN;
    if height(halfB) >= minHalfSize
        rangeHalfB = local_quantile_type7(halfB.complexity, 0.9) - ...
                     local_quantile_type7(halfB.complexity, 0.1);
    end

    rows(end+1, :) = {char(signName), height(nkEligible), height(allEpochsSign), ...
        numel(bigGenres), etaSquared, range9010, meanComplexity, ...
        etaHalfA, rangeHalfB}; %#ok<SAGROW>
end

susceptibility = cell2table(rows, 'VariableNames', ...
    {'mdc','n_nk','n_all','n_genres','eta2','range_9010','mean_complexity', ...
     'eta2_half_A','range_half_B'});
susceptibility.mdc = string(susceptibility.mdc);
fprintf('§4.4 signs with estimable genre effect: %d (expected 64)\n\n', ...
    height(susceptibility));
writetable(susceptibility, 'genre_paper_sign_susceptibility.csv');

%% ---- the main test: eta^2 ~ range -------------------------------------
[rMain, pMain] = corr(susceptibility.range_9010, susceptibility.eta2);
rhoMain        = corr(susceptibility.range_9010, susceptibility.eta2, ...
                      'Type', 'Spearman');
fprintf('eta2 ~ range(P90-P10):  r = %.3f, p = %.2g ; Spearman rho = %.3f\n', ...
    rMain, pMain, rhoMain);
fprintf('  (expected: r = 0.643, p ~ 1e-08, rho = 0.483)\n\n');

%% ---- split-half control (not circular) --------------------------------
okHalves = isfinite(susceptibility.eta2_half_A) & ...
           isfinite(susceptibility.range_half_B);
[rSplit, pSplit] = corr(susceptibility.eta2_half_A(okHalves), ...
                        susceptibility.range_half_B(okHalves));
fprintf('split-half (eta2 from half A ~ range from half B):\n');
fprintf('  r = %.3f, p = %.2g (n = %d)   (expected roughly r = 0.50, p = 5e-05)\n\n', ...
    rSplit, pSplit, sum(okHalves));

%% ======================================================================
%  FIG 4  Genre susceptibility vs complexity range, signs drawn as shapes
%% ======================================================================
% Each grapheme is drawn as its actual sign outline (representative shape
% = earliest-dated attestation, saved by step 00), not as a dot.
load('genre_paper_representative_shapes.mat', 'representative_shapes');
[~, representativeRow] = ismember(susceptibility.mdc, representative_shapes.mdc);
assert(all(representativeRow > 0), 'Missing representative shapes for some signs.');
signShapes = representative_shapes.shapes(representativeRow);

figure('Name', 'Fig 4: eta2 vs range'); clf;
% shapescatter counter-scales against the on-screen axes geometry, so the
% figure must have its final size BEFORE the signs are drawn.
set(gcf, 'Units', 'centimeters', 'Position', figurePosition);
ax = gca; hold(ax, 'on');

% shapescatter freezes the limits it finds, so set them first
xPad = 0.06 * (max(susceptibility.range_9010) - min(susceptibility.range_9010));
yPad = 0.10 * (max(susceptibility.eta2) - min(susceptibility.eta2));
xlim(ax, [min(susceptibility.range_9010) - xPad, max(susceptibility.range_9010) + xPad]);
ylim(ax, [min(susceptibility.eta2) - yPad, max(susceptibility.eta2) + yPad]);

fitCoeffs = polyfit(susceptibility.range_9010, susceptibility.eta2, 1);
xFit = linspace(min(susceptibility.range_9010), max(susceptibility.range_9010), 20);
plot(ax, xFit, polyval(fitCoeffs, xFit), 'r-', 'LineWidth', 1.2);
shapescatter(signShapes, susceptibility.range_9010, susceptibility.eta2, ...
    signScalePx, [], ax);
xlabel(ax, 'Complexity range, P90 - P10 (skeleton pixels, whole corpus)', ...
    'FontName', 'Times New Roman');
ylabel(ax, 'Genre susceptibility  \eta^2 (New Kingdom)', ...
    'FontName', 'Times New Roman');
title(ax, sprintf(['A sign''s genre susceptibility is governed by its range\n' ...
    'r = %.3f, p = %.2g (n = %d)'], rMain, pMain, height(susceptibility)), ...
    'FontName', 'Times New Roman');
grid(ax, 'on');
local_save_figure(saveFigures, figureFolder, 'fig4_eta2_vs_range', figurePosition);

fprintf('\nPipeline complete.\n');

%% ---- local functions ---------------------------------------------------
function etaSquared = local_eta2(y, g)
% One-way eta^2: between-group share of total sum of squares.
% (Same as local_eta2 in genre_explore_03.m.)
    y = y(:); g = string(g(:));
    grandMean = mean(y);
    totalSS   = sum((y - grandMean).^2);
    if totalSS <= 0; etaSquared = NaN; return; end
    groupNames = unique(g);
    betweenSS = 0;
    for k = 1:numel(groupNames)
        yGroup = y(g == groupNames(k));
        betweenSS = betweenSS + numel(yGroup) * (mean(yGroup) - grandMean)^2;
    end
    etaSquared = betweenSS / totalSS;
end

function q = local_quantile_type7(x, p)
% Hyndman-Fan type-7 quantile (numpy/pandas default): linear interpolation
% at position h = (n-1)p + 1 of the sorted sample. MATLAB's quantile()
% uses a different convention, which shifts values slightly for small n.
    x = sort(x(:));
    n = numel(x);
    h = (n - 1) * p + 1;
    hFloor = floor(h);
    hCeil  = min(hFloor + 1, n);
    q = x(hFloor) + (h - hFloor) * (x(hCeil) - x(hFloor));
end

function local_save_figure(saveFigures, figureFolder, name, figurePosition)
    if saveFigures
        set(gcf, 'Units', 'centimeters', 'Position', figurePosition);
        exportgraphics(gcf, fullfile(figureFolder, [name '.svg']), ...
            'ContentType', 'vector');
    end
end
