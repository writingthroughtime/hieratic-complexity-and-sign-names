function [xytByShape, meta] = parse_xyt_session_json(jsonValue)
%PARSE_XYT_SESSION_JSON Parse an online handwriting session payload into per-shape stroke samples.
%
% This function takes a session JSON payload (raw JSON text or an already-decoded
% struct) and converts it into:
%   1) xytByShape : a table with one row per drawn shape (grapheme instance), and
%   2) meta       : a struct with a few session-level metadata fields.
%
% Expected payload layout (conceptually):
%   data.session.shapes(si).partLabel
%   data.session.shapes(si).orientation_deg
%   data.session.shapes(si).strokes(sti).samples(k).{x,y,timestamp,azimuth,altitude,pressure,...}
%
% Output: xytByShape table
%   strokes         : cell array (nShapes x 1). Each cell contains a cell array of strokes.
%                     Each stroke is an N x 6 numeric matrix with columns:
%                       [x, y, t, azimuth, altitude, pressure]
%                     where t is either the original timestamp or a per-stroke relative time.
%   label           : cell array (nShapes x 1) of shape labels (unicode-friendly).
%   orientationDeg  : numeric column (nShapes x 1) of per-shape orientation in degrees.
%
% Time handling
%   - Time mode is currently hard-coded to "relative":
%       t := timestamp - first_finite_timestamp_in_that_stroke
%   - Duplicate timestamps within a stroke are dropped (stable unique).
%   - Rows with non-finite x/y/t are dropped.
%
% Shape/stroke filtering
%   - Shapes missing required fields are skipped.
%   - Strokes with no usable samples are skipped.
%   - Shapes with zero usable strokes are dropped.
%
% Notes / gotchas
%   - Azimuth/altitude/pressure are carried through if present, but they are NOT
%     currently used in the "good" mask, so they may contain NaN even when x/y/t are valid.
%   - The function warns and returns early if session.shapes is absent; ensure callers
%     handle empty outputs.


	% Decode if needed
	if ischar(jsonValue) || isstring(jsonValue)
    	data = jsondecode(jsonValue);
	else
    	data = jsonValue;
	end
	
	% ---- Extract metadata (same fields you used)
	meta = struct();
	meta.generatedAt = getfield_default(data, "generatedAt", "");
	if isfield(data, "session")
    	meta.session_id     = getfield_default(data.session, "id", "");
    	meta.subject_id     = getfield_default(data.session, "subject_id", "");
    	meta.experiment_id  = getfield_default(data.session, "experiment_id", "");
    	meta.start_at       = getfield_default(data.session, "start_at", "");
    	meta.end_at         = getfield_default(data.session, "end_at", "");
	else
    	meta.session_id     = "";
    	meta.subject_id     = "";
    	meta.experiment_id  = "";
    	meta.start_at       = "";
    	meta.end_at         = "";
	end
	
	% ---- Walk shapes -> strokes -> samples and build output
	
	if ~isfield(data, "session") || ~isfield(data.session, "shapes")
    	warning("No session.shapes found in payload.");
    	return;
	end
	
	shapes = ensure_struct_array(data.session.shapes);
	
	tMode = "relative"; % keep this identical to old behavior
	
	% Preallocate as growable lists (simple; you can preallocate later)
	strokeData      = {};   % cell: each row is 1x1 cell containing {xyt, xyt, ...}
	partLabelCol    = {};   % cell: each row is a char (possibly unicode)
	orientationDegCol = []; % numeric column
	
	row = 0;
	
	for si = 1:numel(shapes)
    	if ~isfield(shapes(si), "strokes"),         continue; end
    	if ~isfield(shapes(si), "partLabel"),       continue; end
    	if ~isfield(shapes(si), "orientation_deg"), continue; end
	
    	partLabel      = shapes(si).partLabel;
    	orientationDeg = shapes(si).orientation_deg;
    	strokes        = ensure_struct_array(shapes(si).strokes);
	
    	xytByStroke = {};
	
    	for sti = 1:numel(strokes)
        	if ~isfield(strokes(sti), "samples")
            	continue;
        	end
	
        	samples = ensure_struct_array(strokes(sti).samples);
        	n = numel(samples);
	
        	x = nan(n,1); y = nan(n,1); t = nan(n,1);
			az = nan(n,1); alt = nan(n,1); p = nan(n,1);
	
        	for k = 1:n
            	if isfield(samples(k), "x"),			x(k)	= samples(k).x;			end
            	if isfield(samples(k), "y"),			y(k)	= samples(k).y;			end
            	if isfield(samples(k), "timestamp"),	t(k)	= samples(k).timestamp; end
            	if isfield(samples(k), "azimuth"),		az(k)	= samples(k).azimuth;	end
            	if isfield(samples(k), "altitude"),		alt(k)	= samples(k).altitude;	end
            	if isfield(samples(k), "pressure"),		p(k)	= samples(k).pressure;	end
        	end
	
        	if tMode == "relative"
            	idx0 = find(isfinite(t), 1, "first");
				if ~isempty(idx0)
    				t = t - t(idx0);
				end
        	end
	
        	[t, keepIdx] = unique(t, "stable");
        	x = x(keepIdx);
        	y = y(keepIdx);
        	az = az(keepIdx);
        	alt = alt(keepIdx);
        	p = p(keepIdx);
	
        	good = isfinite(x) & isfinite(y) & isfinite(t);
        	xyt = [x(good), y(good), t(good), az(good), alt(good), p(good)];
	
        	if isempty(xyt)
            	continue;
        	end
	
        	[~, ord] = sort(xyt(:,3), "ascend");
        	xyt = xyt(ord,:);
	
        	xytByStroke{end+1,1} = xyt;
    	end
	
    	% Drop shapes with zero usable strokes:
    	if isempty(xytByStroke)
        	continue;
    	end
	
    	row = row + 1;
    	strokeData{row,1}        = xytByStroke;
    	partLabelCol{row,1}      = partLabel;
    	orientationDegCol(row,1) = orientationDeg;
	end
	
	xytByShape = table( ...
    	strokeData, partLabelCol, orientationDegCol, ...
    	'VariableNames', {'strokes','label','orientationDeg'} );


end

% ---------------- Helpers (same semantics as the originals) ----------------

function s = getfield_default(strct, fieldName, defaultVal)
	if isstruct(strct) && isfield(strct, fieldName)
    	s = strct.(fieldName);
	else
    	s = defaultVal;
	end
end

function arr = ensure_struct_array(v)
% jsondecode can return struct array or cell array of structs depending on shape
	if iscell(v)
    	if isempty(v)
        	arr = struct([]);
    	else
        	arr = [v{:}];
    	end
	elseif isstruct(v)
    	arr = v;
	else
    	arr = struct([]);
	end
end
