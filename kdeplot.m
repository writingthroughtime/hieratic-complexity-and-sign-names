function [f, xi, bw] = kdeplot(ms, varargin)
%% Kernel density estimate + plot
% Usage:
%   kdeplot(ms)
%   kdeplot(ms, 'bw_scale', 0.5)
%   kdeplot(ms, 'bandwidth', 0.2)
%   kdeplot(ms, 'num_points', 500, 'plot_hist', false)
%
% Inputs:
%   ms          : data vector
%
% Name-value options:
%   'bw_scale'  : scale factor on automatic bandwidth (default = 1)
%   'bandwidth' : manually set bandwidth (overrides bw_scale if provided)
%   'num_points': number of evaluation points (default = 400)
%   'plot_hist' : true/false overlay histogram (default = true)
%
% Outputs:
%   f  : density values
%   xi : evaluation grid
%   bw : bandwidth used

%% Parse inputs
p = inputParser;
addRequired(p, 'ms');
addParameter(p, 'bw_scale', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'bandwidth', [], @(x) isempty(x) || (isscalar(x) && x > 0));
addParameter(p, 'num_points', 400, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'plot_hist', true, @(x) islogical(x) && isscalar(x));

parse(p, ms, varargin{:});

bw_scale  = p.Results.bw_scale;
bw_manual = p.Results.bandwidth;
npts      = p.Results.num_points;
plot_hist = p.Results.plot_hist;

%% Clean data
x = ms(:);
x = x(isfinite(x));

if isempty(x)
    error('Input vector contains no finite values.');
end

%% Automatic bandwidth (Silverman rule)
n = numel(x);
sx = std(x);
iqr_x = iqr(x);

sigma = min(sx, iqr_x/1.349);
if sigma <= 0 || ~isfinite(sigma)
    sigma = max(sx, eps);
end

bw_auto = 0.9 * sigma * n^(-1/5);

%% Final bandwidth
if ~isempty(bw_manual)
    bw = bw_manual;
else
    bw = bw_scale * bw_auto;
end

if bw <= 0 || ~isfinite(bw)
    bw = max(range(x)/100, eps);
end

%% Evaluation grid
pad = 3 * bw;
xi = linspace(min(x) - pad, max(x) + pad, npts);

%% KDE (Gaussian kernel)
dx = (xi - x) ./ bw;
K = exp(-0.5 * dx.^2) / sqrt(2*pi);
f = mean(K, 1) / bw;

%% Plot
clf
hold on

if plot_hist
    histogram(x, 'Normalization', 'pdf', ...
        'NumBins', max(10, round(sqrt(n))));
end

plot(xi, f, 'LineWidth', 2);

hold off
xlabel('Value');
ylabel('Density');
title(sprintf('Kernel Density Estimate (bw = %.4g)', bw));
grid on
box on

end