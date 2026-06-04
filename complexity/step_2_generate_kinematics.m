% step_2_generate_kinematics.m
%
% Compute kinematic metrics for every shape in allData_step_1.mat and
% save the enriched dataset as allData_step_2.mat.
%
% Metrics added: drawingTime, pathLength, totalWorkProxy, workPerLength,
%   peakSpeed, meanSpeed, peakAccel, meanAccel, peakJerk, meanJerk,
%   rmsVstar, rmsAstar, rmsJstar, totalTurningAbs, peakTurningAbs,
%   p95TurningAbs, meanTurning.
%
% Input:  allData_step_1.mat
% Output: allData_step_2.mat

clc; clear all; close all;

load allData_step_1;  % loads allData, scriptNames, scriptISOs, experimentIds

nSessions = height(allData);

for iSession = 1:nSessions
    shapes = allData.shapes{iSession};
    if ~istable(shapes)
        error('Expected allData.shapes{%d} to be a table.', iSession);
    end
    fprintf('Kinematics: session %d / %d\n', iSession, nSessions);

    nShapes = height(shapes);

    % Minimal column setup: create if missing, then fill row-by-row.
    shapes = ensure_metric_columns(shapes);

    for iShape = 1:nShapes
        strokes = shapes.strokes{iShape};

        % If empty or too short, leave NaNs and continue
        if isempty(strokes) || all(cellfun(@isempty, strokes))
            continue;
        end

        % 1) Base quantities used by many metrics
        T = metric_drawing_time(strokes);
        L = metric_path_length(strokes);

        shapes.drawingTime(iShape) = T;
        shapes.pathLength(iShape)  = L;

        % 2) Velocity (depends on strokes; independent of T/L)
        [v, dt_v] = series_speed(strokes);  % v aligned to dt_v
        shapes.meanSpeed(iShape) = metric_mean(v);
        shapes.peakSpeed(iShape) = metric_peak(v);

        % 3) Acceleration (depends on v)
        [a, dt_a] = series_accel(strokes);  % a aligned to dt_a
        shapes.meanAccel(iShape) = metric_mean(a);
        shapes.peakAccel(iShape) = metric_peak(a);

        % 4) Jerk (depends on a)
        [j, dt_j] = series_jerk(strokes);   % j aligned to dt_j
        shapes.meanJerk(iShape) = metric_mean(j);
        shapes.peakJerk(iShape) = metric_peak(j);

        % 5) Work proxy (depends on a and its dt)
        shapes.totalWorkProxy(iShape) = metric_work_proxy(a, dt_a);
        shapes.workPerLength(iShape) = shapes.totalWorkProxy(iShape) ./ L;

        % 6) Normalized derivatives (depend on T, L and base series)
        shapes.rmsVstar(iShape) = metric_rms_normalized_v(v, T, L);
        shapes.rmsAstar(iShape) = metric_rms_normalized_a(a, T, L);
        shapes.rmsJstar(iShape) = metric_rms_normalized_j(j, T, L);

        % 7) Turning / curvature proxy (stable discrete measure)
        turnAbs = series_turning_abs(strokes);
        shapes.totalTurningAbs(iShape) = metric_sum(turnAbs);
        shapes.peakTurningAbs(iShape)  = metric_peak(turnAbs);
        shapes.p95TurningAbs(iShape)   = metric_p95(turnAbs);
		shapes.meanTurning(iShape)     = shapes.totalTurningAbs(iShape) ./ L;
    end

    allData.shapes{iSession} = shapes;
end

save("allData_step_2", "allData", "scriptNames", "scriptISOs", "experimentIds");
fprintf('\nSaved allData_step_2.mat\n');


% =========================================================================
% Helpers

function shapes = ensure_metric_columns(shapes)
    shapes = ensure_col(shapes, 'drawingTime');
    shapes = ensure_col(shapes, 'pathLength');

    shapes = ensure_col(shapes, 'totalWorkProxy');
    shapes = ensure_col(shapes, 'workPerLength');

    shapes = ensure_col(shapes, 'peakSpeed');
    shapes = ensure_col(shapes, 'meanSpeed');

    shapes = ensure_col(shapes, 'peakAccel');
    shapes = ensure_col(shapes, 'meanAccel');

    shapes = ensure_col(shapes, 'peakJerk');
    shapes = ensure_col(shapes, 'meanJerk');

    shapes = ensure_col(shapes, 'rmsVstar');
    shapes = ensure_col(shapes, 'rmsAstar');
    shapes = ensure_col(shapes, 'rmsJstar');

    shapes = ensure_col(shapes, 'totalTurningAbs');
    shapes = ensure_col(shapes, 'peakTurningAbs');
    shapes = ensure_col(shapes, 'p95TurningAbs');
    shapes = ensure_col(shapes, 'meanTurning');
end

