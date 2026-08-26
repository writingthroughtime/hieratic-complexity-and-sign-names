%% text_average_complexity.m
% ========================================================================
%  STANDALONE — texts ranked by average sign complexity
% ========================================================================
% Side product of the genre paper pipeline (no paper figure uses it).
% Builds a per-text ranking, leaves it in the workspace variable
% textComplexityRanking, and saves it as text_average_complexity.csv.
%
% Each row is one text from the paper's analysis set: its number of
% measured sign instances, the mean raw complexity of those instances
% (skeleton pixels), and its genre, epoch, and midpoint date for context.
% Rows are sorted by mean complexity, most elaborate text first. Note
% that the mean is over RAW complexity, so a text full of inherently
% elaborate graphemes ranks high even if its writing is hasty. The
% sign-controlled equivalent used in the paper would center each
% instance on its grapheme mean first.
%
% Requires: genre_paper_analysis_set.mat (written by step 00)

clc;

load('genre_paper_analysis_set.mat', 'instances');

[textGroup, textNames] = findgroups(instances.text);

textComplexityRanking = table;
textComplexityRanking.text            = textNames;
textComplexityRanking.n_instances     = splitapply(@numel, instances.complexity, textGroup);
textComplexityRanking.mean_complexity = splitapply(@mean,  instances.complexity, textGroup);

% Context columns (single-valued per text in this dataset).
textComplexityRanking.genre  = splitapply(@(g) g(1), instances.genre,  textGroup);
textComplexityRanking.epoche = splitapply(@(e) e(1), instances.epoche, textGroup);
textComplexityRanking.date   = splitapply(@(d) d(1), instances.date,   textGroup);

textComplexityRanking = sortrows(textComplexityRanking, ...
    'mean_complexity', 'descend');
writetable(textComplexityRanking, 'text_average_complexity.csv');
fprintf('Wrote text_average_complexity.csv\n');

%% Sorting
clc

textComplexityRankingFiltered = textComplexityRanking;

% textComplexityRankingFiltered = textComplexityRankingFiltered(textComplexityRanking.n_instances > 20, :);
% textComplexityRankingFiltered = textComplexityRankingFiltered(strcmp(textComplexityRankingFiltered.genre, "Magischer Text"), :);
% textComplexityRankingFiltered = textComplexityRankingFiltered(strcmp(textComplexityRankingFiltered.epoche, "Neues Reich"), :);

textComplexityRankingFiltered = sortrows(textComplexityRankingFiltered, ...
    'mean_complexity');

fprintf('%d texts ranked by mean sign complexity (raw skeleton pixels).\n', ...
    height(textComplexityRankingFiltered));
fprintf('Result is in the workspace variable textComplexityRanking.\n\n');
disp(textComplexityRankingFiltered(1:min(10, height(textComplexityRankingFiltered)), :));
