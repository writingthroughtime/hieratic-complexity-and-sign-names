

clc;
clear all;
close all;

csv_file_name = 'sign_list.csv';
opts = detectImportOptions(csv_file_name, ...
    'Delimiter', ',', ...
    'TextType', 'string', ...
    'Encoding', 'UTF-8');

opts = setvartype(opts, ...
    {'sign_id','grapheme_id'}, 'int32');

opts = setvartype(opts, ...
    {'mdc','Unicode','ht_local_path','schriftart','text','datierung','datierung_href'}, ...
    'string');

opts = setvartype(opts, 'in_text_selection', 'logical');

opts.VariableNamingRule = 'preserve';

sign_list = readtable(csv_file_name, opts);


head(sign_list);
summary(sign_list);

% Filter the sign_list to include only hieratic signs
sign_list = sign_list(sign_list.schriftart == "Hieratisch", :);

% Drop unneeded columns
sign_list.in_text_selection = [];
sign_list.schriftart = [];
% sign_list.ht_local_path = [];
sign_list.datierung_href = [];

% Temp cludge to run simultaneously with python tiff generator
sign_list = sortrows(sign_list, "ht_local_path");
sign_list.ht_local_path = [];

%% Use image files to collect sign data

filepath = './aku-pal-dump/tiffs/ht/';
filepath_eps = './aku-pal-dump/eps/ht/';

% Preallocate new columns
n = height(sign_list);

sign_list.file_found					= false(n,1);
sign_list.shapes						= cell(n,1);   % each row: cell array of outlines
sign_list.image							= cell(n,1);   % each row: alpha channel image
sign_list.width							= nan(n,1);
sign_list.height						= nan(n,1);
sign_list.skeleton_pixel_count			= nan(n,1);
sign_list.dispersion					= nan(n,1);
sign_list.perimetric_complexity_image	= nan(n,1);
sign_list.perimetric_complexity_shape   = nan(n,1);
sign_list.algorithmic_complexity		= nan(n,1);

% Add all sign shapes to sign_list
for i = 1:n

    if mod(i,100) == 1
        fprintf('Processed %05d / %d\t%.2f%%\n', i, n, 100*i/n);
    end

    currentSign = sign_list(i, :);

    % Construct the file name for the current sign
    fileName = fullfile(filepath, sprintf('ht_%d.tiff', currentSign.sign_id));

    try
        if ~isfile(fileName)
            sign_list.file_found(i) = false;
            sign_list.shapes{i} = {};
            sign_list.image{i} = [];
            sign_list.width(i) = NaN;
            sign_list.height(i) = NaN;
            continue
        end

        sign_list.file_found(i) = true;

        img = imread(fileName);

        % Store true alpha channel, but compute shapes from binarized version
        alpha = img(:,:,4);
        bw = alpha > 0;

        B = bwboundaries(bw, 'noholes');

        % Defensive, even though bwboundaries should already return a cell
        if ~iscell(B)
            B = {B};
        end

        allShape = [];
        for j = 1:numel(B)
            shape = B{j};
            shape = [shape(:,2), -shape(:,1)];
            B{j} = shape;

            allShape = [allShape; shape];
        end

        if ~isempty(allShape)
            w = max(allShape(:,1)) - min(allShape(:,1));
            h = max(allShape(:,2)) - min(allShape(:,2));
        else
            w = NaN;
            h = NaN;
		end

		% Smooth all shapes
		B = smooth_shape_components(B, 1, 2);

		% Get the EPS file size for algorithmic complexity
    	fileNameEPS = fullfile(filepath_eps, sprintf('ht_%d.eps', currentSign.sign_id));
		info = dir(fileNameEPS);
		if ~isempty(info)
        	file_size_bytes = info.bytes;
    	else
        	file_size_bytes = NaN;
    	end
		
        % Store results back into table
        sign_list.shapes{i} = B;
        sign_list.image{i} = alpha;
        sign_list.width(i) = w;
        sign_list.height(i) = h;
        sign_list.skeleton_pixel_count(i) = nnz(bwmorph(alpha, 'skel', Inf));
        sign_list.dispersion(i) = mean_distance_from_centroid(B);
        sign_list.perimetric_complexity_image(i) = perimetric_complexity(alpha);
        sign_list.perimetric_complexity_shape(i) = perimetric_complexity_from_shapes(B);
        sign_list.algorithmic_complexity(i) = file_size_bytes;


    catch
        disp(sprintf('NOT FOUND: %s', fileName));

        sign_list.file_found(i) = false;
        sign_list.shapes{i} = {};
        sign_list.image{i} = [];
        sign_list.width(i) = NaN;
        sign_list.height(i) = NaN;
    end
