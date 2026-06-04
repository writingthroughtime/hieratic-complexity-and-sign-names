
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Script: complexity_metric_tests.m
%
% Purpose
% -------
% Validate skeleton pixel count as a complexity metric by comparing its
% correlation with behavioural metrics (drawing time, path length, etc.)
% against two competing complexity metrics: perimetric complexity and
% algorithmic complexity.
%
% Three complexity metrics are computed from rasterised letter images:
%   1. Skeleton pixel count   — proxy for total pen-path length
%   2. Perimetric complexity  — P² / (4πA), boundary-to-area ratio
%   3. Algorithmic complexity — EPS file size in bytes (LZ-based proxy)
%
% These are correlated with 17 behavioural metrics from the Latin
% handwriting experiments in allData_step_2.mat.
%
% Prerequisites
% -------------
% 1. Install Python deps, rasterise SVGs, then vectorise to EPS (one-time):
%      pip install -r requirements.txt
%      python3 svg_to_tiff.py ./svgs ./tiffs --scale 4 --dpi 600
%      python3 compress_tiffs.py          (requires potrace on PATH)
%    svg_to_tiff.py produces tiffs/; compress_tiffs.py traces those TIFFs
%    with potrace and writes vector EPS to eps/. The EPS file sizes are used
%    as the algorithmic complexity proxy (sparser Bezier paths = simpler shape).
%
% 2. Generate behavioural data (one-time, requires network + MATLAB path
%    containing fetch_json / parse_*_json utilities):
%      run step_1_save_all_data.m        → allData_step_1.mat
%      run step_2_generate_kinematics.m  → allData_step_2.mat
%
% Outputs
%   figures/r_heatmap.svg                    — correlation r-value matrix
%   figures/<metric>_vs_<behavioural>.svg    — violin plot per pair
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
close all

set(groot, 'defaultAxesFontName', 'Minion Pro Hiero');

saveFigures = false;
figurePosition = [1 1 17 10]*2;

fprintf('=== complexity_metric_tests.m ===\n\n');


%% Paths

addpath('../');    % perimetric_complexity.m, violin.m


%% 1.  Complexity metrics (one value per letter)

fprintf('--- Step 1: Computing complexity metrics ---\n');

