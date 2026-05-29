%% TEST: Do more frequent signs simplify over time IFF they start out complex?
%
% Hypothesis:
%   More frequent signs (lower information content) simplify over time
%   only when they start out complex.
%
% Operationalization:
%   information = -log(in_epoch_frequency)
%   complexity  = algorithmic_complexity
%   initial complexity = mean complexity during Old Kingdom baseline
%
% Core prediction:
%   In a model complexity ~ Time * Info * InitC,
%   the coefficient for Time:Info:InitC should be POSITIVE.
%
% Why positive?
%   As information increases (rarer signs), the slope over time should become
%   less negative or more positive, especially for signs with high initial complexity.
%   Therefore lower information (more frequent signs) should show the strongest simplification.

%%
clc
close all

load('sign_list.mat', 'sign_list');
head(sign_list)

%% Epoch list

epochs = [
	% "Frühdynastische Zeit"
    "Altes Reich"
    "Erste Zwischenzeit"
    "Mittleres Reich"
    "Zweite Zwischenzeit"
    "Neues Reich"
    "Dritte Zwischenzeit"
    "Spätzeit"
    "Griechisch-römische Zeit"
];

%%

% Keep only rows where the TIFF was found
try
	sign_list = sign_list(sign_list.file_found, :);
	sign_list.file_found = [];
catch
	disp('Sign list not reloaded, already filtered for valid files.');
end

%% Plot all shapes (to figure out what the complexity metrics are all fubar)

figure(1);
plot_sign_list(sign_list(1:10,:));

%% Excerpt data for visual clarity in the plots
filtered_sign_list = sign_list;

% Excerpt signs in texts with at least minSigns
minSigns = 10
filtered_sign_list = filtered_sign_list(filtered_sign_list.text_length > minSigns, :);

% Excerpt signs with a frequency greater than minFreq
minFreq = 0.0
filtered_sign_list = filtered_sign_list(filtered_sign_list.frequency > minFreq, :);

% Excerpt signs that appear in the selected epochs
selectedEpochs = epochs
% selectedEpochs = [ "Altes Reich", "Mittleres Reich", "Neues Reich" ]
% selectedEpochs = [ "Altes Reich", "Neues Reich" ]
filtered_sign_list = filtered_sign_list(ismember(filtered_sign_list.epoche, selectedEpochs), :);

% Select mdc values that appear at least minCount times in EACH epoch
minCount = 1;

epochCats = categorical(filtered_sign_list.epoche, selectedEpochs, 'Ordinal', true);
[G2, uniqueMDC2] = findgroups(filtered_sign_list.mdc);

nGroups = numel(uniqueMDC2);
nEpochs = numel(selectedEpochs);
nPerEpoch = zeros(nGroups, nEpochs);

for k = 1:nGroups
    idx = (G2 == k);
    nPerEpoch(k, :) = accumarray(double(epochCats(idx)), 1, [nEpochs, 1])';
end

keepMask = all(nPerEpoch >= minCount, 2);

keepMDC2 = uniqueMDC2(keepMask);
filtered_sign_list = filtered_sign_list(ismember(filtered_sign_list.mdc, keepMDC2), :);

% Show me what you got
disp(sprintf('Dataset includes %i distinct signs in %i instances', ...
	numel(unique(filtered_sign_list.mdc)), height(filtered_sign_list)));

T = filtered_sign_list;

%% --- 1. Clean data ---

% Keep rows with usable dating, frequency, grapheme, sign, and complexity
T = T(~isnan(T.epoch_date) & ...
      T.in_epoch_frequency > 0 & ...
      ~isnan(T.algorithmic_complexity) & ...
      ~isnan(T.grapheme_id) & ...
      ~isnan(T.sign_id), :);

% Choose complexity metric
T.complexity = T.algorithmic_complexity;

% Information content: higher = rarer
T.info = -log(T.in_epoch_frequency + 1e-10);

% Time: increasing toward the present
T.time_raw = T.epoch_date;
T.time = (T.time_raw - mean(T.time_raw, 'omitnan')) ./ std(T.time_raw, 'omitnan');

%% --- 2. Define Old Kingdom baseline for initial complexity ---
%
% Adjust this mask if you want a different baseline definition.
% Approximate Old Kingdom range: 2686-2181 BCE
% With negative year numbering: [-2686, -2181]

okMask = T.epoch_date >= -2686 & T.epoch_date <= -2181;

