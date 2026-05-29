function d_med = median_distance_from_centroid(shapes)
%MEDIAN_DISTANCE_FROM_CENTROID
% Compute median Euclidean distance of all shape points from global centroid.
%
% Input
%   shapes : cell array
%       shapes{i} is an N-by-2 matrix of [x y] points
%
% Output
%   d_med : scalar median distance

    % Collect all points
    allPts = [];

    for i = 1:numel(shapes)
        if ~isempty(shapes{i})
            allPts = [allPts; shapes{i}];
        end
    end

    if isempty(allPts)
        d_med = NaN;
        return;
    end

    % Centroid
    centroid = mean(allPts, 1);

    % Distances
    diffs = allPts - centroid;
    d = sqrt(sum(diffs.^2, 2));

    % Median distance
    d_med = median(d);
end