letters  = cellstr(char((1:26) + 'a' - 1)');   % {'a','b',...,'z'}
nLetters = 26;

skeleton_pixel_count        = nan(nLetters, 1);
perimetric_complexity_vals  = nan(nLetters, 1);
algorithmic_complexity      = nan(nLetters, 1);

for i = 1:nLetters

    letter   = letters{i};
    tiffPath = fullfile(tiffDir, [letter '.tiff']);

    if ~isfile(tiffPath)
        fprintf('  WARNING: %s not found; skipping.\n', tiffPath);
        continue;
    end

    img = imread(tiffPath);

    % Extract alpha channel: 4-channel TIFF → channel 4; greyscale fallback
    if size(img, 3) >= 4
        alpha = img(:,:,4);
    elseif size(img, 3) == 2
        alpha = img(:,:,2);
    else
        nCh   = size(img, 3);
        alpha = rgb2gray(img(:,:,1:min(3,nCh)));
    end

    bw = alpha > 0;

    % 2a. Skeleton pixel count
    skeleton_pixel_count(i) = nnz(bwmorph(bw, 'skel', Inf));

    % 2b. Perimetric complexity
    perimetric_complexity_vals(i) = perimetric_complexity(alpha);

    % 2c. Algorithmic complexity: vector EPS file size (potrace output).
    %     compress_tiffs.py traces each TIFF to a vector EPS via potrace.
    %     Simpler letterforms produce sparser Bezier paths → smaller files.
    %     Same description-length proxy as data_prep_01_populate_sign_list.m.
    epsPath  = fullfile(epsDir, [letter '.eps']);
    info_eps = dir(epsPath);
    if ~isempty(info_eps)
        algorithmic_complexity(i) = info_eps.bytes;
    else
        fprintf('  WARNING: %s not found — run compress_tiffs.py first.\n', epsPath);
    end

    fprintf('  [%s]  skel = %4d  perim = %6.2f  algo = %5d bytes\n', ...
        letter, skeleton_pixel_count(i), ...
        perimetric_complexity_vals(i), algorithmic_complexity(i));

end

fprintf('[OK] Complexity metrics computed.\n\n');


%% 2.  Load Latin behavioural data

fprintf('--- Step 2: Loading behavioural data ---\n');

load(dataFile, 'allData');

latinMask = (allData.script == "Latin") & logical(allData.complete);
latinData = allData(latinMask, :);

fprintf('  Complete Latin sessions found: %d\n', height(latinData));

if height(latinData) == 0
    error('No complete Latin sessions found in %s.\n', dataFile);
end

% Concatenate shapes tables across all sessions
allShapes = table();
for iSess = 1:height(latinData)
    s = latinData.shapes{iSess};
    if istable(s) && height(s) > 0
        allShapes = [allShapes; s]; %#ok<AGROW>
    end
end

fprintf('  Total shape instances: %d\n\n', height(allShapes));

% Behavioural metrics — keep only those actually present
candidateMetrics = { ...
    'drawingTime',    'pathLength',       'totalWorkProxy',  'workPerLength', ...
    'meanSpeed',      'peakSpeed',        'rmsVstar',        ...
    'meanAccel',      'peakAccel',        'rmsAstar',        ...
    'meanJerk',       'peakJerk',         'rmsJstar',        ...
    'totalTurningAbs','peakTurningAbs',   'p95TurningAbs',   'meanTurning'   };

presentMask      = cellfun(@(m) ismember(m, allShapes.Properties.VariableNames), candidateMetrics);
behavMetricNames = candidateMetrics(presentMask);
nBehav           = numel(behavMetricNames);

fprintf('Behavioural metrics available: %d\n', nBehav);
fprintf('  %s\n', behavMetricNames{:});
fprintf('\n');


%% 3.  Align complexity metrics to behavioural observations

fprintf('--- Step 3: Building per-observation arrays ---\n');

nObs          = height(allShapes);
skel_obs      = nan(nObs, 1);
perim_obs     = nan(nObs, 1);
algo_obs      = nan(nObs, 1);
letter_labels = strings(nObs, 1);

for k = 1:nObs
    lbl = lower(strtrim(string(allShapes.label(k))));
    letter_labels(k) = lbl;
    idx = find(strcmp(letters, char(lbl)), 1);
    if ~isempty(idx)
        skel_obs(k)  = skeleton_pixel_count(idx);
        perim_obs(k) = perimetric_complexity_vals(idx);
        algo_obs(k)  = algorithmic_complexity(idx);
    end
end

fprintf('[OK] Aligned %d observations across %d letters.\n\n', ...
    nObs, sum(any(isfinite([skel_obs perim_obs algo_obs]), 2)));


%% 4.  Correlation analysis

fprintf('--- Step 4: Computing correlation matrix ---\n');

complexityMets   = {skel_obs, perim_obs, algo_obs};
complexityLabels = {'Skeleton pixel count', 'Perimetric complexity', 'Algorithmic complexity'};
complexityNames  = {'skeleton', 'perimetric', 'algorithmic'};
nCmplx           = numel(complexityMets);

rMatrix = nan(nCmplx, nBehav);
pMatrix = nan(nCmplx, nBehav);

for ic = 1:nCmplx
    cx = complexityMets{ic};
    for jb = 1:nBehav
        by = allShapes.(behavMetricNames{jb});
        valid = isfinite(cx) & isfinite(by);
        if sum(valid) >= 3
            [C, P] = corrcoef(cx(valid), by(valid));
            rMatrix(ic, jb) = C(2,1);
            pMatrix(ic, jb) = P(2,1);
        end
    end
end

% Print summary table
sep = repmat('-', 1, 72);
fprintf('\n%s\n', sep);
fprintf('  %-26s', 'Metric');
for ic = 1:nCmplx
    nk = min(10, length(complexityNames{ic}));
    fprintf('  %-13s', complexityNames{ic}(1:nk));
end
fprintf('\n%s\n', sep);
for jb = 1:nBehav
    fprintf('  %-26s', behavMetricNames{jb});
    for ic = 1:nCmplx
        r = rMatrix(ic, jb);
        p = pMatrix(ic, jb);
        if isnan(r)
            fprintf('  %-10s', '—');
        elseif p < 0.001
            fprintf('  r=%+.3f ***', r);
        elseif p < 0.01
            fprintf('  r=%+.3f **', r);
        elseif p < 0.05
            fprintf('  r=%+.3f *', r);
        else
            fprintf('  r=%+.3f  ', r);
        end
    end
    fprintf('\n');
end
fprintf('%s\n\n', sep);


%% 5.  Figure 1: r-value heatmap

fprintf('--- Step 5: Heatmap figure ---\n');

figure(1); clf;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [1 1 22 8]*1.5);

