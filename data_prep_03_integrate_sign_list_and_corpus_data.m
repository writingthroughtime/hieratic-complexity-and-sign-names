%% Add corpus-based total and epoch frequencies to sign_list

clear; clc

load('sign_list.mat', 'sign_list');
load('corpus_data.mat', 'corpus_data');

% FIX MdC VALUES (manual corrections)

sign_list.mdc(sign_list.mdc == "2") = "Z4A";
sign_list.mdc(sign_list.mdc == "3") = "Z2";

sign_list.mdc = replace(sign_list.mdc, ":", "-");
sign_list.mdc = replace(sign_list.mdc, "&", "-");

% Normalize MdC columns
signMdc = string(sign_list.mdc);
corpusMdc = string(corpus_data.MdC);

% Dates
corpusDate = corpus_data.dateMean;

N = height(sign_list);

unmatchedMdc = strings(0,1);

for i = 1:N

    % Progress output every 100 iterations
    if mod(i,100) == 1 || i == N
        pct = (i / N) * 100;
        fprintf('Processing %d / %d (%.1f%%)\n', i, N, pct);
    end

    mdcMatch = corpusMdc == signMdc(i);

    if ~any(mdcMatch)
        unmatchedMdc(end+1,1) = signMdc(i);
    end

    %% Total frequency across all matching corpus data

    totalMatches = mdcMatch;

    totalCount = sum(corpus_data.count(totalMatches), 'omitnan');
    totalCorpus = sum(corpus_data.textTotal(totalMatches), 'omitnan');

    if totalCorpus > 0
        sign_list.frequency(i) = totalCount / totalCorpus;
    else
        sign_list.frequency(i) = NaN;
    end

    %% Epoch frequency

    dateMatch = corpusDate >= sign_list.epoche_startdatum(i) & ...
                corpusDate <= sign_list.epoche_enddatum(i);

    epochMatches = mdcMatch & dateMatch;

    epochCount = sum(corpus_data.count(epochMatches), 'omitnan');
    epochCorpus = sum(corpus_data.textTotal(epochMatches), 'omitnan');

    if epochCorpus > 0
        sign_list.in_epoch_frequency(i) = epochCount / epochCorpus;
    else
        sign_list.in_epoch_frequency(i) = NaN;
    end

end

% Deduped unmatched MdC list
unmatchedMdc = unique(unmatchedMdc);
unmatchedMdc = unmatchedMdc(unmatchedMdc ~= "");

% Save updated data
save('sign_list_plus_corpus_data.mat', 'sign_list', '-v7.3');

% Save unmatched MdC list
writelines(unmatchedMdc, 'unmatched_mdc.txt');

disp('Updated frequency and in_epoch_frequency from corpus_data and saved sign_list_plus_corpus_data.mat')
fprintf('Saved %d unmatched MdC values to unmatched_mdc.txt\n', numel(unmatchedMdc));