%% batch_resynthesize_dataset_V1.m
% Batch analyze/resynthesize instrument folders and save partial-model versions.
%
% Creates these versions for every input audio file:
%   full        = envelope + AM vibrato + FM vibrato
%   am_only     = envelope + AM vibrato only
%   fm_only     = envelope + FM vibrato only
%   no_vibrato  = envelope only, with AM and FM vibrato disabled
%
% Put this file in the same MATLAB folder as:
%   vib_analyze_harmonics_analysis_V27.m
%   vib_analyze_harmonics_resynthesize_V27.m
%
% Used to create dataset for listening tests

clear; clc;

%% ---------------- USER SETTINGS ----------------

analysisFcn = @vib_analyze_harmonics_analysis_V27;
resynthFcn  = @vib_analyze_harmonics_resynthesize_V27;

sourceFolders = [ ...
   "C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio"
];

batchOpts = struct();
batchOpts.outputRoot = "C:\Users\Andre\OneDrive\Documents\MATLAB\batch_resynth_outputs";
batchOpts.scanRecursive = true;
batchOpts.audioExtensions = [".wav", ".mp3", ".flac", ".m4a", ".aif", ".aiff"];
batchOpts.numHarmonics = 15;
batchOpts.saveParamsMat = false;
batchOpts.saveSynthDataMat = false;  % can become very large if true
batchOpts.closeFiguresAfterEachFile = true;

% Batch plotting should usually stay off, otherwise hundreds of figures may open.
batchOpts.plotAnalysis = true;
batchOpts.plotResynthesis = true;

% Normalization is useful for listening-test exports. Set false if you want
% raw model output levels preserved exactly.
batchOpts.resynthNormalize = true;
batchOpts.resynthPeak = 0.95;

% Keep these off for clean AM/FM/no-vibrato comparisons. You can turn noise
% on later if you want a separate "naturalized" condition.
batchOpts.noiseEnable = false;
batchOpts.freqJitterEnable = false;

% Set to a small number while testing, for example 5. Use Inf for all files.
batchOpts.maxFilesTotal = Inf;

% Optional: copy each source audio file into the matching output folder.
batchOpts.copyOriginal = false;

%% ---------------- VARIANT DEFINITIONS ----------------

variants = struct( ...
    'label',  {"full", "am_only", "fm_only", "no_vibrato"}, ...
    'keepAM', {true,   true,      false,     false}, ...
    'keepFM', {true,   false,     true,      false} ...
);

%% ---------------- BATCH RUN ----------------

if ~isfolder(batchOpts.outputRoot)
    mkdir(batchOpts.outputRoot);
end

logRows = {};
numFilesProcessed = 0;

fprintf('Batch output folder:\n  %s\n\n', char(batchOpts.outputRoot));