imagesc(rMatrix, [-1 1]);
colormap(redblue_colormap());
colorbar;

ax = gca;
ax.XTick      = 1:nBehav;
ax.XTickLabel = behavMetricNames;
ax.XTickLabelRotation = 45;
ax.YTick      = 1:nCmplx;
ax.YTickLabel = complexityLabels;
ax.FontName   = 'Minion Pro Hiero';

title('Correlation (r): complexity metrics vs. behavioural metrics', ...
    'FontName', 'Minion Pro Hiero');
xlabel('Behavioural metric', 'FontName', 'Minion Pro Hiero');
ylabel('Complexity metric',  'FontName', 'Minion Pro Hiero');

% Annotate each cell with r value
for ic = 1:nCmplx
    for jb = 1:nBehav
        r = rMatrix(ic, jb);
        if ~isnan(r)
            if abs(r) > 0.5
                txtColor = [1 1 1];   % white on saturated cells
            else
                txtColor = [0 0 0];   % black on pale cells
            end
            text(jb, ic, sprintf('%.2f', r), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment',   'middle', ...
                'FontName', 'Minion Pro Hiero', ...
                'FontSize', 7, ...
                'Color', txtColor);
        end
    end
end

if saveFigures
    set(gcf, 'Units', 'centimeters');
    set(gcf, 'Position', [1 1 22 8]*1.5);
    exportgraphics(gcf, fullfile(figDir, 'r_heatmap.svg'), 'ContentType', 'vector');
    fprintf('[SAVED] r_heatmap.svg\n');
end

fprintf('[OK] Heatmap figure done.\n\n');


%% 6.  Violin plots: one figure per (complexity × behavioural) pair

fprintf('--- Step 6: Violin plots (%d figures) ---\n', nCmplx * nBehav);

figNum = 10;   % start numbering after the heatmap

for ic = 1:nCmplx

    cx     = complexityMets{ic};
    cLabel = complexityLabels{ic};
    cName  = complexityNames{ic};

    if all(isnan(cx))
        fprintf('  Skipping %s (all NaN).\n', cLabel);
        continue;
    end

    for jb = 1:nBehav

        mName = behavMetricNames{jb};
        by    = allShapes.(mName);

        valid = isfinite(cx) & isfinite(by);
        if sum(valid) < 3
            figNum = figNum + 1;
            continue;
        end

        figure(figNum); clf;

        violin(cx(valid), by(valid), letter_labels(valid), ...
            'XLabel', cLabel, ...
            'YLabel', mName,  ...
            'Title',  sprintf('%s vs. %s', cLabel, mName));

        if saveFigures
            set(gcf, 'Units', 'centimeters');
            set(gcf, 'Position', figurePosition);
            fname = sprintf('%s_vs_%s.svg', cName, mName);
            exportgraphics(gcf, fullfile(figDir, fname), 'ContentType', 'vector');
            fprintf('  [SAVED] %s\n', fname);
        end

        figNum = figNum + 1;

    end

end

fprintf('[OK] Violin plots done.\n\n');
fprintf('=== All done. ===\n');


%% ─── Local functions ────────────────────────────────────────────────────

function cmap = redblue_colormap(n)
% REDBLUE_COLORMAP  Blue–white–red diverging colormap.
%   cmap = redblue_colormap()        64-step default
%   cmap = redblue_colormap(N)       N-step
    if nargin < 1, n = 64; end
    half  = ceil(n / 2);
    blue  = [linspace(0.2, 1, half)', linspace(0.2, 1, half)', ones(half, 1)];
    red   = [ones(half, 1), linspace(1, 0.2, half)', linspace(1, 0.2, half)'];
    if mod(n, 2) == 0
        cmap = [blue; red];
    else
        cmap = [blue; red(2:end,:)];
    end
end
