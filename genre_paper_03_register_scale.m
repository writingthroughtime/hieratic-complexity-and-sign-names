%% genre_paper_03_register_scale.m
% ========================================================================
%  GENRE PAPER PIPELINE — STEP 3 of 5:  the empirical register scale (§4.2)
% ========================================================================
% Port of section §4.2 of genre_analysis.py, plus paper Figs 1 and 2.
%
% Scores each New Kingdom genre by its mean SIGN-CENTERED complexity
% ("how fully are signs drawn here, for the signs they are"), with 95%
% confidence intervals from a TEXT-BLOCK bootstrap: we resample whole
% texts (with replacement) within each genre, because instances within a
% text are not independent. This yields the empirical register scale —
% careful book-hand (Kemit) at the top, rapid utilitarian writing
% (magical texts, payment lists) at the bottom.
%
% EXPECTED ANCHOR VALUES:
%   Magischer Text  -601 px  [about -657, -371]   5 texts
%   Kemit           +104 px                     212 texts
%   Medizinischer Text +119 px (only 2 texts — wide CI, thin cell)
%
% FIG 1: horizontal violins of the register scale, one row per genre,
%        with the bootstrap mean and 95% CI overlaid in black (paper Fig. 1)
% FIG 2: same grapheme (A1, G17) drawn across three registers, actual
%        outlines from the corpus (paper Fig. 2, the "money figure")
%
% Requires: genre_paper_nk_model_set.mat   (step 02)
%           genre_paper_exemplar_shapes.mat (step 00)
%           violinh.m (in this folder), iris.m (on the path)

clc; close all;
set(groot, 'defaultAxesFontName', 'Times New Roman');

%% ---- knobs -------------------------------------------------------------
nBootstrap        = 2000;    % text-block bootstrap replicates
bootstrapSeed     = 11;      % rng seed (Python used numpy seed 11; draws
                             % differ across languages, CIs match to a few px)
saveFigures       = true;
figureFolder      = fullfile('figures', 'genre_paper');
figurePosition    = [1 1 20 12]*2;   % cm, doubled (house style)

violinBandwidth   = 100;     % px, ksdensity bandwidth for the Fig 1 violins
violinRowHalfHeight = 0.38;  % half-height of a full-density violin (row units)

% Exemplar spec for Fig 2: sign, then three genres low -> high register
exemplarSpec = {
    "A1",  ["Namenliste/Onomasticon", "Administrativer Text", "Kemit"];
    "G17", ["Magischer Text",         "Administrativer Text", "Kemit"];
};
nExemplarTokens = 3;   % instances drawn per (sign, genre) cell (nearest the median)

% Fig 2 layout. Tokens are placed cumulatively by their TRUE drawn widths
% (signs are height-normalized, so wide forms take more room), and the
% axis limits are computed from the content. Distances in axis units,
% where 1 unit = the drawn height of a sign.
exemplarTokenGap       = 0.35;       % gap between tokens within a genre
exemplarPanelGap       = 1.8;        % gap between genre panels
exemplarFigurePosition = [1 1 24 8]*2;   % wide and short: one strip per sign

%% ---- load --------------------------------------------------------------
load('genre_paper_nk_model_set.mat', 'nkModelSet');
if saveFigures && ~exist(figureFolder, 'dir'); mkdir(figureFolder); end

%% ---- register score per genre -----------------------------------------
[genreGroup, genreNames] = findgroups(nkModelSet.genre);
registerScore = splitapply(@mean, nkModelSet.complexity_sign_centered, genreGroup);
tokensPerGenre = splitapply(@numel, nkModelSet.complexity_sign_centered, genreGroup);

[registerScore, scoreOrder] = sort(registerScore);   % most abbreviated first
genreNames     = genreNames(scoreOrder);
tokensPerGenre = tokensPerGenre(scoreOrder);
nGenres        = numel(genreNames);

%% ---- text-block bootstrap for 95% CIs ---------------------------------
% For each genre: collect the sign-centered complexities of each of its
% texts, then repeatedly resample TEXTS with replacement and recompute the
% genre mean. Percentiles of those means give the CI.
rng(bootstrapSeed);