for folderIdx = 1:numel(sourceFolders)
    rootFolder = sourceFolders(folderIdx);
    folderName = local_last_path_part(rootFolder);
    folderLabel = sprintf('%02d_%s', folderIdx, char(local_sanitize_name(folderName)));
    folderOutRoot = fullfile(batchOpts.outputRoot, folderLabel);

    if ~isfolder(rootFolder)
        warning('Input folder does not exist: %s', char(rootFolder));
        logRows(end+1,:) = {datetime('now'), rootFolder, "", "", "", "missing_folder", "Input folder does not exist", NaN, NaN, NaN, NaN}; %#ok<SAGROW>
        continue;
    end

    audioFiles = local_find_audio_files(rootFolder, batchOpts.audioExtensions, batchOpts.scanRecursive);
    fprintf('[%02d/%02d] %s: found %d audio files.\n', folderIdx, numel(sourceFolders), char(folderName), numel(audioFiles));

    if isempty(audioFiles)
        logRows(end+1,:) = {datetime('now'), rootFolder, "", "", "", "no_audio_files", "No supported audio files found", NaN, NaN, NaN, NaN}; %#ok<SAGROW>
        continue;
    end

    for fileIdx = 1:numel(audioFiles)
        if numFilesProcessed >= batchOpts.maxFilesTotal
            fprintf('Reached batchOpts.maxFilesTotal = %g. Stopping.\n', batchOpts.maxFilesTotal);
            numFilesProcessed = 0;
            break;
        end

        audioPath = audioFiles(fileIdx);
        [audioFolder, baseName, sourceExt] = fileparts(audioPath);
        relFolder = local_relative_folder(audioFolder, rootFolder);
        fileOutDir = fullfile(folderOutRoot, relFolder);
        if ~isfolder(fileOutDir)
            mkdir(fileOutDir);
        end

        fprintf('  (%d/%d) Analyzing %s\n', fileIdx, numel(audioFiles), char(baseName));
        tFileStart = tic;

        try
            S = feval(analysisFcn, audioPath, ...
                'numHarmonics', batchOpts.numHarmonics, ...
                'plot_expEnv', batchOpts.plotAnalysis, ...
                'plot_vib', false, ...
                'plot_vib_overviews', batchOpts.plotAnalysis, ...
                'plot_harm_amps', false, ...
                'plot_waveform', batchOpts.plotAnalysis, ...
                'plot_spectrogram', false, ...
                'calcMetrics', false);

            paramsFull = S.params;
            fs = S.fs;
            f0Hz = local_safe_get(S, 'f0Hz', NaN);
            sourceDurSec = local_get_source_duration_from_S(S);

            if batchOpts.saveParamsMat
                paramsPath = fullfile(fileOutDir, local_sanitize_name(baseName) + "__analysis_params.mat");
                save(paramsPath, 'S', 'paramsFull', '-v7.3');
            end

            if batchOpts.copyOriginal
                copyfile(audioPath, fullfile(fileOutDir, local_sanitize_name(baseName) + "__original" + string(sourceExt)));
            end

            for v = 1:numel(variants)
                variant = variants(v);
                paramsVariant = local_make_partial_params(paramsFull, variant.keepAM, variant.keepFM);
                outName = local_sanitize_name(baseName) + "__" + variant.label + ".mp3";
                outPath = fullfile(fileOutDir, outName);

                fprintf('      -> %s\n', char(variant.label));

                [ySynth, synthData] = feval(resynthFcn, paramsVariant, ...
                    'fs', fs, ...
                    'playAudio', false, ...
                    'saveAudio', true, ...
                    'outputPath', char(outPath), ...
                    'plot_waveform', batchOpts.plotResynthesis, ...
                    'plot_amfm', false, ...
                    'plot_harmonic_controls', false, ...
                    'resynthNormalize', batchOpts.resynthNormalize, ...
                    'resynthPeak', batchOpts.resynthPeak, ...
                    'noiseEnable', batchOpts.noiseEnable, ...
                    'freqJitterEnable', batchOpts.freqJitterEnable); %#ok<ASGLU>

                if batchOpts.saveSynthDataMat
                    synthDataPath = replace(outPath, ".mp3", "__synthData.mat");
                    save(synthDataPath, 'synthData', '-v7.3');
                end

                logRows(end+1,:) = {datetime('now'), rootFolder, audioPath, variant.label, outPath, "ok", "", f0Hz, fs, sourceDurSec, toc(tFileStart)}; %#ok<SAGROW>
            end

            numFilesProcessed = numFilesProcessed + 1;

        catch ME
            warning('Failed on file: %s\nReason: %s', char(audioPath), ME.message);
            logRows(end+1,:) = {datetime('now'), rootFolder, audioPath, "", "", "error", string(ME.message), NaN, NaN, NaN, toc(tFileStart)}; %#ok<SAGROW>
        end

        if batchOpts.closeFiguresAfterEachFile
            close all force;
        end
    end

    % if numFilesProcessed >= batchOpts.maxFilesTotal
    %     break;
    % end
end

summaryPath = fullfile(batchOpts.outputRoot, "batch_resynth_summary.csv");
matSummaryPath = fullfile(batchOpts.outputRoot, "batch_resynth_summary.mat");

if isempty(logRows)
    T = table();
else
    T = cell2table(logRows, 'VariableNames', { ...
        'timeStamp', 'rootFolder', 'audioPath', 'variant', 'outputPath', ...
        'status', 'message', 'f0Hz', 'fs', 'sourceDurSec', 'elapsedSec'});
end

