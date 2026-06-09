
clc
close all

set(groot, 'defaultAxesFontName', 'Times New Roman');

saveFigures = true;
figurePosition = [1 1 17 10]*2;

disp('Loading sign list data...');
load('sign_list_plus_corpus_data.mat', 'sign_list');
sign_list = sign_list(~isnan(sign_list.frequency), :);

% Keep only rows where the TIFF was found
try
	sign_list = sign_list(sign_list.file_found, :);
	sign_list.file_found = [];
catch
	disp('Sign list not reloaded, already filtered for valid files.');
end


%% Show sign distributions over time

figure(1); clf;
kdeplot(sign_list.date);
title('Sign Attestations by Date');
xlabel('Date')
ylabel('Number of Signs')

if saveFigures
	set(gcf, 'Units', 'centimeters');
	set(gcf, 'Position', figurePosition);
	exportgraphics(gcf, sprintf('./figures/%s.svg', 'Sign Attestations by Date'), ...
		'ContentType','vector');
end


%% Excerpt data for visual clarity in the plots
filtered_sign_list = sign_list;

% Keep only signs from texts with at least this many signs
minSigns = 1;
filtered_sign_list = filtered_sign_list(filtered_sign_list.text_length > minSigns, :);

% Select major historical periods with enough data for robust results
selectedEpochs = [
    "Altes Reich"
    "Mittleres Reich"
    "Neues Reich"
    "Griechisch-römische Zeit"
];
filtered_sign_list = filtered_sign_list(ismember(filtered_sign_list.epoche, selectedEpochs), :);

disp(sprintf('After epoch filter, dataset includes %i distinct signs in %i instances', ...
	numel(unique(filtered_sign_list.mdc)), height(filtered_sign_list)));

% Complexity metric: skeleton pixel count (normalized pen-path length)
filtered_sign_list.complexity = filtered_sign_list.skeleton_pixel_count;


%% Correlations by epoch

for iEpoch = 1:numel(selectedEpochs)
	epoch = selectedEpochs(iEpoch);
    epochData = filtered_sign_list(strcmp(filtered_sign_list.epoche, epoch), :);
	epochData = epochData(~isnan(epochData.in_epoch_frequency), :);

	if isempty(epochData)
		continue;
	end

	x = -log(epochData.in_epoch_frequency);
	y = epochData.complexity;

    [rEpoch, pEpoch] = corr(x, y);
    fprintf('Epoch: %s, Correlation coefficient: %.4f, p-value: %.10f\n', epoch, rEpoch, pEpoch);

	figure(100+iEpoch); clf;
    violin(x, y, epochData.mdc, ...
		'Bandwidth', 300, ...
		'XLabel', 'Information Content', 'YLabel', 'Complexity', 'Title', epoch);

	if saveFigures
		set(gcf, 'Units', 'centimeters');
		set(gcf, 'Position', figurePosition);
		exportgraphics(gcf, sprintf('./figures/%s.svg', epoch), ...
			'ContentType','vector');
	end
end


%% Select mdc values that appear at least minCount times in EACH epoch
minCount = 2;

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

disp(sprintf('After %i per epoch filter, dataset includes %i distinct signs in %i instances', ...
	minCount, numel(unique(filtered_sign_list.mdc)), height(filtered_sign_list)));


%% Compute per-sign complexity slope and information content

n = height(filtered_sign_list);
mdc = unique(filtered_sign_list.mdc);
m = height(mdc);

fs = zeros(m,1);
ms = zeros(m,1);
shapes = cell(m,1);

for i = 1:m
	selectedSign = mdc(i);
	oneSign = filtered_sign_list(strcmp(filtered_sign_list.mdc, selectedSign), :);
	fs(i) = mean(oneSign.frequency);

	X = [ones(height(oneSign),1), oneSign.date];
	b = X \ oneSign.complexity;
	ms(i) = b(2);

	oneSign = sortrows(oneSign, 'date');
	shapes(i) = oneSign.shapes(1);
end

% Remove signs with missing frequency
shapes = shapes(~isnan(fs));
ms = ms(~isnan(fs));
mdc = mdc(~isnan(fs));
fs = fs(~isnan(fs));


%% Information Content vs. Change in Complexity scatter plot