end


%% Add dates

date_csv = 'dates.csv';

opts = detectImportOptions(date_csv, ...
    'Delimiter', ',', ...
    'TextType', 'string', ...
    'Encoding', 'UTF-8');

dates_table = readtable(date_csv, opts);

% Merge using text as key
sign_list = innerjoin(sign_list, dates_table, 'Keys', 'datierung');

head(sign_list)

% Add approx mid dates

sign_list = sortrows(sign_list, {'sign_id'});

sign_list.date = (sign_list.startdatum + sign_list.enddatum)/2;
sign_list.epoch_date = (sign_list.epoche_startdatum + sign_list.epoche_enddatum)/2;


%% Add overall sign frequencies (full corpus)

sign_list.frequency = zeros(n,1);

% Compute frequencies of mdc for all signs in dataset
[G, mdc_vals] = findgroups(sign_list.mdc);
counts = splitapply(@numel, sign_list.mdc, G);
freq = counts ./ sum(counts);

% Map frequencies back to each row
sign_list.frequency = freq(G);

%% Add sign frequencies per epoch

sign_list.in_epoch_frequency = zeros(n,1);
sign_list.epoch_length = zeros(n,1);

epochs = unique(sign_list.epoche);

for k = 1:numel(epochs)
    currentEpoch = epochs(k);
    currentSigns = sign_list(sign_list.epoche == currentEpoch, :);

    nSigns = height(currentSigns);
    currentSigns.epoch_length = ones(nSigns,1) * nSigns;

    % Frequencies of mdc within this epoch
    [G, ~] = findgroups(currentSigns.mdc);
    counts = splitapply(@numel, currentSigns.mdc, G);
    freq = counts ./ sum(counts);

    % Map frequencies back to rows
    currentSigns.in_epoch_frequency = freq(G);

    sign_list(sign_list.epoche == currentEpoch, :) = currentSigns;
end

%% Add count of signs in text and in-text sign frequencies

sign_list.text_length = zeros(n,1);
sign_list.in_text_frequency = zeros(n,1);

texts = unique(sign_list.text);


nTexts = numel(texts);


for k = 1:nTexts
	currentText = texts(k);
    currentSigns = sign_list(sign_list.text == currentText, :);
	nSigns = height(currentSigns);
	currentSigns.text_length = ones(nSigns, 1)*nSigns;

	% Compute frequencies of mdc within this text
	[G, mdc_vals] = findgroups(currentSigns.mdc);
	counts = splitapply(@numel, currentSigns.mdc, G);
	freq = counts ./ sum(counts);

	% Map frequencies back to each row
	currentSigns.in_text_frequency = freq(G);

	sign_list(sign_list.text == currentText, :) = currentSigns;
end

%% Save everything

save('sign_list_with_images.mat', 'sign_list', '-v7.3');

% Save a smaller version without images
sign_list.image = [];
save('sign_list.mat', 'sign_list', '-v7.3');

%% Get rid of bad texts with messed up sign forms

load('sign_list.mat', 'sign_list');

txt = string(sign_list.text);

bad = ismember(txt, [
    "O. Deir el-Bahri T3.L11"
	"O. Deir el-Bahri T3.L13"
    "O. Deir el-Bahri T3.L16"
]) ...
| contains(txt, "OL 6666") ...
| contains(txt, "UC 31953");

sign_list(bad, :) = [];

save('sign_list.mat', 'sign_list', '-v7.3');