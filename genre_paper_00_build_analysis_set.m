%% genre_paper_00_build_analysis_set.m
% ========================================================================
%  GENRE PAPER PIPELINE — STEP 0 of 5:  build the instance-level analysis set
% ========================================================================
% Port of the data-loading section of genre_analysis.py (Claude analysis,
% 2026-07-30) for "How Genre Shaped Complexity in Hieratic Handwriting".
%
% This script does the ONE slow thing (loading the 2.2 GB
% sign_list_plus_corpus_data.mat) exactly once, joins the AKU-PAL genre
% labels from texts.csv, and saves a slim instance-level table that every
% later script loads in a second or two.
%
% PIPELINE (run in order; each step saves what the next one needs):
%   genre_paper_00_build_analysis_set.m      -> genre_paper_analysis_set.mat
%                                               genre_paper_exemplar_shapes.mat
%                                               genre_paper_representative_shapes.mat
%   genre_paper_01_validate_against_companion.m   (no outputs; checks only)
%   genre_paper_02_genre_effect_nk.m         -> genre_paper_nk_model_set.mat
%   genre_paper_03_register_scale.m          -> Fig 1, Fig 2, register CSV
%   genre_paper_04_diachrony_genre_control.m -> Fig 3, Fig 5, Fig 6, CSVs
%   genre_paper_05_range_hypothesis.m        -> Fig 4, susceptibility CSV
%
% Shared helper functions (must be on the path, i.e. in this folder):
%   ols_with_clustered_errors.m , reference_coded_dummies.m
%
% EXPECTED CONSOLE OUTPUT (values from the validated Python run):
%   base-filtered set:    29,997 instances, 794 texts, 520 graphemes
%   genre-labeled subset: 29,205 instances, 674 texts, 516 graphemes, 51 genres
%
% Requires: sign_list_plus_corpus_data.mat , texts.csv
% Read-only w.r.t. the base data; writes only the two derived .mat files.

clc; close all;

%% ---- knobs -------------------------------------------------------------
unspecifiedGenreLabel = "nicht spezifiziert";   % AKU-PAL "no genre" label
exemplarSigns         = ["A1"; "G17"];          % signs for the Fig 2 exemplar plot
analysisSetFile       = 'genre_paper_analysis_set.mat';
exemplarShapesFile    = 'genre_paper_exemplar_shapes.mat';
representativeShapesFile = 'genre_paper_representative_shapes.mat';

%% ---- load the big file (slow: ~2.2 GB) --------------------------------
disp('Loading sign_list_plus_corpus_data.mat (this is the slow step)...');
load('sign_list_plus_corpus_data.mat', 'sign_list');

% Base filters, mirroring change_in_complexity_tests.m / genre_explore_*:
%   (1) frequency present (drops signs never matched to the TLA list)
%   (2) source image found (skeleton pixel count is only valid then)
sign_list = sign_list(~isnan(sign_list.frequency), :);
try
    sign_list = sign_list(sign_list.file_found, :);
    sign_list.file_found = [];
catch
    disp('Already filtered for valid files.');
end

% Complexity metric used throughout the paper: skeleton pixel count
% (pen-path length; source images are scale-normalized upstream).
sign_list.complexity = sign_list.skeleton_pixel_count;

%% ---- join genre labels from texts.csv ---------------------------------
% texts.csv maps text name -> AKU-PAL Textinhalt category ("genre").
textsTable = readtable('texts.csv', 'TextType','string', 'Encoding','UTF-8');
[textFound, textLoc] = ismember(string(sign_list.text), textsTable.text);
sign_list.genre = strings(height(sign_list), 1);
sign_list.genre(textFound) = textsTable.genre(textLoc(textFound));

% has_genre marks rows usable for genre analysis. We KEEP unlabeled rows
% in the table because step 01 (validation against the companion paper)
% must run on the full base set, genre or no genre.
sign_list.has_genre = ...
    sign_list.genre ~= "" & ...
    sign_list.genre ~= unspecifiedGenreLabel & ...
    ~ismissing(sign_list.genre);

