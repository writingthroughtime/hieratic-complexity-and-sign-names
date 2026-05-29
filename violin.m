function violin(x, y, labels, varargin)
%VIOLIN  Violin plot grouped by discrete x, with optional labels and a best-fit line.

    if nargin < 2
        error('violin:MissingInput', 'Usage: violin(x, y, [labels], ...)');
    end

    if nargin < 3
        labels = [];
    end

    x = x(:);
    y = y(:);

    if numel(x) ~= numel(y)
        error('violin:SizeMismatch', 'x and y must have the same number of elements.');
    end

    if ~isempty(labels)
        if numel(labels) ~= numel(x)
            error('violin:LabelSizeMismatch', 'labels must be the same length as x and y.');
        end
    end

    p = inputParser;
    p.addParameter('Colormap', [], @(c) isempty(c) || (isnumeric(c) && size(c,2) == 3));
    p.addParameter('LabelColor', [1 1 1], @(v) isnumeric(v) && numel(v) == 3);
    p.addParameter('LineColor', [204 89 93] / 255, @(v) isnumeric(v) && numel(v) == 3);
    p.addParameter('LineOpacity', 0.5, @(v) isnumeric(v) && isscalar(v) && v >= 0 && v <= 1);
    p.addParameter('ShowFitLine', true, @(v) islogical(v) && isscalar(v));
    p.addParameter('ShowPoints', false, @(v) islogical(v) && isscalar(v));
    p.addParameter('PointSize', 18, @(v) isnumeric(v) && isscalar(v) && v > 0);
    p.addParameter('PointOpacity', 0.35, @(v) isnumeric(v) && isscalar(v) && v >= 0 && v <= 1);
    p.addParameter('ViolinWidth', 2 * mean(abs(diff(sort(x)))), @(v) isnumeric(v) && isscalar(v) && v > 0);
    p.addParameter('Bandwidth', 2 * var(y), @(v) isempty(v) || (isnumeric(v) && isscalar(v) && v > 0));
    p.addParameter('NumDensityPts', 200, @(v) isnumeric(v) && isscalar(v) && v >= 30);
    p.addParameter('FontName', 'Minion Pro Hiero', @(v) ischar(v) || isstring(v));
    p.addParameter('XLabel', '', @(v) ischar(v) || isstring(v));
    p.addParameter('YLabel', '', @(v) ischar(v) || isstring(v));
    p.addParameter('Title', '', @(v) ischar(v) || isstring(v));
    p.addParameter('Grid', true, @(v) islogical(v) && isscalar(v));
    p.parse(varargin{:});
    opt = p.Results;

    if ~isempty(labels)
        lbl = string(labels(:));
        [uLbl, ~, gIdx] = unique(lbl, 'stable');
        nG = numel(uLbl);

        ux = nan(nG, 1);
        for gi = 1:nG
            m = (gIdx == gi) & isfinite(x);
            xs = unique(x(m));
            if numel(xs) ~= 1
                error('violin:BadDataLabelX', ...
                    'Bad data: label "%s" maps to %d distinct x values (expected exactly 1).', ...
                    uLbl(gi), numel(xs));
            end
            ux(gi) = xs;
        end

        groupIdx = gIdx;
        groupKeys = uLbl;
    else
        [ux, ~, xIdx] = unique(x, 'stable');
        nG = numel(ux);

        groupIdx = xIdx;
        groupKeys = [];
    end

    if isempty(opt.Colormap)
        cmap = jet(nG);
    else
        cmap = opt.Colormap;
        if size(cmap,1) < nG
            error('violin:ColormapTooShort', ...
                'Colormap must have at least %d rows.', nG);
        end
        cmap = cmap(1:nG, :);
    end

    [uxSorted, perm] = sort(ux, 'ascend');
    ux = uxSorted;

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
        X = [ones(length(x),1) x];
        b = X \ y;

        xLine = linspace(min(x), max(x), 200)';
        yLine = [ones(size(xLine)) xLine] * b;
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
        xi = ux(gi);
        mask = (groupIdx == gi) & isfinite(y);
        yg = y(mask);

        if isempty(yg)
            continue;
        end

        color = cmap(gi, :);

        if numel(yg) < 2
            plot(ax, xi, yg(1), 'o', ...
                'MarkerEdgeColor', color, ...
                'MarkerFaceColor', color, ...
                'MarkerSize', 5);

            if ~isempty(labels)
                labelInfo(end+1) = struct( ...
                    'x', xi, ...
                    'y', yg(1), ...
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

        yMin = min(yg) - pad;
        yMax = max(yg) + pad;

        if yMin == yMax
            plot(ax, xi, yg(1), 'o', ...
                'MarkerEdgeColor', color, ...
                'MarkerFaceColor', color, ...
                'MarkerSize', 5);

            if ~isempty(labels)
                labelInfo(end+1) = struct( ...
                    'x', xi, ...
                    'y', yg(1), ...
                    'txt', string(groupKeys(gi)), ...
                    'color', opt.LabelColor);
            end

            continue;
        end

        yGrid = linspace(yMin, yMax, opt.NumDensityPts);

        if isempty(opt.Bandwidth)
            f = ksdensity(yg, yGrid);
        else
            f = ksdensity(yg, yGrid, 'Bandwidth', opt.Bandwidth);
        end

        if all(f == 0) || any(~isfinite(f))
            plot(ax, xi, mean(yg, 'omitnan'), 'o', ...
                'MarkerEdgeColor', color, ...
                'MarkerFaceColor', color, ...
                'MarkerSize', 5);

            if ~isempty(labels)
                labelInfo(end+1) = struct( ...
                    'x', xi, ...
                    'y', mean(yg, 'omitnan'), ...
                    'txt', string(groupKeys(gi)), ...
                    'color', opt.LabelColor);
            end

            continue;
        end

        halfWidth = opt.ViolinWidth * (f / max(f));

        xLeft  = xi - halfWidth(:);
        xRight = xi + halfWidth(:);

        xPoly = [xLeft; flipud(xRight)];
        yPoly = [yGrid(:); flipud(yGrid(:))];

        patch(ax, xPoly, yPoly, color, ...
            'FaceAlpha', 0.8, 'EdgeColor', 'none');

        plot(ax, xLeft,  yGrid, '-', 'Color', color, 'LineWidth', 1.5);
        plot(ax, xRight, yGrid, '-', 'Color', color, 'LineWidth', 1.5);

        if opt.ShowPoints
            jitter = (rand(size(yg)) - 0.5) * (opt.ViolinWidth * 0.25);
            sc = scatter(ax, xi + jitter, yg, opt.PointSize, ...
                'MarkerFaceColor', color, 'MarkerEdgeColor', color);
            sc.MarkerFaceAlpha = opt.PointOpacity;
            sc.MarkerEdgeAlpha = opt.PointOpacity;
        end

        if ~isempty(labels)
            [~, imax] = max(f);
            labelInfo(end+1) = struct( ...
                'x', xi, ...
                'y', yGrid(imax), ...
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
        title(ax, sprintf('%s\nr = %0.2f\np = %0.4f', opt.Title, r, pval), 'FontName', opt.FontName);
    elseif strlength(string(opt.XLabel)) > 0 && strlength(string(opt.YLabel)) > 0
        title(ax, sprintf('%s vs. %s\nr = %0.2f\np = %0.4f', opt.XLabel, opt.YLabel, r, pval), 'FontName', opt.FontName);
    else
        title(ax, sprintf('r = %0.3f, p = %.3g', r, pval), 'FontName', opt.FontName);
    end

    ax.FontName = opt.FontName;

    hold(ax, 'off');

    xlim([min(x) - opt.ViolinWidth * 2, max(x) + opt.ViolinWidth * 2]);
end