confidenceLo = nan(nGenres, 1);
confidenceHi = nan(nGenres, 1);
textsPerGenre = nan(nGenres, 1);

for iGenre = 1:nGenres
    genreRows = nkModelSet(nkModelSet.genre == genreNames(iGenre), :);

    % cell array: one entry per text, holding that text's instance values
    [textGroup, ~] = findgroups(genreRows.text);
    valuesByText = splitapply(@(v) {v}, genreRows.complexity_sign_centered, textGroup);
    nTexts = numel(valuesByText);
    textsPerGenre(iGenre) = nTexts;

    bootstrapMeans = nan(nBootstrap, 1);
    for iBoot = 1:nBootstrap
        resampledTexts = randi(nTexts, nTexts, 1);            % with replacement
        pooled = vertcat(valuesByText{resampledTexts});
        bootstrapMeans(iBoot) = mean(pooled);
    end
    confidenceLo(iGenre) = prctile(bootstrapMeans,  2.5);
    confidenceHi(iGenre) = prctile(bootstrapMeans, 97.5);
end

registerScale = table(genreNames, registerScore, confidenceLo, confidenceHi, ...
    textsPerGenre, tokensPerGenre, ...
    'VariableNames', {'genre','score','ci_lo','ci_hi','texts','tokens'});

disp('§4.2 Empirical register scale (NK, sign-centered px, text bootstrap):');
disp(registerScale);
writetable(registerScale, 'genre_paper_register_scale.csv');
fprintf('Wrote genre_paper_register_scale.csv\n');

%% ======================================================================
%  FIG 1  Register scale as horizontal violins (paper Fig. 1)
%% ======================================================================
% One violin per genre showing the full distribution of sign-centered
% complexity, bottom row = most abbreviated register. The bootstrap mean
% and 95% CI from above are overlaid in black on each violin.
figure('Name', 'Fig 1: Empirical register scale'); clf;

yPositions = 1:nGenres;    % bottom = most abbreviated (magical texts)

% Row position of every observation, in register-scale order
[~, observationRow] = ismember(nkModelSet.genre, registerScale.genre);

if exist('iris', 'file')
    rowColors = iris(nGenres);
else
    rowColors = jet(nGenres);
end

violinh(nkModelSet.complexity_sign_centered, observationRow, [], ...
    'Colormap', rowColors, ...
    'Bandwidth', violinBandwidth, ...
    'ViolinWidth', violinRowHalfHeight, ...
    'FontName', 'Times New Roman');
ax = gca; hold(ax, 'on');

errorbar(ax, registerScale.score, yPositions, ...
    registerScale.score - registerScale.ci_lo, ...     % left whisker
    registerScale.ci_hi - registerScale.score, ...     % right whisker
    'horizontal', 'o', ...
    'Color', 'k', 'MarkerFaceColor', 'k', 'MarkerSize', 4, ...
    'LineWidth', 1, 'CapSize', 0);
xline(ax, 0, 'k--');

axisLabels = strings(nGenres, 1);
for iGenre = 1:nGenres
    axisLabels(iGenre) = sprintf('%s  (%d)', ...
        local_english_genre_label(registerScale.genre(iGenre)), ...
        registerScale.texts(iGenre));
end
set(ax, 'YTick', yPositions, 'YTickLabel', axisLabels);
ylim(ax, [0.3, nGenres + 0.7]);
xlabel(ax, 'Sign-controlled complexity relative to corpus mean (skeleton pixels)', ...
    'FontName', 'Times New Roman');
title(ax, {'Empirical register scale, New Kingdom', ...
       '(same-sign complexity by genre; 95% CI, texts resampled)'}, ...
    'FontName', 'Times New Roman');
grid(ax, 'on');
hold(ax, 'off');
xlim([-2000, 2000]);

local_save_figure(saveFigures, figureFolder, 'fig1_register_scale', figurePosition);

%% ======================================================================
%  FIG 2  One sign, three registers — actual outlines (paper Fig. 2)
%% ======================================================================
load('genre_paper_exemplar_shapes.mat', 'exemplar_shapes');