writetable(T, summaryPath);
save(matSummaryPath, 'T', 'sourceFolders', 'batchOpts', 'variants');

fprintf('\nDone. Processed %d source files.\n', numFilesProcessed);
fprintf('Summary CSV:\n  %s\n', char(summaryPath));
fprintf('Summary MAT:\n  %s\n', char(matSummaryPath));

%% ---------------- LOCAL FUNCTIONS ----------------

function audioFiles = local_find_audio_files(rootFolder, audioExtensions, scanRecursive)
    audioFiles = strings(0,1);
    for e = 1:numel(audioExtensions)
        ext = char(audioExtensions(e));
        if scanRecursive
            d = dir(fullfile(char(rootFolder), '**', ['*' ext]));
        else
            d = dir(fullfile(char(rootFolder), ['*' ext]));
        end
        d = d(~[d.isdir]);
        for k = 1:numel(d)
            audioFiles(end+1,1) = string(fullfile(d(k).folder, d(k).name)); %#ok<AGROW>
        end
    end
    audioFiles = unique(audioFiles, 'stable');
end

function paramsOut = local_make_partial_params(paramsIn, keepAM, keepFM)
    paramsOut = paramsIn;
    if ~isfield(paramsOut, 'harm') || isempty(paramsOut.harm)
        return;
    end
    for k = 1:numel(paramsOut.harm)
        if ~keepAM
            paramsOut.harm(k).amModel = local_zero_model(local_get_model(paramsOut.harm(k), 'amModel'));
        end
        if ~keepFM
            paramsOut.harm(k).fmModel = local_zero_model(local_get_model(paramsOut.harm(k), 'fmModel'));
        end
    end
end

function model = local_get_model(harmStruct, fieldName)
    if isstruct(harmStruct) && isfield(harmStruct, fieldName) && isstruct(harmStruct.(fieldName))
        model = harmStruct.(fieldName);
    else
        model = struct();
    end
end

function model = local_zero_model(model)
    if ~isstruct(model)
        model = struct();
    end
    model.freqHz = 0;
    model.amp = 0;
    model.phaseRad = 0;
    model.offset = 0;
    model.isVibrato = false;
    model.rejectReason = 'disabled_for_partial_model_export';
end

function folderName = local_last_path_part(pathIn)
    pathIn = strip(string(pathIn));
    pathIn = regexprep(pathIn, '[\/]+$', '');
    [~, folderName] = fileparts(pathIn);
    folderName = string(folderName);
    if strlength(folderName) == 0
        folderName = "folder";
    end
end

function safeName = local_sanitize_name(nameIn)
    safeName = string(nameIn);
    safeName = regexprep(safeName, '[<>:"/\\|?*]', '_');
    safeName = regexprep(safeName, '\s+', '_');
    safeName = regexprep(safeName, '_+', '_');
    safeName = strip(safeName, '_');
    if strlength(safeName) == 0
        safeName = "unnamed";
    end
end

function relFolder = local_relative_folder(fileFolder, rootFolder)
    fileFolder = string(fileFolder);
    rootFolder = regexprep(string(rootFolder), '[\/]+$', '');
    relFolder = erase(fileFolder, rootFolder);
    relFolder = regexprep(relFolder, '^[\/]+', '');
    if strlength(relFolder) == 0
        relFolder = "";
    end
end

function value = local_safe_get(s, fieldName, defaultValue)
    value = defaultValue;
    if isstruct(s) && isfield(s, fieldName)
        candidate = s.(fieldName);
        if isnumeric(candidate) && isscalar(candidate) && isfinite(candidate)
            value = candidate;
        end
    end
end

function durSec = local_get_source_duration_from_S(S)
    durSec = NaN;
    if isfield(S, 't') && numel(S.t) > 1
        durSec = S.t(end) + median(diff(S.t));
    elseif isfield(S, 'x') && isfield(S, 'fs') && isfinite(S.fs) && S.fs > 0
        durSec = numel(S.x) / S.fs;
    elseif isfield(S, 'params') && isfield(S.params, 'sourceNumSamples') && isfield(S.params, 'sourceFs') && S.params.sourceFs > 0
        durSec = S.params.sourceNumSamples / S.params.sourceFs;
    end
end
