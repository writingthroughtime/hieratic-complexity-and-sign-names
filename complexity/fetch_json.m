function jsonText = fetch_json(endpoint, varargin)
%FETCH_JSON Fetch raw JSON from an HTTP endpoint and return it as a string.

endpoint = string(endpoint);

p = inputParser;
p.addParameter("Timeout", 60, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("Headers", ["Accept","application/json"], ...
    @(x) isstring(x) || (iscell(x) && size(x,2)==2));
p.addParameter("Method", "GET", @(s) isstring(s) || ischar(s));
p.addParameter("Body", []);
p.addParameter("ContentType", "application/json", @(s) isstring(s) || ischar(s));
p.parse(varargin{:});

timeout     = p.Results.Timeout;
headers     = p.Results.Headers;
method      = upper(string(p.Results.Method));
body        = p.Results.Body;
contentType = string(p.Results.ContentType);

% --- normalize headers to string array Nx2
if iscell(headers)
    headers = string(headers);
end

opts = weboptions( ...
    "Timeout", timeout, ...
    "HeaderFields", headers, ...
    "ContentType", "text" ...   % force raw response
);

try
    switch method
        case "GET"
            resp = webread(endpoint, opts);

        case {"POST","PUT","PATCH"}
            opts.MediaType = contentType;

            if isempty(body)
                payload = "";
            elseif isstring(body) || ischar(body)
                payload = body;
            else
                payload = jsonencode(body);
            end

            resp = webwrite(endpoint, payload, opts);

        otherwise
            error("fetch_json:UnsupportedMethod", ...
                  "Unsupported HTTP method: %s", method);
    end

catch ME
    ME2 = MException("fetch_json:RequestFailed", ...
        "fetch_json failed for endpoint:\n%s\n\n%s", endpoint, ME.message);
    ME2 = addCause(ME2, ME);
    throw(ME2);
end

% --- normalize output to string
if isstring(resp)
    jsonText = resp;
elseif ischar(resp)
    jsonText = string(resp);
else
    jsonText = string(char(resp));
end

end