function T = ensure_col(T, varName)
    if ~ismember(varName, T.Properties.VariableNames)
        T.(varName) = nan(height(T), 1);
    end
end

% --- stroke segmentation --------------------------------------------------

function [x, y, t] = stroke_xy_t(S)  % S is kx6: [x y t az alt p]
    x = double(S(:,1)); y = double(S(:,2)); t = double(S(:,3));
    [t, idx] = sort(t); x = x(idx); y = y(idx);
    keep = [true; diff(t) > 0];
    x = x(keep); y = y(keep); t = t(keep);
end

% --- scalar metrics -------------------------------------------------------

function T = metric_drawing_time(strokes)
    T = 0;
    for i = 1:numel(strokes)
        S = strokes{i}; if isempty(S), continue; end
        [~,~,t] = stroke_xy_t(S); if numel(t) < 2, continue; end
        T = T + (t(end) - t(1));
    end
end

function L = metric_path_length(strokes)
    L = 0;
    for i = 1:numel(strokes)
        S = strokes{i}; if isempty(S), continue; end
        [x,y,~] = stroke_xy_t(S); if numel(x) < 2, continue; end
        L = L + sum(hypot(diff(x), diff(y)));
    end
end

function out = metric_mean(x);  if isempty(x), out=NaN; else, out=mean(x,'omitnan');     end; end
function out = metric_peak(x);  if isempty(x), out=NaN; else, out=max(x,[],'omitnan');   end; end
function out = metric_sum(x);   if isempty(x), out=NaN; else, out=sum(x,'omitnan');      end; end
function out = metric_p95(x);   if isempty(x), out=NaN; else, out=prctile(x,95);         end; end

function out = metric_work_proxy(a, dt_a)
    if isempty(a)||isempty(dt_a), out=NaN; return; end
    out = sum((a.^2).*dt_a, 'omitnan');
end

% --- series helpers -------------------------------------------------------

function [v, dt] = series_speed(strokes)
    v = []; dt = [];
    for i = 1:numel(strokes)
        S = strokes{i}; if isempty(S), continue; end
        [x,y,t] = stroke_xy_t(S); if numel(t)<2, continue; end
        dti = diff(t);
        v  = [v;  hypot(diff(x)./dti, diff(y)./dti)];  %#ok<AGROW>
        dt = [dt; dti];                                  %#ok<AGROW>
    end
end

function [a, dt2] = series_accel(strokes)
    a = []; dt2 = [];
    for i = 1:numel(strokes)
        S = strokes{i}; if isempty(S), continue; end
        [x,y,t] = stroke_xy_t(S); if numel(t)<3, continue; end
        dt=diff(t); vx=diff(x)./dt; vy=diff(y)./dt;
        dt_i=diff(t(1:end-1));
        a   = [a;   hypot(diff(vx)./dt_i, diff(vy)./dt_i)];  %#ok<AGROW>
        dt2 = [dt2; dt_i];                                     %#ok<AGROW>
    end
end

function [j, dt3] = series_jerk(strokes)
    j = []; dt3 = [];
    for i = 1:numel(strokes)
        S = strokes{i}; if isempty(S), continue; end
        [x,y,t] = stroke_xy_t(S); if numel(t)<4, continue; end
        dt=diff(t); vx=diff(x)./dt; vy=diff(y)./dt;
        dt2=diff(t(1:end-1)); ax=diff(vx)./dt2; ay=diff(vy)./dt2;
        dt3_i=diff(t(1:end-2));
        j   = [j;   hypot(diff(ax)./dt3_i, diff(ay)./dt3_i)];  %#ok<AGROW>
        dt3 = [dt3; dt3_i];                                      %#ok<AGROW>
    end
end

function turnAbs = series_turning_abs(strokes)
    turnAbs = [];
    for i = 1:numel(strokes)
        S = strokes{i}; if isempty(S), continue; end
        [x,y,~] = stroke_xy_t(S); if numel(x)<3, continue; end
        theta = atan2(diff(y), diff(x));
        turnAbs = [turnAbs; abs(diff(unwrap(theta)))];  %#ok<AGROW>
    end
end

% --- normalized RMS -------------------------------------------------------

function out = metric_rms_normalized_v(v, T, L)
    if isempty(v)||~(T>0)||~(L>0), out=NaN; return; end
    out = sqrt(mean(((T/L).*v).^2, 'omitnan'));
end
function out = metric_rms_normalized_a(a, T, L)
    if isempty(a)||~(T>0)||~(L>0), out=NaN; return; end
    out = sqrt(mean(((T^2/L).*a).^2, 'omitnan'));
end
function out = metric_rms_normalized_j(j, T, L)
    if isempty(j)||~(T>0)||~(L>0), out=NaN; return; end
    out = sqrt(mean(((T^3/L).*j).^2, 'omitnan'));
end