for showLabels = [false true]

	figure(201); clf;

	if saveFigures
		set(gcf, 'Units', 'centimeters');
		set(gcf, 'Position', figurePosition);
	end

	ax = axes;
	xlim(ax, [min(-log(fs))-0.5 max(-log(fs))+0.5]);
	ylim(ax, [min(ms)-0.3 max(ms)+0.3]);

	if showLabels
		shapescatter(shapes, -log(fs), ms, 20, mdc, ax);
	else
		shapescatter(shapes, -log(fs), ms, 20, [], ax);
	end

	xlabel('Information Content', 'FontName', 'Times New Roman');
	ylabel('Change in Complexity', 'FontName', 'Times New Roman');
	grid on;

	% Add regression line
	mdl = fitlm(-log(fs), ms);
	xfit = linspace(min(-log(fs)), max(-log(fs)), 100)';
	yfit = predict(mdl, xfit);

	hold on;
	plot(xfit, yfit, 'LineWidth', 1);
	hold off;

	[r, p] = corr(-log(fs), ms);
	fprintf('Correlation coefficient (information vs. complexity slope): r = %.4f, p = %.10f\n', r, p);

	titleString = sprintf('Information Content vs. Change in Complexity\nr = %0.4f, p = %0.4f', r, p);
	title(titleString, 'FontName', 'Times New Roman');

	if saveFigures
		if showLabels
			exportgraphics(gcf, './figures/Information Content vs. Change in Complexity with MdC.svg', 'ContentType','vector');
		else
			exportgraphics(gcf, './figures/Information Content vs. Change in Complexity.svg', 'ContentType','vector');
		end
	end
end

%% Look at sign trajectories

n = height(filtered_sign_list);
mdc = unique(filtered_sign_list.mdc);
m = height(mdc);

fs = zeros(m,1);
ms = zeros(m,1);
shapes = cell(m,1);


for i = 1:m
	
	selectedSign = mdc(i);
	oneSign = filtered_sign_list(strcmp(filtered_sign_list.mdc, selectedSign), :);

	if height(oneSign) < 20
		continue;
	end
	
	% % Use latest available frequency values (Greco-Roman in this case)
	% oneSignGR = oneSign(strcmp(oneSign.epoche, "Griechisch-römische Zeit"),:);
	% fs(i) = mean(oneSignGR.in_epoch_frequency);

	X = [ones(height(oneSign),1), oneSign.date];
	b = X \ oneSign.complexity;
	ms(i) = b(2);
end

[ms, iSort] = sort(ms);
mdc = mdc(iSort);

% Select a subset of signs to visualize
signsToPlot = 1:2;							% 10 most simplified
signsToPlot = length(mdc)+(-10:0);			% 10 most complexified
signsToPlot = find(ms<0)';					% All simplified
signsToPlot = find(ms>0)';					% All complexified
signsToPlot = find(ismember(mdc, ["G1", "A1", "G17", "D36", "D28", "G35"]))';	% Specific MdC

for i = signsToPlot
	figure(1000+i); clf;

	if saveFigures
		set(gcf, 'Units', 'centimeters');
		set(gcf, 'Position', figurePosition);   % [x y width height]
	end


	% KLUDGE: Reduce number of shapes in plot for presentation
	% (Without this the resulting figures are too complex to paste into Keynote)
	oneSign = filtered_sign_list(strcmp(filtered_sign_list.mdc, mdc(i)), :);
	if height(oneSign) > 525
		oneSign = oneSign(randperm(height(oneSign), 550), :);
		[~, mdl] = plot_sign_complexity(oneSign, mdc(i));
		title(sprintf('%s | slope = %.4f', mdc(i), ms(i)), ...
			'FontName', 'Times New Roman');
	else
		[~, mdl] = plot_sign_complexity(filtered_sign_list, mdc(i));
	end


	titleString = sprintf('Sign complexity for slope %0.4f, sign %s', ms(i), mdc(i)); 
	
	if saveFigures
		set(gcf, 'Units', 'centimeters');
		set(gcf, 'Position', figurePosition);   % [x y width height]
		exportgraphics(gcf, sprintf('./figures/signs/%s.svg', titleString), ...
		'ContentType','vector');
	end

	% JSesh copy-paste
	disp(sprintf('|%i-%s-+lslope=%.2f, p=%.4f+s-!', i, mdc(i), ms(i), mdl.ModelFitVsNullModel.Pvalue));
end

%% Close all figure windows after exporting
if saveFigures
	close all;
end
