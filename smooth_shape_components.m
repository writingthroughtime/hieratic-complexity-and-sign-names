function shapes_smooth = smooth_shape_components(shapes, step, sigma)
%SMOOTH_SHAPE_COMPONENTS Smooth each polygonal shape component.
%
% shapes_smooth = smooth_shape_components(shapes, step, sigma)
%
% Input
%   shapes : cell array
%       shapes{i} is an N-by-2 matrix of [x y] points for one blob outline
%
%   step : scalar
%       Target arc-length spacing between resampled points
%
%   sigma : scalar
%       Standard deviation of Gaussian smoothing kernel, in units of
%       resampled points. Typical values: 1 to 5.
%
% Output
%   shapes_smooth : cell array
%       Same structure as shapes, but each component is resampled and
%       smoothed.
%
% Notes
%   - Treats each component as a closed curve.
%   - Uses periodic padding so the smoothing wraps around cleanly.
%   - Good first guess: step = 1, sigma = 2.

    shapes_smooth = cell(size(shapes));

    for i = 1:numel(shapes)
        xy = shapes{i};

        if isempty(xy) || size(xy,1) < 3
            shapes_smooth{i} = xy;
            continue;
        end

        x = xy(:,1);
        y = xy(:,2);

        % Ensure closed curve
        if x(1) ~= x(end) || y(1) ~= y(end)
            x = [x; x(1)];
            y = [y; y(1)];
        end

        % Remove consecutive duplicate points
        dxy = diff([x y], 1, 1);
        keep = [true; any(dxy ~= 0, 2)];
        x = x(keep);
        y = y(keep);

        if numel(x) < 4
            shapes_smooth{i} = [x y];
            continue;
        end

        % Arc-length parameterization
        ds = sqrt(diff(x).^2 + diff(y).^2);
        s = [0; cumsum(ds)];
        L = s(end);

        if L == 0
            shapes_smooth{i} = [x y];
            continue;
        end

        % Uniform resampling grid
        nPts = max(8, ceil(L / step));
        sNew = linspace(0, L, nPts + 1)';
        sNew(end) = [];  % avoid duplicating closure point

        % Interpolate closed curve
        xNew = interp1(s, x, sNew, 'pchip');
        yNew = interp1(s, y, sNew, 'pchip');

        % Periodic Gaussian smoothing
        xNew = local_circular_gaussian_smooth(xNew, sigma);
        yNew = local_circular_gaussian_smooth(yNew, sigma);

        % Re-close curve
        xNew(end+1) = xNew(1);
        yNew(end+1) = yNew(1);

        shapes_smooth{i} = [xNew yNew];
    end
end


function vOut = local_circular_gaussian_smooth(v, sigma)
%LOCAL_CIRCULAR_GAUSSIAN_SMOOTH Circular Gaussian smoothing of a vector.

    if sigma <= 0
        vOut = v;
        return;
    end

    halfWidth = max(1, ceil(3*sigma));
    t = (-halfWidth:halfWidth)';
    g = exp(-(t.^2) / (2*sigma^2));
    g = g / sum(g);

    n = numel(v);

    % Circular padding
    vPad = [v(end-halfWidth+1:end); v; v(1:halfWidth)];

    vConv = conv(vPad, g, 'same');
    vOut = vConv(halfWidth+1:halfWidth+n);
end