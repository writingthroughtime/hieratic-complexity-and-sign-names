function C = perimetric_complexity_from_shapes(shapes)
%PARAMETRIC_COMPLEXITY_FROM_SHAPES
% Compute perimetric/parametric complexity from a cell array of blob outlines.
%
% Input
%   shapes : cell array
%       shapes{i} is an N-by-2 matrix of [x y] points tracing one blob
%
% Output
%   C : scalar complexity, defined as P^2 / (4*pi*A)

    totalArea = 0;
    totalPerimeter = 0;

    for i = 1:numel(shapes)
        xy = shapes{i};

        if isempty(xy) || size(xy,1) < 3
            continue;
        end

        x = xy(:,1);
        y = xy(:,2);

        % Close the polygon if needed
        if x(1) ~= x(end) || y(1) ~= y(end)
            x = [x; x(1)];
            y = [y; y(1)];
        end

        % Area
        totalArea = totalArea + polyarea(x, y);

        % Perimeter
        dx = diff(x);
        dy = diff(y);
        totalPerimeter = totalPerimeter + sum(sqrt(dx.^2 + dy.^2));
    end

    if totalArea <= 0
        C = NaN;
        return
    end

    C = (totalPerimeter^2) / (4*pi*totalArea);
end