figure('Name', 'Fig 2: Exemplars across registers'); clf;
tiledlayout(size(exemplarSpec,1), 1, 'TileSpacing', 'compact');

glyphHeight = 1.0;   % drawing height of each sign in axis units
nExemplarRows    = size(exemplarSpec, 1);
nExemplarColumns = max(cellfun(@numel, exemplarSpec(:, 2)));

% ---- pass 1: pick every cell's tokens and measure the group widths ----
% Tokens are height-normalized, so a group's width depends on which forms
% were picked. Measuring first lets the two rows share one column grid.
pickedTokens = cell(nExemplarRows, nExemplarColumns);
cellMedians  = nan(nExemplarRows, nExemplarColumns);
groupWidths  = zeros(nExemplarRows, nExemplarColumns);

for iSign = 1:nExemplarRows
    signName    = exemplarSpec{iSign, 1};
    genreTriple = exemplarSpec{iSign, 2};

    for iGenre = 1:numel(genreTriple)
        cellRows = exemplar_shapes(exemplar_shapes.mdc == signName & ...
                                   exemplar_shapes.genre == genreTriple(iGenre), :);
        if isempty(cellRows)
            warning('No %s instances in genre "%s".', signName, genreTriple(iGenre));
            continue;
        end

        % Pick the tokens whose complexity is nearest the cell median, so
        % the drawn examples are TYPICAL, not cherry-picked extremes.
        cellMedian = median(cellRows.complexity);
        [~, nearMedianOrder] = sort(abs(cellRows.complexity - cellMedian));
        picked = cellRows(nearMedianOrder(1:min(nExemplarTokens, height(cellRows))), :);
        picked = sortrows(picked, 'complexity');

        pickedTokens{iSign, iGenre} = picked;
        cellMedians(iSign, iGenre)  = cellMedian;

        groupWidth = (height(picked) - 1) * exemplarTokenGap;
        for iToken = 1:height(picked)
            groupWidth = groupWidth + ...
                local_sign_shape_width(picked.shapes{iToken}, glyphHeight);
        end
        groupWidths(iSign, iGenre) = groupWidth;
    end
end

% ---- shared column grid: each column as wide as its widest row --------
% Both rows use the same column centers, so the genre panels line up
% vertically. Within a column, each row's token group is centered.
columnWidths  = max(groupWidths, [], 1);
columnStarts  = [0, cumsum(columnWidths(1:end-1) + exemplarPanelGap)];
columnCenters = columnStarts + columnWidths / 2;
totalWidth    = columnStarts(end) + columnWidths(end);

% ---- pass 2: draw ------------------------------------------------------
for iSign = 1:nExemplarRows
    signName    = exemplarSpec{iSign, 1};
    genreTriple = exemplarSpec{iSign, 2};

    ax = nexttile; hold(ax, 'on');
    axis(ax, 'off');

    for iGenre = 1:numel(genreTriple)
        picked = pickedTokens{iSign, iGenre};
        if isempty(picked)
            continue;
        end

        % Draw each token as filled black outlines, complexity value below
        xCursor = columnCenters(iGenre) - groupWidths(iSign, iGenre) / 2;
        for iToken = 1:height(picked)
            tokenWidth = local_sign_shape_width(picked.shapes{iToken}, glyphHeight);
            xCenter = xCursor + tokenWidth / 2;
            local_draw_sign_shapes(ax, picked.shapes{iToken}, xCenter, 0.5, glyphHeight);
            text(ax, xCenter, -0.25, sprintf('%d', round(picked.complexity(iToken))), ...
                'HorizontalAlignment', 'center', 'FontSize', 9, ...
                'FontName', 'Times New Roman');
            xCursor = xCursor + tokenWidth + exemplarTokenGap;
        end

        % Genre header with the FULL cell's median (not just the 3 drawn)
        text(ax, columnCenters(iGenre), 1.45, ...
            sprintf('%s\n(median %d px)', ...
                local_english_genre_label(genreTriple(iGenre)), ...
                round(cellMedians(iSign, iGenre))), ...
            'HorizontalAlignment', 'center', 'FontSize', 11, ...
            'FontName', 'Times New Roman');
    end

    % Row label: the grapheme
    text(ax, -1.0, 0.5, signName, 'FontSize', 16, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'FontName', 'Times New Roman');
    xlim(ax, [-1.8, totalWidth + 0.4]);
    ylim(ax, [-0.6, 1.9]);
    daspect(ax, [1 1 1]);   % keep the sign outlines' true proportions
