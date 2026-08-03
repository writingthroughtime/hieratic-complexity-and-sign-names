function result = ols_with_clustered_errors(y, X, clusterIds, coefficientNames)
%OLS_WITH_CLUSTERED_ERRORS OLS with cluster-robust (CR1) standard errors.
%
%   result = ols_with_clustered_errors(y, X, clusterIds, coefficientNames)
%
%   y                 n-by-1 response
%   X                 n-by-k design matrix (include your own intercept column)
%   clusterIds        n-by-1 grouping variable (string/numeric); observations
%                     sharing a value may have arbitrarily correlated errors
%                     (here: sign instances from the same TEXT)
%   coefficientNames  optional k-by-1 string array for pretty printing
%
%   result struct fields:
%     .beta        k-by-1 OLS point estimates (identical to plain OLS)
%     .se          k-by-1 cluster-robust standard errors
%     .z           beta ./ se
%     .p           two-sided p-values from the NORMAL approximation.
%                  This is what the Python reference run used (verified
%                  numerically: e.g. Brief slope t = -2.248 -> p = 0.0245
%                  reproduces only under the normal, not t(G-1)). MATLAB's
%                  fitlm has no built-in clustered equivalent.
%     .Vclustered  k-by-k robust covariance matrix (use for Wald tests)
%     .nObs, .nClusters, .names, .residuals
%
%   The estimator is the Liang–Zeger sandwich with the CR1 small-sample
%   correction  c = (n-1)/(n-k) * G/(G-1):
%
%       V = c * (X'X)^-1 * [ sum_g (X_g' e_g)(X_g' e_g)' ] * (X'X)^-1
%
%   Wald test example (are all genre coefficients jointly zero?):
%       idx = <columns of the genre dummies>;
%       W   = result.beta(idx)' / result.Vclustered(idx, idx) * result.beta(idx);
%       p   = chi2cdf(W, numel(idx), 'upper');

    [nObs, nCoef] = size(X);
    if nargin < 4 || isempty(coefficientNames)
        coefficientNames = "b" + string(1:nCoef)';
    end

    % ---- OLS point estimates -------------------------------------------
    beta      = X \ y;
    residuals = y - X * beta;

    % ---- sandwich "bread" ----------------------------------------------
    XtXinv = (X' * X) \ eye(nCoef);

    % ---- sandwich "meat": sum over clusters of (X_g' e_g)(X_g' e_g)' ---
    [clusterIndex, ~] = findgroups(string(clusterIds(:)));
    nClusters = max(clusterIndex);

    meat = zeros(nCoef, nCoef);
    for g = 1:nClusters
        inCluster = (clusterIndex == g);
        scoreSum  = X(inCluster, :)' * residuals(inCluster);   % k-by-1
        meat = meat + scoreSum * scoreSum';
    end

    % ---- CR1 small-sample correction (statsmodels default) ------------
    correction = (nObs - 1) / (nObs - nCoef) * nClusters / (nClusters - 1);
    Vclustered = correction * (XtXinv * meat * XtXinv);

    % ---- assemble result -----------------------------------------------
    result.beta       = beta;
    result.se         = sqrt(diag(Vclustered));
    result.z          = beta ./ result.se;
    result.p          = 2 * normcdf(-abs(result.z));
    result.Vclustered = Vclustered;
    result.nObs       = nObs;
    result.nClusters  = nClusters;
    result.names      = string(coefficientNames(:));
    result.residuals  = residuals;
end
