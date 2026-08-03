function violinh(x, y, labels, varargin)
%VIOLINH  Horizontal violin plot grouped by discrete y, with optional labels.
%
%   violinh(x, y, [labels], ...)
%
%   The horizontal counterpart of violin.m: each group occupies one row at
%   a fixed y position, and the distribution of its x values is drawn as a
%   violin extending left and right along the value axis. All options
%   mirror violin.m, with the roles of the two axes exchanged.
%
%   x       observed values (horizontal axis)
%   y       row position of each observation's group (vertical axis)
%   labels  optional group labels, one per observation; each label must
%           map to exactly one y position. Labels are drawn inside the
%           violins at the density peak, as in violin.m. Pass [] to skip
%           in-violin labels and set YTickLabel on the axes instead.
%
%   Additional name-value options (defaults mirror violin.m):
%     'Colormap'    n-by-3 colors, one row per group (default jet)
%     'LabelColor'  in-violin label color (default white)
%     'ShowFitLine' draw a least-squares fit line across groups (default false;
%                   rarely meaningful when rows are ordered categories)
%     'ShowStats'   append r and p to the title (default false, same reason)
%     'ShowPoints'  jittered raw observations on each violin (default false)
%     'ViolinWidth' half-height of a full-density violin in y units
%     'Bandwidth'   ksdensity bandwidth in x units
%     'FontName'    font for labels and title (default Times New Roman)
%     'XLabel', 'YLabel', 'Title', 'Grid'  as in violin.m

    if nargin < 2
        error('violinh:MissingInput', 'Usage: violinh(x, y, [labels], ...)');
    end

    if nargin < 3
        labels = [];
    end

    x = x(:);
    y = y(:);

    if numel(x) ~= numel(y)
        error('violinh:SizeMismatch', 'x and y must have the same number of elements.');
    end

    if ~isempty(labels) && numel(labels) ~= numel(x)
        error('violinh:LabelSizeMismatch', 'labels must be the same length as x and y.');
    end

    p = inputParser;
    p.addParameter('Colormap', [], @(c) isempty(c) || (isnumeric(c) && size(c,2) == 3));
    p.addParameter('LabelColor', [1 1 1], @(v) isnumeric(v) && numel(v) == 3);
    p.addParameter('LineColor', [204 89 93] / 255, @(v) isnumeric(v) && numel(v) == 3);
    p.addParameter('LineOpacity', 0.5, @(v) isnumeric(v) && isscalar(v) && v >= 0 && v <= 1);
    p.addParameter('ShowFitLine', false, @(v) islogical(v) && isscalar(v));
    p.addParameter('ShowStats', false, @(v) islogical(v) && isscalar(v));
    p.addParameter('ShowPoints', false, @(v) islogical(v) && isscalar(v));
    p.addParameter('PointSize', 18, @(v) isnumeric(v) && isscalar(v) && v > 0);
    p.addParameter('PointOpacity', 0.35, @(v) isnumeric(v) && isscalar(v) && v >= 0 && v <= 1);
    p.addParameter('ViolinWidth', 0.4, @(v) isnumeric(v) && isscalar(v) && v > 0);
    p.addParameter('Bandwidth', 2 * var(x), @(v) isempty(v) || (isnumeric(v) && isscalar(v) && v > 0));
    p.addParameter('NumDensityPts', 200, @(v) isnumeric(v) && isscalar(v) && v >= 30);
    p.addParameter('FontName', 'Times New Roman', @(v) ischar(v) || isstring(v));
    p.addParameter('XLabel', '', @(v) ischar(v) || isstring(v));
    p.addParameter('YLabel', '', @(v) ischar(v) || isstring(v));
    p.addParameter('Title', '', @(v) ischar(v) || isstring(v));
    p.addParameter('Grid', true, @(v) islogical(v) && isscalar(v));
    p.parse(varargin{:});
    opt = p.Results;

    % Resolve groups: either labels (each mapping to one y) or unique y values.
    if ~isempty(labels)
        lbl = string(labels(:));
        [uLbl, ~, gIdx] = unique(lbl, 'stable');
        nG = numel(uLbl);

        uy = nan(nG, 1);
        for gi = 1:nG
            m = (gIdx == gi) & isfinite(y);
            ys = unique(y(m));
            if numel(ys) ~= 1
                error('violinh:BadDataLabelY', ...
                    'Bad data: label "%s" maps to %d distinct y values (expected exactly 1).', ...
                    uLbl(gi), numel(ys));
            end
            uy(gi) = ys;
        end

        groupIdx = gIdx;
        groupKeys = uLbl;
    else
        [uy, ~, yIdx] = unique(y, 'stable');
        nG = numel(uy);

        groupIdx = yIdx;
        groupKeys = [];
    end

    if isempty(opt.Colormap)
        cmap = jet(nG);
    else
        cmap = opt.Colormap;
        if size(cmap,1) < nG
            error('violinh:ColormapTooShort', ...
                'Colormap must have at least %d rows.', nG);
        end
        cmap = cmap(1:nG, :);
    end

    [uySorted, perm] = sort(uy, 'ascend');
    uy = uySorted;

    if numel(groupKeys) > 0
        groupKeys = groupKeys(perm);
    end

    newGroup = zeros(nG, 1);
    newGroup(perm) = 1:nG;
    groupIdx = newGroup(groupIdx);

    [C, Pval] = corrcoef(x, y, 'Rows', 'complete');
    r = C(2,1);
    pval = Pval(2,1);

    if opt.ShowFitLine
        Y = [ones(length(y),1) y];
        b = Y \ x;

        yLine = linspace(min(y), max(y), 200)';
        xLine = [ones(size(yLine)) yLine] * b;
    end

    clf
    ax = gca;
    hold(ax, 'on');

    if opt.Grid
        grid(ax, 'on');
    else
        grid(ax, 'off');
    end

    labelInfo = struct('x', {}, 'y', {}, 'txt', {}, 'color', {});

    for gi = 1:nG
        yi = uy(gi);
        mask = (groupIdx == gi) & isfinite(x);
        xg = x(mask);

        if isempty(xg)
            continue;
        end

        color = cmap(gi, :);

        if numel(xg) < 2 || min(xg) == max(xg)
            plot(ax, xg(1), yi, 'o', ...
                'MarkerEdgeColor', color, ...
                'MarkerFaceColor', color, ...
                'MarkerSize', 5);

            if ~isempty(labels)
                labelInfo(end+1) = struct( ...
                    'x', xg(1), ...
                    'y', yi, ...
                    'txt', string(groupKeys(gi)), ...
                    'color', opt.LabelColor);
            end

            continue;
        end

        if isempty(opt.Bandwidth)
            pad = 0;
        else
            pad = 3 * opt.Bandwidth;
        end

        xGrid = linspace(min(xg) - pad, max(xg) + pad, opt.NumDensityPts);

        if isempty(opt.Bandwidth)
            f = ksdensity(xg, xGrid);
        else
            f = ksdensity(xg, xGrid, 'Bandwidth', opt.Bandwidth);
        end

        if all(f == 0) || any(~isfinite(f))
            plot(ax, mean(xg, 'omitnan'), yi, 'o', ...
                'MarkerEdgeColor', color, ...
                'MarkerFaceColor', color, ...
                'MarkerSize', 5);

            if ~isempty(labels)
                labelInfo(end+1) = struct( ...
                    'x', mean(xg, 'omitnan'), ...
                    'y', yi, ...
                    'txt', string(groupKeys(gi)), ...
                    'color', opt.LabelColor);
            end

            continue;
        end

        halfHeight = opt.ViolinWidth * (f / max(f));

        yLow  = yi - halfHeight(:);
        yHigh = yi + halfHeight(:);

        yPoly = [yLow; flipud(yHigh)];
        xPoly = [xGrid(:); flipud(xGrid(:))];

        patch(ax, xPoly, yPoly, color, ...
            'FaceAlpha', 0.8, 'EdgeColor', 'none');

        plot(ax, xGrid, yLow,  '-', 'Color', color, 'LineWidth', 1.5);
        plot(ax, xGrid, yHigh, '-', 'Color', color, 'LineWidth', 1.5);

        if opt.ShowPoints
            jitter = (rand(size(xg)) - 0.5) * (opt.ViolinWidth * 0.5);
            sc = scatter(ax, xg, yi + jitter, opt.PointSize, ...
                'MarkerFaceColor', color, 'MarkerEdgeColor', color);
            sc.MarkerFaceAlpha = opt.PointOpacity;
            sc.MarkerEdgeAlpha = opt.PointOpacity;
        end

        if ~isempty(labels)
            [~, imax] = max(f);
            labelInfo(end+1) = struct( ...
                'x', xGrid(imax), ...
                'y', yi, ...
                'txt', string(groupKeys(gi)), ...
                'color', opt.LabelColor);
        end
    end

    for k = 1:numel(labelInfo)
        text(ax, labelInfo(k).x, labelInfo(k).y, labelInfo(k).txt, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontName', opt.FontName, ...
            'Color', labelInfo(k).color, ...
            'FontWeight','bold');
    end

    if opt.ShowFitLine
        lc = opt.LineColor;
        plot(ax, xLine, yLine, '-', 'Color', [lc opt.LineOpacity], 'LineWidth', 2);
    end

    if strlength(string(opt.XLabel)) > 0
        xlabel(ax, opt.XLabel, 'FontName', opt.FontName);
    end
    if strlength(string(opt.YLabel)) > 0
        ylabel(ax, opt.YLabel, 'FontName', opt.FontName);
    end

    if strlength(string(opt.Title)) > 0
        if opt.ShowStats
            title(ax, sprintf('%s\nr = %0.2f\np = %0.4f', opt.Title, r, pval), 'FontName', opt.FontName);
        else
            title(ax, opt.Title, 'FontName', opt.FontName);
        end
    elseif opt.ShowStats
        title(ax, sprintf('r = %0.3f, p = %.3g', r, pval), 'FontName', opt.FontName);
    end

    ax.FontName = opt.FontName;

    hold(ax, 'off');

    ylim([min(y) - opt.ViolinWidth * 2, max(y) + opt.ViolinWidth * 2]);
end