end

sgtitle('Same grapheme drawn across genres (New Kingdom)', ...
    'FontName', 'Times New Roman', 'FontWeight', 'bold');

local_save_figure(saveFigures, figureFolder, 'fig2_exemplars', exemplarFigurePosition);

fprintf('\nNext: genre_paper_04_diachrony_genre_control.m\n');

%% ---- local functions ---------------------------------------------------
function local_draw_sign_shapes(ax, shapeSet, xCenter, yCenter, targetHeight)
% Draw one sign's outline set as filled black patches, normalized so the
% whole sign is targetHeight tall and centered at (xCenter, yCenter).
% (Same normalization idea as shapescatter.m, without pixel counter-scaling.)
    if isempty(shapeSet); return; end
    allPoints = vertcat(shapeSet{:});
    if isempty(allPoints); return; end

    centroid   = (max(allPoints,[],1) + min(allPoints,[],1)) / 2;
    signHeight = max(allPoints(:,2)) - min(allPoints(:,2));
    if signHeight == 0; signHeight = 1; end
    scale = targetHeight / signHeight;

    for iComponent = 1:numel(shapeSet)
        outline = shapeSet{iComponent};
        if isempty(outline); continue; end
        outline = (outline - centroid) * scale + [xCenter, yCenter];
        patch(ax, outline(:,1), outline(:,2), 'k', 'EdgeColor', 'none');
    end
end

function signWidth = local_sign_shape_width(shapeSet, targetHeight)
% Width of a sign as local_draw_sign_shapes will draw it: the sign is
% scaled so its full height equals targetHeight, so the drawn width is
% the bounding-box width times that same scale factor.
    if isempty(shapeSet); signWidth = 0; return; end
    allPoints = vertcat(shapeSet{:});
    if isempty(allPoints); signWidth = 0; return; end

    signHeight = max(allPoints(:,2)) - min(allPoints(:,2));
    if signHeight == 0; signHeight = 1; end
    signWidth = (max(allPoints(:,1)) - min(allPoints(:,1))) * targetHeight / signHeight;
end

function label = local_english_genre_label(germanGenre)
% English display names for the AKU-PAL Textinhalt categories that appear
% in the NK model set (used in the published figures).
    map = containers.Map( ...
        {'Magischer Text', 'Fürbitte', 'Historischer Vermerk', ...
         'Zahlungsliste', 'Prophezeiung', 'Lehre', 'Kolophon', ...
         'Namenliste/Onomasticon', 'Besuchertext', 'Literarischer Text', ...
         'Erzählung', 'Brief', 'Juristische Urkunde', ...
         'Hymnus im Götterkult', 'Haushaltsliste', 'Administrativer Text', ...
         'Gerichtsurkunde/Zeugenaussage', 'Kemit', 'Medizinischer Text'}, ...
        {'Magical text', 'Intercessory prayer', 'Historical note', ...
         'Payment list', 'Prophecy', 'Teaching (instruction)', 'Colophon', ...
         'Name list / onomasticon', 'Visitor graffito', 'Literary text', ...
         'Narrative tale', 'Letter', 'Legal document', ...
         'Divine-cult hymn', 'Household list', 'Administrative text', ...
         'Court record / testimony', 'Kemit (school book-hand)', 'Medical text'});
    key = char(germanGenre);
    if isKey(map, key)
        label = map(key);
    else
        label = char(germanGenre);   % fall back to the German label
    end
end

function local_save_figure(saveFigures, figureFolder, name, figurePosition)
    if saveFigures
        set(gcf, 'Units', 'centimeters', 'Position', figurePosition);
        exportgraphics(gcf, fullfile(figureFolder, [name '.svg']), ...
            'ContentType', 'vector');
    end
end
