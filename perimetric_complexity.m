function c = perimetric_complexity(alpha)
% PERIMETRIC_COMPLEXITY
% Computes raster perimetric complexity:
%
%   C = P^2 / (4*pi*A)
%
% where
%   A = foreground area in pixels
%   P = inside perimeter + outside perimeter, in pixel counts
%
% Input:
%   alpha  = alpha channel
%
% Output:
%   c      = perimetric complexity

if ndims(alpha) == 3
    alpha = alpha(:,:,1);
end

alpha = im2double(alpha);

% foreground mask
bw = alpha > 0;

if ~any(bw(:))
    c = NaN;
    return
end

% crop to occupied region to avoid nonsense from empty margins
rows = any(bw, 2);
cols = any(bw, 1);
bw = bw(rows, cols);

% pad so outer boundary is well-defined
bw = padarray(bw, [1 1], 0, 'both');

% area
Apx = nnz(bw);

if Apx == 0
    c = NaN;
    return
end

% inside perimeter pixels
pin = bwperim(bw, 8);

% outside perimeter pixels:
% background pixels touching foreground
kernel = ones(3);
adjToFg = conv2(double(bw), kernel, 'same') > 0;
pout = ~bw & adjToFg;

% total perimeter
Ppx = nnz(pin) + nnz(pout);

c = (Ppx^2) / (4*pi*Apx);
end