%% ---- slim instance table ----------------------------------------------
% Keep only the columns the genre pipeline needs. Everything downstream
% (steps 01-05) works from this table alone.
instances = table;
instances.mdc         = string(sign_list.mdc);         % grapheme (Gardiner/MdC)
instances.text        = string(sign_list.text);        % source text (cluster unit)
instances.genre       = sign_list.genre;               % AKU-PAL Textinhalt
instances.has_genre   = sign_list.has_genre;
instances.epoche      = string(sign_list.epoche);      % epoch name
instances.date        = sign_list.date;                % midpoint of dating range (yrs, BCE negative)
instances.text_length = sign_list.text_length;         % nr. of signs in source text
instances.frequency   = sign_list.frequency;           % TLA whole-corpus frequency
instances.complexity  = sign_list.complexity;          % skeleton pixel count

% Require finite complexity and date (every later analysis does).
instances = instances(isfinite(instances.complexity) & isfinite(instances.date), :);

fprintf('\nBase-filtered set:     %6d instances, %4d texts, %3d graphemes\n', ...
    height(instances), numel(unique(instances.text)), numel(unique(instances.mdc)));
fprintf('  (expected from Python run: 29997 instances, 794 texts, 520 graphemes)\n');

labelled = instances(instances.has_genre, :);
fprintf('Genre-labeled subset: %6d instances, %4d texts, %3d graphemes, %d genres\n', ...
    height(labelled), numel(unique(labelled.text)), ...
    numel(unique(labelled.mdc)), numel(unique(labelled.genre)));
fprintf('  (expected from Python run: 29205 instances, 674 texts, 516 graphemes, 51 genres)\n');

save(analysisSetFile, 'instances');
fprintf('\nSaved %s\n', analysisSetFile);

%% ---- exemplar shapes for the Fig 2 "money figure" ----------------------
% Fig 2 (genre_paper_03) draws ACTUAL sign outlines for a couple of
% graphemes across registers. The outlines live in sign_list.shapes and
% are far too heavy to keep for all 30k rows, so we save just the New
% Kingdom, genre-labeled rows of the chosen exemplar signs.
exemplarRows = ismember(string(sign_list.mdc), exemplarSigns) & ...
               string(sign_list.epoche) == "Neues Reich" & ...
               sign_list.has_genre & ...
               isfinite(sign_list.complexity);

exemplar_shapes = table;
exemplar_shapes.mdc        = string(sign_list.mdc(exemplarRows));
exemplar_shapes.genre      = sign_list.genre(exemplarRows);
exemplar_shapes.text       = string(sign_list.text(exemplarRows));
exemplar_shapes.complexity = sign_list.complexity(exemplarRows);
exemplar_shapes.shapes     = sign_list.shapes(exemplarRows);   % cell of outline sets

save(exemplarShapesFile, 'exemplar_shapes');
fprintf('Saved %s (%d exemplar instances for %s)\n', ...
    exemplarShapesFile, height(exemplar_shapes), strjoin(exemplarSigns(:)', ', '));

%% ---- representative shapes for the shape-scatter figures ---------------
% The per-sign scatterplots (steps 04 and 05) draw each grapheme as an
% actual sign outline (shapescatter.m) instead of a dot. Each grapheme is
% represented by its earliest-dated attestation, the same convention the
% companion paper uses for its figures.
representativeMdc    = unique(string(sign_list.mdc));
representativeShapes = cell(numel(representativeMdc), 1);
for iMdc = 1:numel(representativeMdc)
    oneSign = sign_list(string(sign_list.mdc) == representativeMdc(iMdc), :);
    oneSign = sortrows(oneSign, 'date');    % NaN dates sort to the bottom
    representativeShapes{iMdc} = oneSign.shapes{1};
end

representative_shapes = table(representativeMdc, representativeShapes, ...
    'VariableNames', {'mdc', 'shapes'});
save(representativeShapesFile, 'representative_shapes');
fprintf('Saved %s (%d graphemes, earliest-attestation shapes)\n', ...
    representativeShapesFile, height(representative_shapes));

fprintf('\nDone. Next: genre_paper_01_validate_against_companion.m\n');

%% Run the next in sequence

genre_paper_01_validate_against_companion;