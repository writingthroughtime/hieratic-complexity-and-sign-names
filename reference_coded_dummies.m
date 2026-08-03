function [dummyMatrix, levels, referenceLevel] = reference_coded_dummies(categoryVector)
%REFERENCE_CODED_DUMMIES Dummy (indicator) columns with the first level dropped.
%
%   [D, levels, ref] = reference_coded_dummies(v)
%
%   v       string/categorical/cellstr vector, one entry per observation.
%   D       n-by-(k-1) matrix of 0/1 indicators for levels 2..k, where the
%           k levels are sorted alphabetically (MATLAB's unique() order —
%           the same convention patsy/statsmodels uses, so coefficients
%           line up with the Python reference run).
%   levels  the k-1 level names that D's columns correspond to.
%   ref     the dropped (reference) level, absorbed into the intercept.
%
%   Used to build fixed-effects design matrices by hand for
%   ols_with_clustered_errors, where we need explicit control over which
%   columns belong to which factor (e.g. to Wald-test "all genre
%   coefficients = 0" jointly).

    categoryVector = string(categoryVector(:));
    allLevels = unique(categoryVector);          % sorted, ascending

    referenceLevel = allLevels(1);
    levels         = allLevels(2:end);

    nObs    = numel(categoryVector);
    nLevels = numel(levels);
    dummyMatrix = zeros(nObs, nLevels);
    for iLevel = 1:nLevels
        dummyMatrix(:, iLevel) = categoryVector == levels(iLevel);
    end
end