% Fallback if the mask is too sparse:
% If too few rows survive, switch to earliest quantile of time.
if sum(okMask) < 50
    cutoff = quantile(T.epoch_date, 0.20);
    okMask = T.epoch_date <= cutoff;
    fprintf('\nOld Kingdom mask too sparse. Using earliest 20%% of dated material as baseline.\n');
end

%% --- 3. Compute initial complexity per grapheme ---

[G0, g0] = findgroups(T.grapheme_id(okMask));
initComplexity = splitapply(@(x) mean(x, 'omitnan'), T.complexity(okMask), G0);

initTbl = table(g0, initComplexity, ...
    'VariableNames', {'grapheme_id','InitC_raw'});

% Merge back into token-level table
T = outerjoin(T, initTbl, 'Keys', 'grapheme_id', 'MergeKeys', true, 'Type', 'left');

% Remove graphemes with no baseline estimate
T = T(~isnan(T.InitC_raw), :);

%% --- 4. Center predictors for interaction models ---

T.InitC = T.InitC_raw - mean(T.InitC_raw, 'omitnan');
T.Info  = T.info      - mean(T.info, 'omitnan');
T.Time  = T.time      - mean(T.time, 'omitnan');

%% --- 5. Aggregate per grapheme x time for grapheme-level trajectories ---

[G, grapheme_id, time_vals] = findgroups(T.grapheme_id, T.Time);

meanComplexity = splitapply(@(c,f) sum(c .* f, 'omitnan') ./ sum(f, 'omitnan'), ...
    T.complexity, T.in_epoch_frequency, G);

meanInfo = splitapply(@(x) mean(x, 'omitnan'), T.Info, G);
meanInit = splitapply(@(x) mean(x, 'omitnan'), T.InitC, G);

aggTbl = table(meanComplexity, time_vals, meanInfo, meanInit, grapheme_id, ...
    'VariableNames', {'Mean','Time','Info','InitC','Grapheme'});

aggTbl = aggTbl(~isnan(aggTbl.Mean) & ~isnan(aggTbl.Time) & ...
                ~isnan(aggTbl.Info) & ~isnan(aggTbl.InitC), :);

aggTbl.Grapheme = categorical(aggTbl.Grapheme);

%% --- 6. Main aggregated model ---
%
% Key test:
%   Time:Info:InitC > 0
%
% Meaning:
%   Among initially complex signs, rarer signs resist simplification
%   relative to frequent ones.

lme_agg = fitlme(aggTbl, 'Mean ~ Time * Info * InitC + (1|Grapheme)');

disp(' ');
disp('AGGREGATED MODEL: Mean ~ Time * Info * InitC + (1|Grapheme)');
disp(lme_agg.Coefficients);

fprintf('\nINTERPRETATION (AGGREGATED MODEL):\n');
idx3 = strcmp(lme_agg.Coefficients.Name, 'Time:Info:InitC');
if any(idx3)
    fprintf('Time:Info:InitC = %.4f\n', lme_agg.Coefficients.Estimate(idx3));
else
    fprintf('Time:Info:InitC term not found. Check coefficient naming.\n');
end

%% --- 7. Full token-level model ---
%
% This is the stronger version.
% Random intercepts for grapheme and sign.
%
% Again, the key term is Time:Info:InitC.

T.grapheme_id = categorical(T.grapheme_id);
T.sign_id = categorical(T.sign_id);

lme_full = fitlme(T, ...
    'complexity ~ Time * Info * InitC + (1|grapheme_id) + (1|sign_id)');

disp(' ');
disp('FULL MODEL (token-level): complexity ~ Time * Info * InitC + (1|grapheme_id) + (1|sign_id)');
disp(lme_full.Coefficients);

fprintf('\nINTERPRETATION (FULL MODEL):\n');
idx3f = strcmp(lme_full.Coefficients.Name, 'Time:Info:InitC');
if any(idx3f)
    fprintf('Time:Info:InitC = %.4f\n', lme_full.Coefficients.Estimate(idx3f));
else
    fprintf('Time:Info:InitC term not found. Check coefficient naming.\n');
end

%% --- 8. Per-grapheme slopes for visualization ---
%
% For each grapheme, estimate complexity slope over time.
% Then relate the slope to information and initial complexity.

graphemes = categories(T.grapheme_id);
nG = numel(graphemes);

slope = NaN(nG,1);
meanInfoByG = NaN(nG,1);
initByG = NaN(nG,1);
nObs = NaN(nG,1);
nTime = NaN(nG,1);

