function labels = localNormalizeLabels(labels, n)
%LOCALNORMALIZELABELS Convert many label types into an n-by-1 string array.

    if isnumeric(labels) || islogical(labels)

        if numel(labels) ~= n
            error('labels must have one value per shape set.');
        end

        labels = string(labels(:));

    elseif isstring(labels)

        if numel(labels) ~= n
            error('labels must have one value per shape set.');
        end

        labels = labels(:);

    elseif ischar(labels)

        if n ~= 1
            error(['A char array label is only valid when there is exactly one shape set. ', ...
                   'Use string array or cellstr for multiple labels.']);
        end

        labels = string(labels);

    elseif iscell(labels)

        if numel(labels) ~= n
            error('labels must have one value per shape set.');
        end

        labels = string(labels(:));

    elseif iscategorical(labels)

        if numel(labels) ~= n
            error('labels must have one value per shape set.');
        end

        labels = string(labels(:));

    else
        error('Unsupported labels type.');
    end
end