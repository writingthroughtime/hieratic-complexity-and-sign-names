%% Unify SVG scale by text-level scale factor
clc;
clear;
close all;

load('sign_list.mat', 'sign_list');

%% Paths

srcDir = './aku-pal/svgs/ht/';
dstDir = './svgs/ht/';

if ~exist(dstDir, 'dir')
    mkdir(dstDir);
end

%% Compute one scale factor per text from mean dispersion

texts = unique(sign_list.text);
nTexts = numel(texts);

text_mean_dispersion = nan(nTexts,1);

for k = 1:nTexts
    currentText = texts(k);
    currentSigns = sign_list(sign_list.text == currentText, :);

    dispersions_k = nan(height(currentSigns), 1);

    for i = 1:height(currentSigns)
        currentSign = currentSigns(i,:);

        if ~currentSign.file_found
            continue;
        end

        if isempty(currentSign.shapes{1})
            continue;
        end

        try
            dispersions_k(i) = mean_distance_from_centroid(currentSign.shapes{1});
        catch
            dispersions_k(i) = NaN;
        end
    end

    text_mean_dispersion(k) = mean(dispersions_k, 'omitnan');
end

scale_factors = 1 ./ text_mean_dispersion;
scale_factors(isnan(scale_factors) | isinf(scale_factors)) = NaN;

% Normalize so the smallest non-NaN scale factor becomes 1
min_sf = min(scale_factors, [], 'omitnan');
scale_factors = scale_factors ./ min_sf;
scale_factors(isnan(scale_factors)) = 1;

fprintf('Scale factor range: %.4f to %.4f\n', ...
    min(scale_factors), max(scale_factors));

% Map text -> scale factor
text_to_scale = containers.Map('KeyType','char','ValueType','double');
for k = 1:nTexts
    text_to_scale(char(texts(k))) = scale_factors(k);
end

%% Process SVGs
% Use unique sign_id rows in case anything appears twice

[~, ia] = unique(sign_list.sign_id, 'stable');
sign_rows = sign_list(ia,:);

n = height(sign_rows);

for i = 1:n
    if mod(i,100) == 1
        fprintf('Processed %d / %d\t%.2f%%\n', i, n, 100*i/n);
    end

    sign_id = sign_rows.sign_id(i);
    txt = char(sign_rows.text(i));

    if isKey(text_to_scale, txt)
        sf = text_to_scale(txt);
    else
        sf = 1;
    end

    srcFile = fullfile(srcDir, sprintf('ht_%d.svg', sign_id));
    dstFile = fullfile(dstDir, sprintf('ht_%d.svg', sign_id));

    if ~isfile(srcFile)
        continue;
    end

    try
        svg = fileread(srcFile);
        svg_new = rescale_svg_text(svg, sf);
        fid = fopen(dstFile, 'w');
        fwrite(fid, svg_new, 'char');
        fclose(fid);
    catch ME
        fprintf('FAILED: %s\n', srcFile);
        fprintf('%s\n', ME.message);
    end
end

disp('Done.');

%% --- Helper function: rescale one SVG as text ---
function svg_out = rescale_svg_text(svg_in, s)

    % Find opening <svg ...> tag by string search, not regex
    startIdx = strfind(lower(svg_in), '<svg');
    if isempty(startIdx)
        error('No opening <svg> tag found.');
    end
    startIdx = startIdx(1);

    endRel = strfind(svg_in(startIdx:end), '>');
    if isempty(endRel)
        error('Opening <svg> tag is not closed.');
    end
    endIdx = startIdx + endRel(1) - 1;

    openMatch = svg_in(startIdx:endIdx);

    % Parse width / height
    [widthVal, widthUnit, hasWidth]    = parse_svg_length_attr(openMatch, 'width');
    [heightVal, heightUnit, hasHeight] = parse_svg_length_attr(openMatch, 'height');

    % Parse viewBox
    [vb, hasViewBox] = parse_viewbox_attr(openMatch);

    % If no viewBox, synthesize one from width/height if possible
    if ~hasViewBox && hasWidth && hasHeight
        vb = [0, 0, widthVal, heightVal];
        hasViewBox = true;
    end

    % Update opening tag
    newOpen = openMatch;

    if hasWidth
        newOpen = replace_or_add_attr(newOpen, 'width', ...
            sprintf('%.8f%s', widthVal * s, widthUnit));
    end

    if hasHeight
        newOpen = replace_or_add_attr(newOpen, 'height', ...
            sprintf('%.8f%s', heightVal * s, heightUnit));
    end

    if hasViewBox
        vb2 = vb .* s;
        vbStr = sprintf('%.8f %.8f %.8f %.8f', vb2(1), vb2(2), vb2(3), vb2(4));
        newOpen = replace_or_add_attr(newOpen, 'viewBox', vbStr);
    end

    % Replace opening tag
    svg_mid = [svg_in(1:startIdx-1), newOpen, svg_in(endIdx+1:end)];

    % Insert scale group right after opening tag
    insertPos = startIdx + length(newOpen);
    svg_mid = [svg_mid(1:insertPos), newline, ...
               '<g transform="scale(', num2str(s,'%.8f'), ')">', ...
               svg_mid(insertPos+1:end)];

    % Insert closing </g> before final </svg>
    closeIdx = strfind(lower(svg_mid), '</svg>');
    if isempty(closeIdx)
        error('No closing </svg> tag found.');
    end
    closeIdx = closeIdx(end);

    svg_out = [svg_mid(1:closeIdx-1), newline, '</g>', newline, svg_mid(closeIdx:end)];
end

%% --- Helper: parse width/height attr ---
function [val, unit, tf] = parse_svg_length_attr(tagText, attrName)
    expr = [attrName '\s*=\s*"([^"]+)"'];
    tok = regexp(tagText, expr, 'tokens', 'once');

    if isempty(tok)
        val = NaN;
        unit = '';
        tf = false;
        return;
    end

    raw = strtrim(tok{1});
    m = regexp(raw, '^([+-]?\d*\.?\d+(?:[eE][+-]?\d+)?)([a-zA-Z%]*)$', 'tokens', 'once');

    if isempty(m)
        val = NaN;
        unit = '';
        tf = false;
        return;
    end

    val = str2double(m{1});
    unit = m{2};
    tf = ~isnan(val);
end

%% --- Helper: parse viewBox attr ---
function [vb, tf] = parse_viewbox_attr(tagText)
    tok = regexp(tagText, 'viewBox\s*=\s*"([^"]+)"', 'tokens', 'once');

    if isempty(tok)
        vb = [NaN NaN NaN NaN];
        tf = false;
        return;
    end

    nums = sscanf(tok{1}, '%f');
    if numel(nums) ~= 4
        vb = [NaN NaN NaN NaN];
        tf = false;
        return;
    end

    vb = nums(:).';
    tf = true;
end

%% --- Helper: replace existing attr or add it ---
function tagOut = replace_or_add_attr(tagIn, attrName, attrValue)

    expr = [attrName '\s*=\s*"[^"]*"'];

    if ~isempty(regexp(tagIn, expr, 'once'))
        tagOut = regexprep(tagIn, expr, sprintf('%s="%s"', attrName, attrValue), 'once');
    else
        tagOut = regexprep(tagIn, '>$', sprintf(' %s="%s">', attrName, attrValue), 'once');
    end
end