for i = 1:nG
    idx = T.grapheme_id == graphemes{i};
    sub = T(idx,:);
    
    nObs(i) = height(sub);
    nTime(i) = numel(unique(sub.Time));
    
    % Require enough distinct time points
    if height(sub) >= 6 && numel(unique(sub.Time)) >= 3
        p = polyfit(sub.Time, sub.complexity, 1);
        slope(i) = p(1);
        meanInfoByG(i) = mean(sub.Info, 'omitnan');
        initByG(i) = mean(sub.InitC, 'omitnan');
    end
end

slopeTbl = table(categorical(graphemes), slope, meanInfoByG, initByG, nObs, nTime, ...
    'VariableNames', {'Grapheme','Slope','Info','InitC','NObs','NTime'});

slopeTbl = slopeTbl(~isnan(slopeTbl.Slope) & ~isnan(slopeTbl.Info) & ~isnan(slopeTbl.InitC), :);

%% --- 9. Slope-level regression as a sanity check ---

mdl_slope = fitlm(slopeTbl, 'Slope ~ Info * InitC');

disp(' ');
disp('SLOPE-LEVEL MODEL: Slope ~ Info * InitC');
disp(mdl_slope);

%% --- 10. Make high/low groups for visualization ---

medInfo = median(slopeTbl.Info, 'omitnan');
medInit = median(slopeTbl.InitC, 'omitnan');

isLowInfo  = slopeTbl.Info <= medInfo;  % more frequent
isHighInfo = slopeTbl.Info >  medInfo;  % less frequent
isLowInit  = slopeTbl.InitC <= medInit;
isHighInit = slopeTbl.InitC >  medInit;

groupLabel = strings(height(slopeTbl),1);
groupLabel(isLowInfo  & isLowInit)  = "Frequent + initially simple";
groupLabel(isLowInfo  & isHighInit) = "Frequent + initially complex";
groupLabel(isHighInfo & isLowInit)  = "Rare + initially simple";
groupLabel(isHighInfo & isHighInit) = "Rare + initially complex";

slopeTbl.Group = categorical(groupLabel);

%% --- 11. Plot 1: slope by information, colored by initial complexity ---

figure(1); clf;
scatter(slopeTbl.Info, slopeTbl.Slope, 40, slopeTbl.InitC, 'filled');
xlabel('Information content, centered (-log frequency)');
ylabel('Complexity slope over time');
title('Complexity change over time by information and initial complexity');
cb = colorbar;
ylabel(cb, 'Initial complexity (centered)');
grid on;
hold on;

xline(medInfo, '--');
yline(0, '--');
hold off;

%% --- 12. Plot 2: four-group boxplot of slopes ---

figure(2); clf;
boxchart(slopeTbl.Group, slopeTbl.Slope);
ylabel('Complexity slope over time');
title('Slope by frequency-information x initial complexity group');
grid on;
yline(0, '--');

%% --- 13. Plot 3: predicted trajectories from aggregated model ---
%
% Show the four combinations:
%   frequent/rare x initially simple/complex

figure(3); clf; hold on;

tGrid = linspace(min(aggTbl.Time), max(aggTbl.Time), 100)';

lowInfoVal  = quantile(aggTbl.Info, 0.25);
highInfoVal = quantile(aggTbl.Info, 0.75);
lowInitVal  = quantile(aggTbl.InitC, 0.25);
highInitVal = quantile(aggTbl.InitC, 0.75);

predTbl1 = table(tGrid, repmat(lowInfoVal,  size(tGrid)), repmat(highInitVal, size(tGrid)), ...
    categorical(repmat(string(aggTbl.Grapheme(1)), size(tGrid))), ...
    'VariableNames', {'Time','Info','InitC','Grapheme'});

predTbl2 = table(tGrid, repmat(highInfoVal, size(tGrid)), repmat(highInitVal, size(tGrid)), ...
    categorical(repmat(string(aggTbl.Grapheme(1)), size(tGrid))), ...
    'VariableNames', {'Time','Info','InitC','Grapheme'});

predTbl3 = table(tGrid, repmat(lowInfoVal,  size(tGrid)), repmat(lowInitVal, size(tGrid)), ...
    categorical(repmat(string(aggTbl.Grapheme(1)), size(tGrid))), ...
    'VariableNames', {'Time','Info','InitC','Grapheme'});

