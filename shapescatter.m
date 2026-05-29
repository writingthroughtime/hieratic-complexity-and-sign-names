function h = shapescatter(shapeSets, x, y, scalePx, labels, ax)
%SHAPESCATTER Draw multi-part filled shapes at specified positions.
%
% scalePx is the approximate max visual size of each sign in screen pixels.

    if nargin < 6 || isempty(ax)
        ax = gca;
    end

    n = numel(shapeSets);

    if numel(x) ~= n || numel(y) ~= n
        error('shapeSets, x, and y must have the same number of elements.');
    end

    if isscalar(scalePx)
        scalePx = repmat(scalePx, n, 1);
    else
        scalePx = scalePx(:);
    end

    if numel(scalePx) ~= n
        error('scalePx must be a scalar or have one value per shape set.');
    end

    if nargin < 5 || isempty(labels)
        labels = [];
    else
        labels = localNormalizeLabels(labels, n);
    end

    h = cell(n,1);

    holdState = ishold(ax);
    hold(ax, 'on');

    % This matters. Otherwise old axis equal / image / square state can persist.
    axis(ax, 'normal');

    % Freeze limits before drawing patches, otherwise patches can change the limits.
    ax.XLimMode = 'manual';
    ax.YLimMode = 'manual';

    drawnow;

    xl = ax.XLim;
    yl = ax.YLim;

    plotBoxPx = localPlotBoxPixels(ax);

    xUnitsPerPixel = diff(xl) / plotBoxPx(3);
    yUnitsPerPixel = diff(yl) / plotBoxPx(4);

    cm = iris(n);
    colorIdx = randperm(n);

    for i = 1:n
        B = shapeSets{i};

        if isempty(B)
            h{i} = {};
            continue;
        end

        allPts = [];

        for j = 1:numel(B)
            if ~isempty(B{j})
                allPts = [allPts; B{j}];
            end
        end

        if isempty(allPts)
            h{i} = {};
            continue;
        end

        centroid = mean(allPts, 1);

        xmin = min(allPts(:,1));
        xmax = max(allPts(:,1));
        ymin = min(allPts(:,2));
        ymax = max(allPts(:,2));

        s = max(xmax - xmin, ymax - ymin);

        if s == 0
            s = 1;
        end

        thisColor = cm(colorIdx(i), :);
        h{i} = cell(numel(B),1);

        for j = 1:numel(B)
            shape = B{j};

            if isempty(shape)
                h{i}{j} = gobjects(0);
                continue;
            end

            % Normalize sign geometry.
            shape = (shape - centroid) / s;

            % Counter-scale against the current axes transform.
            % These are deliberately different.
            shape(:,1) = shape(:,1) * scalePx(i) * xUnitsPerPixel + x(i);
            shape(:,2) = shape(:,2) * scalePx(i) * yUnitsPerPixel + y(i);

            h{i}{j} = patch(ax, shape(:,1), shape(:,2), thisColor, ...
                'FaceAlpha', 0.9, ...
                'EdgeColor', 'none');
        end

        if ~isempty(labels)
            text(ax, x(i), y(i), labels(i), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontName', 'Minion Pro Hiero', ...
                'Interpreter', 'none');
        end
    end

    if ~holdState
        hold(ax, 'off');
    end
end

function plotBoxPx = localPlotBoxPixels(ax)
%LOCALPLOTBOXPIXELS Return actual plot box position in pixels.
%
% This accounts for axes position and aspect-ratio constraints.

    oldUnits = ax.Units;
    ax.Units = 'pixels';
    pos = ax.Position;
    ax.Units = oldUnits;

    darMode = ax.DataAspectRatioMode;
    pbarMode = ax.PlotBoxAspectRatioMode;

    if strcmp(darMode, 'auto') && strcmp(pbarMode, 'auto')
        plotBoxPx = pos;
        return;
    end

    xl = ax.XLim;
    yl = ax.YLim;

    dx = abs(diff(xl));
    dy = abs(diff(yl));

    if strcmp(darMode, 'manual')
        dar = ax.DataAspectRatio;
        targetRatio = (dx / dar(1)) / (dy / dar(2));
    else
        pbar = ax.PlotBoxAspectRatio;
        targetRatio = pbar(1) / pbar(2);
    end

    currentRatio = pos(3) / pos(4);

    plotBoxPx = pos;

    if currentRatio > targetRatio
        newWidth = pos(4) * targetRatio;
        plotBoxPx(1) = pos(1) + (pos(3) - newWidth) / 2;
        plotBoxPx(3) = newWidth;
    else
        newHeight = pos(3) / targetRatio;
        plotBoxPx(2) = pos(2) + (pos(4) - newHeight) / 2;
        plotBoxPx(4) = newHeight;
    end
end