predTbl4 = table(tGrid, repmat(highInfoVal, size(tGrid)), repmat(lowInitVal, size(tGrid)), ...
    categorical(repmat(string(aggTbl.Grapheme(1)), size(tGrid))), ...
    'VariableNames', {'Time','Info','InitC','Grapheme'});

y1 = predict(lme_agg, predTbl1);
y2 = predict(lme_agg, predTbl2);
y3 = predict(lme_agg, predTbl3);
y4 = predict(lme_agg, predTbl4);

plot(tGrid, y1, 'LineWidth', 2, 'DisplayName', 'Frequent + initially complex');
plot(tGrid, y2, 'LineWidth', 2, 'DisplayName', 'Rare + initially complex');
plot(tGrid, y3, 'LineWidth', 2, 'DisplayName', 'Frequent + initially simple');
plot(tGrid, y4, 'LineWidth', 2, 'DisplayName', 'Rare + initially simple');

xlabel('Time (centered)');
ylabel('Predicted algorithmic complexity');
title('Predicted trajectories from Time x Info x InitC model');
legend('Location', 'best');
grid on;
hold off;

%% --- 14. Plot 4: observed aggregated data, split by high/low initial complexity ---

aggMedInit = median(aggTbl.InitC, 'omitnan');
aggMedInfo = median(aggTbl.Info, 'omitnan');

figure(4); clf;

subplot(1,2,1);
idx = aggTbl.InitC > aggMedInit;
scatter(aggTbl.Time(idx), aggTbl.Mean(idx), 20, aggTbl.Info(idx), 'filled');
xlabel('Time');
ylabel('Mean algorithmic complexity');
title('Initially complex graphemes');
cb = colorbar;
ylabel(cb, 'Information (higher = rarer)');
grid on;

subplot(1,2,2);
idx = aggTbl.InitC <= aggMedInit;
scatter(aggTbl.Time(idx), aggTbl.Mean(idx), 20, aggTbl.Info(idx), 'filled');
xlabel('Time');
ylabel('Mean algorithmic complexity');
title('Initially simple graphemes');
cb = colorbar;
ylabel(cb, 'Information (higher = rarer)');
grid on;

%% --- 15. Optional direct change-score analysis ---
%
% For each grapheme, compare earliest and latest observed mean complexity.
% This is simpler and sometimes easier to interpret in prose.

[G2, g2] = findgroups(T.grapheme_id);
delta = NaN(numel(g2),1);
infoG = NaN(numel(g2),1);
initG = NaN(numel(g2),1);

for i = 1:numel(g2)
    idx = T.grapheme_id == g2(i);
    sub = T(idx,:);
    
    uTimes = unique(sub.Time);
    if numel(uTimes) >= 2
        tMin = min(uTimes);
        tMax = max(uTimes);
        
        earlyMean = mean(sub.complexity(sub.Time == tMin), 'omitnan');
        lateMean  = mean(sub.complexity(sub.Time == tMax), 'omitnan');
        
        delta(i) = lateMean - earlyMean;
        infoG(i) = mean(sub.Info, 'omitnan');
        initG(i) = mean(sub.InitC, 'omitnan');
    end
end

deltaTbl = table(categorical(g2), delta, infoG, initG, ...
    'VariableNames', {'Grapheme','Delta','Info','InitC'});

deltaTbl = deltaTbl(~isnan(deltaTbl.Delta) & ~isnan(deltaTbl.Info) & ~isnan(deltaTbl.InitC), :);

mdl_delta = fitlm(deltaTbl, 'Delta ~ Info * InitC');

disp(' ');
disp('CHANGE-SCORE MODEL: Delta ~ Info * InitC');
disp(mdl_delta);

%% --- 16. Compact readout of the key coefficients ---

fprintf('\n==================== SUMMARY ====================\n');

coefName = 'Time:Info:InitC';

fprintf('\nAggregated model:\n');
disp(lme_agg.Coefficients(:, {'Name','Estimate','SE','tStat','pValue'}));

fprintf('\nFull token-level model:\n');
disp(lme_full.Coefficients(:, {'Name','Estimate','SE','tStat','pValue'}));

fprintf('\nExpected sign for support of hypothesis:\n');
fprintf('  Time:Info:InitC > 0\n');

fprintf('\nReason:\n');
fprintf('  Higher information = rarer signs.\n');
fprintf('  Among initially complex signs, rarer signs should simplify less or even complexify,\n');
fprintf('  while frequent signs should simplify more.\n');
fprintf('=================================================\n');