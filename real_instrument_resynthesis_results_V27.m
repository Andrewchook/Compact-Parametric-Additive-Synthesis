%% real_instrument_resynthesis_results_V27.m
% Batch test script for the thesis section:
%   \section{Real Instrument Resynthesis Results}
%
% What this script creates:
%   1) tables/sample_table.csv
%   2) tables/metric_table.csv
%   3) tables/harmonic_error_table.csv
%   4) tables/summary_table_auto.csv
%   5) thesis figures for representative samples
%   6) resynthesized wav files for listening notes
%
% Required files on the MATLAB path:
%   vib_analyze_harmonics_analysis_V27.m
%   vib_analyze_harmonics_resynthesize_V27.m
%
% Recommended use:
%   Put this script in the same folder as the V27 analysis/resynthesis files,
%   update cfg.resultsDir if desired, then run this script.

clear; close all; clc;

%% ---------------- User settings ----------------
cfg = struct();
cfg.resultsDir = fullfile(pwd, 'real_instrument_results_V27');
cfg.numHarmonics = 15;
cfg.figureVisible = 'off';       % 'off' for batch mode, 'on' for interactive viewing
cfg.makeDetailedPlotsForAll = false;
cfg.savePerSampleParams = true;
cfg.saveResynthAudio = true;
cfg.validHarmonicMinPeakFrac = 0.005;  % count harmonic if peak ampNoVib exceeds this fraction of strongest harmonic
cfg.amEnabledThreshold = 0.005;         % fractional AM depth threshold for table count
cfg.fmEnabledThresholdHz = 0.10;        % FM depth threshold for table count
cfg.maxSpectrogramHz = 8000;
cfg.specWinMs = 46;
cfg.specHopMs = 10;
cfg.specNfft = 4096;
cfg.specDynRangeDb = 80;
cfg.selectedHarmonicsForPlots = [1 2 3 5 8 12 15];

% Representative figures are made for samples whose filename contains one
% of these patterns. These cover bowed strings, brass, reeds, and plucked strings.
cfg.representativeContains = [ ...
    "violin_A4_1_fortissimo", ...
    "cello_Fs2_long", ...
    "double-bass_A1_025_piano_pizz", ...
    "trumpet_A4_15_fortissimo", ...
    "trombone_As3_15", ...
    "tuba_A2_long", ...
    "bass-clarinet_B3_05", ...
    "guitar_C3_very-long", ...
    "mandolin_D4_very-long", ...
    "banjo_A4_very-long"];

%% ---------------- Audio files ----------------
audioFiles = [ ...
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\bass-clarinet_B3_05_piano_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\bass-clarinet_A2_1_pianissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\bass-clarinet_A3_1_fortissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\bass-clarinet_As2_1_pianissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\tuba_As1_1_piano_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\tuba_As2_1_fortissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\tuba_A2_1_fortissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\tuba_A2_long_mezzo-forte_vibrato.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\tuba_A3_long_mezzo-forte_vibrato.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trombone_As4_1_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trombone_As2_very-long_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trombone_As3_15_mezzo-forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trombone_A2_15_mezzo-forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trombone_A2_very-long_mezzo-forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trumpet_As3_1_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trumpet_As3_15_pianissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trumpet_B3_1_pianissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trumpet_A3_1_fortissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trumpet_A4_15_fortissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\guitar_A3_very-long_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\guitar_B3_very-long_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\guitar_C3_very-long_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\guitar_Cs3_very-long_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\guitar_D4_very-long_piano_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\violin_A3_05_forte_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\violin_A3_025_pianissimo_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\violin_A4_1_fortissimo_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\violin_A5_1_pianissimo_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\violin_A5_025_forte_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\mandolin_A4_very-long_piano_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\mandolin_B4_very-long_piano_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\mandolin_D4_very-long_piano_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\mandolin_E4_very-long_piano_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\mandolin_F5_very-long_piano_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\double-bass_A1_1_piano_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\double-bass_A1_15_piano_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\double-bass_A1_025_piano_pizz-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\double-bass_A3_1_fortissimo_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\double-bass_A3_15_forte_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\double-bass_As1_05_molto-pianissimo_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\cello_Fs2_long_mezzo-piano_non-vibrato.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\cello_As4_15_pianissimo_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\banjo_C6_very-long_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\banjo_Fs4_very-long_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\banjo_Gs3_very-long_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\cello_As2_05_forte_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\banjo_A4_very-long_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\banjo_A5_very-long_piano_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\bass-clarinet_B2_1_fortissimo_normal.mp3"
];

%% ---------------- Output folders ----------------
figDir = fullfile(cfg.resultsDir, 'figures');
audioDir = fullfile(cfg.resultsDir, 'audio');
tableDir = fullfile(cfg.resultsDir, 'tables');
paramDir = fullfile(cfg.resultsDir, 'params');
logDir = fullfile(cfg.resultsDir, 'logs');
local_mkdir(cfg.resultsDir);
local_mkdir(figDir);
local_mkdir(audioDir);
local_mkdir(tableDir);
local_mkdir(paramDir);
local_mkdir(logDir);

%% ---------------- V27 options ----------------
analysisOpts = struct();
analysisOpts.numHarmonics = cfg.numHarmonics;
analysisOpts.f0Method = 'majority';
analysisOpts.plot_expEnv = false;
analysisOpts.plot_vib = false;
analysisOpts.plot_vib_overviews = false;
analysisOpts.plot_harm_amps = false;
analysisOpts.plot_waveform = false;
analysisOpts.plot_spectrogram = false;
analysisOpts.calcMetrics = false;
analysisOpts.paramStoreDebugTracks = false;

synthOpts = struct();
synthOpts.playAudio = false;
synthOpts.saveAudio = false;
synthOpts.plot_waveform = false;
synthOpts.plot_amfm = false;
synthOpts.plot_harmonic_controls = false;
synthOpts.resynthNormalize = false;
synthOpts.noiseEnable = false;          % change to true for an optional listening-only variant
synthOpts.freqJitterEnable = false;     % keep false for strict model evaluation

%% ---------------- Batch run ----------------
sampleRows = {};
metricRows = {};
harmRows = {};
summaryRows = {};
failRows = {};

fprintf('Real instrument V27 batch test starting.\n');
fprintf('Output folder: %s\n\n', cfg.resultsDir);

for iFile = 1:numel(audioFiles)
    audioPath = audioFiles(iFile);
    [~, stem, ext] = fileparts(audioPath);
    fileName = stem + ext;
    sampleID = local_sample_id(stem);
    meta = local_parse_sample_name(stem);
    isRepresentative = cfg.makeDetailedPlotsForAll || any(contains(stem, cfg.representativeContains, 'IgnoreCase', true));

    fprintf('[%02d/%02d] %s\n', iFile, numel(audioFiles), fileName);

    if ~isfile(audioPath)
        warning('File not found, skipping: %s', audioPath);
        failRows(end+1,:) = {sampleID, string(audioPath), "file_not_found", ""}; %#ok<SAGROW>
        continue;
    end

    try
        S = local_call_name_value(@vib_analyze_harmonics_analysis_V27, audioPath, analysisOpts);
        [ySynth, synthData] = local_call_name_value_two(@vib_analyze_harmonics_resynthesize_V27, S.params, synthOpts);

        outWav = fullfile(audioDir, sampleID + "_V27_full.wav");
        if cfg.saveResynthAudio
            local_write_wav_scaled(outWav, ySynth, synthData.fs);
        else
            outWav = "";
        end

        sampleMetrics = local_compute_sample_metrics(S, ySynth, synthData.fs, cfg);
        harmErr = local_compute_harmonic_errors(S, synthData, cfg);
        sampleMetrics.meanAmpRelRmse = mean(harmErr.ampRelRmse, 'omitnan');
        sampleMetrics.meanFmRmseHz = mean(harmErr.fmRmseHz, 'omitnan');
        storage = local_storage_estimate(S.params, S.x);

        if isfield(S, 'params') && isfield(S.params, 'harm')
            numStoredHarm = numel(S.params.harm);
        else
            numStoredHarm = NaN;
        end
        numValidHarm = local_count_valid_harmonics(S, cfg);
        numAM = local_count_modulated_harmonics(S.params, 'amModel', cfg.amEnabledThreshold);
        numFM = local_count_modulated_harmonics(S.params, 'fmModel', cfg.fmEnabledThresholdHz);

        sampleRows(end+1,:) = { ... %#ok<SAGROW>
            sampleID, string(fileName), string(meta.instrument), string(meta.note), string(meta.durationToken), ...
            string(meta.dynamic), string(meta.articulation), string(meta.family), sampleMetrics.durationSec, ...
            S.f0Hz, numValidHarm, numStoredHarm, numAM, numFM, ...
            storage.paramScalars, storage.paramKiB, storage.rawAudioKiB, storage.paramPctOfRaw, string(outWav)};

        metricRows(end+1,:) = { ... %#ok<SAGROW>
            sampleID, string(meta.instrument), string(meta.note), string(meta.articulation), ...
            sampleMetrics.waveformNrmse, sampleMetrics.envelopeCorr, sampleMetrics.logSpectralDistanceDb, ...
            sampleMetrics.centroidMeanAbsErrorHz, sampleMetrics.meanAmpRelRmse, sampleMetrics.meanFmRmseHz, ...
            sampleMetrics.meanVibRateHz, sampleMetrics.meanFmDepthHz, sampleMetrics.meanAmDepthPct};

        for h = 1:height(harmErr)
            harmRows(end+1,:) = { ... %#ok<SAGROW>
                sampleID, string(meta.instrument), string(meta.note), string(meta.articulation), ...
                harmErr.harmonic(h), harmErr.ampRelRmse(h), harmErr.fmRmseHz(h), ...
                harmErr.vibRateHz(h), harmErr.amDepthPct(h), harmErr.fmDepthHz(h)};
        end

        autoSummary = local_auto_summary(meta, sampleMetrics);
        summaryRows(end+1,:) = { ... %#ok<SAGROW>
            sampleID, string(fileName), string(meta.instrument), string(meta.note), string(meta.articulation), ...
            string(autoSummary.overallResult), string(autoSummary.mainStrength), string(autoSummary.mainLimitation), ...
            "ADD LISTENING NOTE"};

        if isRepresentative
            local_plot_waveform_comparison(S, ySynth, synthData.fs, meta, sampleID, figDir, cfg);
            local_plot_spectrogram_comparison(S.x, S.fs, ySynth, synthData.fs, meta, sampleID, figDir, cfg);
            local_plot_amplitude_reconstruction(S, synthData, meta, sampleID, figDir, cfg);
            local_plot_fm_reconstruction(S, synthData, meta, sampleID, figDir, cfg);
        end

        if cfg.savePerSampleParams
            params = S.params; %#ok<NASGU>
            metrics = sampleMetrics; %#ok<NASGU>
            save(fullfile(paramDir, sampleID + "_params_metrics.mat"), 'params', 'metrics', 'harmErr', '-v7.3');
        end

        fprintf('    f0 = %.2f Hz | valid harmonics = %d | env corr = %.3f | LSD = %.2f dB\n', ...
            S.f0Hz, numValidHarm, sampleMetrics.envelopeCorr, sampleMetrics.logSpectralDistanceDb);

    catch ME
        warning('Failed on %s: %s', fileName, ME.message);
        failRows(end+1,:) = {sampleID, string(audioPath), "analysis_or_resynthesis_failed", string(ME.message)}; %#ok<SAGROW>
        local_write_error_log(fullfile(logDir, sampleID + "_error.txt"), ME);
    end
end

%% ---------------- Write tables ----------------
sampleTable = cell2table(sampleRows, 'VariableNames', { ...
    'sampleID','fileName','instrument','note','durationToken','dynamic','articulation','family', ...
    'durationSec','estimatedF0Hz','numValidHarmonics','numStoredHarmonics','numAMHarmonics','numFMHarmonics', ...
    'parameterScalars','parameterKiB','rawAudioKiB','parameterPctOfRaw','resynthWav'});

metricTable = cell2table(metricRows, 'VariableNames', { ...
    'sampleID','instrument','note','articulation','waveformNRMSE','envelopeCorrelation', ...
    'logSpectralDistanceDb','centroidMeanAbsErrorHz','meanAmpRelRMSE','meanFmRMSEHz', ...
    'meanVibratoRateHz','meanFmDepthHz','meanAmDepthPct'});

harmonicErrorTable = cell2table(harmRows, 'VariableNames', { ...
    'sampleID','instrument','note','articulation','harmonic','ampRelRMSE','fmRMSEHz', ...
    'vibratoRateHz','amDepthPct','fmDepthHz'});

summaryTable = cell2table(summaryRows, 'VariableNames', { ...
    'sampleID','fileName','instrument','note','articulation','overallResultAuto', ...
    'mainStrengthAuto','mainLimitationAuto','listeningNotes'});

failureTable = cell2table(failRows, 'VariableNames', {'sampleID','audioPath','status','message'});

writetable(sampleTable, fullfile(tableDir, 'sample_table.csv'));
writetable(metricTable, fullfile(tableDir, 'metric_table.csv'));
writetable(harmonicErrorTable, fullfile(tableDir, 'harmonic_error_table.csv'));
writetable(summaryTable, fullfile(tableDir, 'summary_table_auto.csv'));
writetable(failureTable, fullfile(tableDir, 'failure_table.csv'));
save(fullfile(cfg.resultsDir, 'real_instrument_batch_summary.mat'), ...
    'cfg', 'sampleTable', 'metricTable', 'harmonicErrorTable', 'summaryTable', 'failureTable');

local_write_readme(cfg.resultsDir);

fprintf('\nDone. Tables written to:\n  %s\n', tableDir);
fprintf('Representative figures written to:\n  %s\n', figDir);
fprintf('Resynthesized audio written to:\n  %s\n', audioDir);

%% ================= Local functions =================

function out = local_call_name_value(funHandle, firstArg, optsStruct)
    % Most versions of these V27 functions accept an options struct as the
    % second argument. Newer MATLAB versions also accept name-value pairs.
    % Try the struct call first, then fall back to name-value form.
    try
        out = funHandle(firstArg, optsStruct);
    catch
        nv = local_struct_to_nv(optsStruct);
        out = funHandle(firstArg, nv{:});
    end
end

function [out1, out2] = local_call_name_value_two(funHandle, firstArg, optsStruct)
    try
        [out1, out2] = funHandle(firstArg, optsStruct);
    catch
        nv = local_struct_to_nv(optsStruct);
        [out1, out2] = funHandle(firstArg, nv{:});
    end
end

function c = local_struct_to_nv(s)
    names = fieldnames(s);
    c = cell(1, 2*numel(names));
    for ii = 1:numel(names)
        c{2*ii-1} = names{ii};
        c{2*ii} = s.(names{ii});
    end
end

function local_mkdir(p)
    if ~exist(p, 'dir')
        mkdir(p);
    end
end

function id = local_sample_id(stem)
    id = string(regexprep(char(stem), '[^A-Za-z0-9]+', '_'));
    id = regexprep(id, '^_+|_+$', '');
end

function meta = local_parse_sample_name(stem)
    parts = split(string(stem), '_');
    meta = struct();
    meta.instrument = local_get_part(parts, 1);
    meta.note = local_get_part(parts, 2);
    meta.durationToken = local_get_part(parts, 3);
    meta.dynamic = local_get_part(parts, 4);
    if numel(parts) >= 5
        meta.articulation = strjoin(parts(5:end), '_');
    else
        meta.articulation = "";
    end
    meta.family = local_family(meta.instrument, meta.articulation);
end

function s = local_get_part(parts, idx)
    if numel(parts) >= idx
        s = parts(idx);
    else
        s = "";
    end
end

function family = local_family(instrument, articulation)
    inst = lower(string(instrument));
    art = lower(string(articulation));
    if any(inst == ["trumpet","trombone","tuba"])
        family = "brass";
    elseif contains(inst, "clarinet")
        family = "woodwind/reed";
    elseif any(inst == ["violin","cello","double-bass"]) && ~contains(art, "pizz")
        family = "bowed string";
    elseif any(inst == ["guitar","mandolin","banjo"]) || contains(art, "pizz")
        family = "plucked string";
    else
        family = "other";
    end
end

function metrics = local_compute_sample_metrics(S, ySynth, fsSynth, cfg)
    x = S.x(:);
    fs = S.fs;
    if fsSynth ~= fs
        ySynth = local_resample_linear(ySynth(:), fsSynth, fs);
    else
        ySynth = ySynth(:);
    end
    N = min(numel(x), numel(ySynth));
    x = x(1:N);
    y = ySynth(1:N);
    yScaled = local_match_rms_and_gain(x, y);

    metrics = struct();
    metrics.durationSec = N / fs;
    metrics.waveformNrmse = local_rms(x - yScaled) / max(local_rms(x), eps);

    envWin = max(8, round(0.010 * fs));
    ex = movmean(abs(x), envWin);
    ey = movmean(abs(yScaled), envWin);
    metrics.envelopeCorr = local_corr(ex, ey);

    [lsdDb, centErrHz] = local_spectral_metrics(x, yScaled, fs, cfg);
    metrics.logSpectralDistanceDb = lsdDb;
    metrics.centroidMeanAbsErrorHz = centErrHz;

    metrics.meanAmpRelRmse = NaN;
    metrics.meanFmRmseHz = NaN;
    metrics.meanVibRateHz = local_mean_harmonic_metric(S, 'vibRateHz');
    metrics.meanFmDepthHz = local_mean_harmonic_metric(S, 'fmDepthHz');
    metrics.meanAmDepthPct = local_mean_harmonic_metric(S, 'amDepthPct');
end

function harmErr = local_compute_harmonic_errors(S, synthData, cfg)
    K = 0;
    if isfield(S, 'harm')
        K = numel(S.harm);
    end
    harmonic = (1:K).';
    ampRelRmse = nan(K,1);
    fmRmseHz = nan(K,1);
    vibRateHz = nan(K,1);
    amDepthPct = nan(K,1);
    fmDepthHz = nan(K,1);

    if isfield(S, 'params') && isfield(S.params, 'analyticAmpScale')
        ampScale = S.params.analyticAmpScale;
    else
        ampScale = 2;
    end

    for k = 1:K
        hk = S.harm(k);
        if isfield(hk, 'metrics')
            vibRateHz(k) = local_get_scalar(hk.metrics, 'vibRateHz', NaN);
            amDepthPct(k) = local_get_scalar(hk.metrics, 'amDepthPct', NaN);
            fmDepthHz(k) = local_get_scalar(hk.metrics, 'fmDepthHz', NaN);
        end

        if isfield(hk, 'ampEnv') && ~isempty(hk.ampEnv) && isfield(synthData, 'harm') && numel(synthData.harm) >= k
            A_meas = ampScale * hk.ampEnv(:);
            A_rec = synthData.harm(k).Ak(:);
            A_rec = local_match_length(A_rec, numel(A_meas));
            valid = isfinite(A_meas) & isfinite(A_rec) & A_meas > 0;
            if nnz(valid) > 16 && local_rms(A_meas(valid)) > 0
                A_rec_scaled = local_match_rms_and_gain(A_meas(valid), A_rec(valid));
                ampRelRmse(k) = local_rms(A_meas(valid) - A_rec_scaled) / max(local_rms(A_meas(valid)), eps);
            end
        end

        if isfield(hk, 'vibFmHz') && ~isempty(hk.vibFmHz) && isfield(synthData, 'harm') && numel(synthData.harm) >= k
            fm_meas = hk.vibFmHz(:);
            fm_rec = synthData.harm(k).fmSinHz(:);
            fm_rec = local_match_length(fm_rec, numel(fm_meas));
            valid = isfinite(fm_meas) & isfinite(fm_rec);
            if nnz(valid) > 16
                fmRmseHz(k) = local_rms(fm_meas(valid) - fm_rec(valid));
            end
        end
    end

    harmErr = table(harmonic, ampRelRmse, fmRmseHz, vibRateHz, amDepthPct, fmDepthHz);
end

function storage = local_storage_estimate(params, x)
    storage = struct();
    storage.paramScalars = local_count_scalars(params);
    storage.paramBytes = 8 * storage.paramScalars;
    storage.paramKiB = storage.paramBytes / 1024;
    storage.rawAudioBytes = 2 * numel(x);  % 16-bit PCM reference size, matching earlier thesis estimates
    storage.rawAudioKiB = storage.rawAudioBytes / 1024;
    storage.paramPctOfRaw = 100 * storage.paramBytes / max(storage.rawAudioBytes, eps);
end

function n = local_count_scalars(x)
    if isnumeric(x) || islogical(x)
        n = numel(x);
    elseif isstruct(x)
        n = 0;
        for ii = 1:numel(x)
            f = fieldnames(x(ii));
            for jj = 1:numel(f)
                n = n + local_count_scalars(x(ii).(f{jj}));
            end
        end
    elseif iscell(x)
        n = 0;
        for ii = 1:numel(x)
            n = n + local_count_scalars(x{ii});
        end
    else
        n = 0;
    end
end

function n = local_count_valid_harmonics(S, cfg)
    if ~isfield(S, 'harm') || isempty(S.harm)
        n = 0;
        return;
    end
    peaks = nan(numel(S.harm),1);
    for k = 1:numel(S.harm)
        if isfield(S.harm(k), 'ampNoVib') && ~isempty(S.harm(k).ampNoVib)
            peaks(k) = max(S.harm(k).ampNoVib(:), [], 'omitnan');
        end
    end
    maxPeak = max(peaks, [], 'omitnan');
    if ~isfinite(maxPeak) || maxPeak <= 0
        n = 0;
    else
        n = nnz(peaks >= cfg.validHarmonicMinPeakFrac * maxPeak);
    end
end

function n = local_count_modulated_harmonics(params, modelField, threshold)
    n = 0;
    if ~isfield(params, 'harm')
        return;
    end
    for k = 1:numel(params.harm)
        if isfield(params.harm(k), modelField)
            m = params.harm(k).(modelField);
            if isfield(m, 'amp') && isfinite(m.amp) && abs(m.amp) >= threshold
                n = n + 1;
            end
        end
    end
end

function yScaled = local_match_rms_and_gain(x, y)
    x = x(:);
    y = y(:);
    N = min(numel(x), numel(y));
    x = x(1:N);
    y = y(1:N);
    valid = isfinite(x) & isfinite(y);
    yScaled = y;
    if nnz(valid) < 2 || sum(y(valid).^2) <= 0
        return;
    end
    g = sum(x(valid).*y(valid)) / sum(y(valid).^2);
    if isfinite(g)
        yScaled = g * y;
    end
end

function r = local_rms(x)
    x = x(:);
    x = x(isfinite(x));
    if isempty(x)
        r = NaN;
    else
        r = sqrt(mean(x.^2));
    end
end

function c = local_corr(x, y)
    x = x(:);
    y = y(:);
    N = min(numel(x), numel(y));
    x = x(1:N);
    y = y(1:N);
    valid = isfinite(x) & isfinite(y);
    if nnz(valid) < 3
        c = NaN;
        return;
    end
    x = x(valid) - mean(x(valid));
    y = y(valid) - mean(y(valid));
    den = sqrt(sum(x.^2) * sum(y.^2));
    if den <= 0
        c = NaN;
    else
        c = sum(x.*y) / den;
    end
end

function [lsdDb, centroidErrHz] = local_spectral_metrics(x, y, fs, cfg)
    [Xdb, ~, f, Xmag] = local_stft_db_and_mag(x, fs, cfg);
    [Ydb, ~, ~, Ymag] = local_stft_db_and_mag(y, fs, cfg);
    M = min(size(Xdb,2), size(Ydb,2));
    F = min(size(Xdb,1), size(Ydb,1));
    Xdb = Xdb(1:F,1:M);
    Ydb = Ydb(1:F,1:M);
    Xmag = Xmag(1:F,1:M);
    Ymag = Ymag(1:F,1:M);
    band = f(1:F) <= cfg.maxSpectrogramHz;
    D = Xdb(band,:) - Ydb(band,:);
    lsdDb = sqrt(mean(D(:).^2, 'omitnan'));

    fb = f(1:F);
    fb = fb(band);
    Xb = Xmag(band,:);
    Yb = Ymag(band,:);
    cx = sum(fb .* Xb, 1) ./ max(sum(Xb, 1), eps);
    cy = sum(fb .* Yb, 1) ./ max(sum(Yb, 1), eps);
    centroidErrHz = mean(abs(cx - cy), 'omitnan');
end

function [db, tt, ff, mag] = local_stft_db_and_mag(x, fs, cfg)
    x = x(:);
    winN = max(64, round(cfg.specWinMs/1000 * fs));
    hopN = max(1, round(cfg.specHopMs/1000 * fs));
    nfft = max(cfg.specNfft, 2^nextpow2(winN));
    w = local_hann(winN);
    if numel(x) < winN
        x = [x; zeros(winN - numel(x), 1)];
    end
    numFrames = 1 + floor((numel(x) - winN) / hopN);
    numBins = floor(nfft/2) + 1;
    mag = zeros(numBins, numFrames);
    tt = zeros(1, numFrames);
    for m = 1:numFrames
        idx = (1:winN) + (m-1)*hopN;
        frame = x(idx) .* w;
        X = fft(frame, nfft);
        mag(:,m) = abs(X(1:numBins));
        tt(m) = (idx(1) + idx(end))/(2*fs);
    end
    ff = (0:numBins-1).' * fs/nfft;
    db = 20*log10(mag + 1e-12);
end

function w = local_hann(N)
    n = (0:N-1).';
    if N <= 1
        w = ones(N,1);
    else
        w = 0.5 - 0.5*cos(2*pi*n/(N-1));
    end
end

function y = local_resample_linear(x, fsIn, fsOut)
    x = x(:);
    if fsIn == fsOut
        y = x;
        return;
    end
    tIn = (0:numel(x)-1).' / fsIn;
    tOut = (0:round(tIn(end)*fsOut)).' / fsOut;
    y = interp1(tIn, x, tOut, 'linear', 0);
end

function x2 = local_match_length(x, N)
    x = x(:);
    if numel(x) == N
        x2 = x;
    elseif isempty(x)
        x2 = zeros(N,1);
    else
        tOld = linspace(0,1,numel(x)).';
        tNew = linspace(0,1,N).';
        x2 = interp1(tOld, x, tNew, 'linear', 'extrap');
    end
end

function m = local_mean_harmonic_metric(S, fieldName)
    vals = nan(numel(S.harm),1);
    for k = 1:numel(S.harm)
        if isfield(S.harm(k), 'metrics') && isfield(S.harm(k).metrics, fieldName)
            vals(k) = S.harm(k).metrics.(fieldName);
        end
    end
    m = mean(vals, 'omitnan');
end

function val = local_get_scalar(s, fieldName, defaultVal)
    val = defaultVal;
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName)) && isnumeric(s.(fieldName)) && isscalar(s.(fieldName))
        if isfinite(s.(fieldName))
            val = s.(fieldName);
        end
    end
end

function local_plot_waveform_comparison(S, ySynth, fsSynth, meta, sampleID, figDir, cfg)
    x = S.x(:);
    fs = S.fs;
    if fsSynth ~= fs
        y = local_resample_linear(ySynth(:), fsSynth, fs);
    else
        y = ySynth(:);
    end
    N = min(numel(x), numel(y));
    x = x(1:N);
    y = local_match_rms_and_gain(x, y(1:N));
    t = (0:N-1).' / fs;
    envWin = max(8, round(0.010 * fs));
    ex = movmean(abs(x), envWin);
    ey = movmean(abs(y), envWin);

    fig = figure('Name', sampleID + " waveform comparison", 'Color','w', 'Visible', cfg.figureVisible);
    tiledlayout(fig, 2, 1, 'TileSpacing','compact', 'Padding','compact');
    nexttile;
    plot(t, x, 'DisplayName','Original'); hold on;
    plot(t, y, 'DisplayName','V27 resynthesis');
    grid on; xlabel('Time (s)'); ylabel('Amplitude');
    title(sprintf('%s %s %s: waveform comparison', meta.instrument, meta.note, meta.articulation), 'Interpreter','none');
    legend('Location','best');
    nexttile;
    plot(t, ex, 'DisplayName','Original abs envelope'); hold on;
    plot(t, ey, 'DisplayName','Resynth abs envelope');
    grid on; xlabel('Time (s)'); ylabel('Smoothed |x[n]|');
    title('Broad amplitude envelope comparison');
    legend('Location','best');
    local_save_figure(fig, fullfile(figDir, sampleID + "_waveform.png"));
end

function local_plot_spectrogram_comparison(x, fs, ySynth, fsSynth, meta, sampleID, figDir, cfg)
    if fsSynth ~= fs
        y = local_resample_linear(ySynth(:), fsSynth, fs);
    else
        y = ySynth(:);
    end
    N = min(numel(x), numel(y));
    x = x(1:N);
    y = local_match_rms_and_gain(x, y(1:N));
    [Xdb, tx, f] = local_stft_db_and_mag(x, fs, cfg);
    [Ydb, ty, ~] = local_stft_db_and_mag(y, fs, cfg);
    climMax = max([Xdb(:); Ydb(:)], [], 'omitnan');
    clim = [climMax - cfg.specDynRangeDb, climMax];

    fig = figure('Name', sampleID + " spectrogram comparison", 'Color','w', 'Visible', cfg.figureVisible);
    tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');
    nexttile;
    imagesc(tx, f/1000, Xdb); axis xy; ylim([0 cfg.maxSpectrogramHz/1000]); caxis(clim);
    xlabel('Time (s)'); ylabel('Frequency (kHz)'); title('Original'); colorbar;
    nexttile;
    imagesc(ty, f/1000, Ydb); axis xy; ylim([0 cfg.maxSpectrogramHz/1000]); caxis(clim);
    xlabel('Time (s)'); ylabel('Frequency (kHz)'); title('V27 resynthesis'); colorbar;
    sgtitle(sprintf('%s %s %s: spectrogram comparison', meta.instrument, meta.note, meta.articulation), 'Interpreter','none');
    local_save_figure(fig, fullfile(figDir, sampleID + "_spectrogram.png"));
end

function local_plot_amplitude_reconstruction(S, synthData, meta, sampleID, figDir, cfg)
    K = numel(S.harm);
    selected = cfg.selectedHarmonicsForPlots(cfg.selectedHarmonicsForPlots <= K);
    if isempty(selected)
        return;
    end
    if isfield(S, 'params') && isfield(S.params, 'analyticAmpScale')
        ampScale = S.params.analyticAmpScale;
    else
        ampScale = 2;
    end
    t = S.t(:);
    harmErr = local_compute_harmonic_errors(S, synthData, cfg);

    fig = figure('Name', sampleID + " amplitude reconstruction", 'Color','w', 'Visible', cfg.figureVisible);
    tiledlayout(fig, 2, 1, 'TileSpacing','compact', 'Padding','compact');
    nexttile;
    hold on;
    for kk = selected
        if isfield(S.harm(kk), 'ampEnv') && numel(synthData.harm) >= kk
            A_meas = ampScale * S.harm(kk).ampEnv(:);
            A_rec = local_match_length(synthData.harm(kk).Ak(:), numel(A_meas));
            % Normalize each curve pair by measured peak so different harmonics fit on one axis.
            denom = max(A_meas, [], 'omitnan');
            if isfinite(denom) && denom > 0
                plot(t, A_meas/denom, '-', 'DisplayName', sprintf('H%d measured', kk));
                plot(t, A_rec/denom, '--', 'DisplayName', sprintf('H%d reconstructed', kk));
            end
        end
    end
    grid on; xlabel('Time (s)'); ylabel('Normalized amplitude');
    title('Measured harmonic amplitudes vs reconstructed amplitudes');
    legend('Location','eastoutside');

    nexttile;
    bar(harmErr.harmonic, harmErr.ampRelRmse);
    grid on; xlabel('Harmonic number'); ylabel('Relative RMSE');
    title('Amplitude reconstruction error by harmonic');
    sgtitle(sprintf('%s %s %s: harmonic amplitude reconstruction', meta.instrument, meta.note, meta.articulation), 'Interpreter','none');
    local_save_figure(fig, fullfile(figDir, sampleID + "_harmonic_amplitude_reconstruction.png"));
end

function local_plot_fm_reconstruction(S, synthData, meta, sampleID, figDir, cfg)
    K = numel(S.harm);
    selected = cfg.selectedHarmonicsForPlots(cfg.selectedHarmonicsForPlots <= K);
    if isempty(selected)
        return;
    end
    t = S.t(:);
    harmErr = local_compute_harmonic_errors(S, synthData, cfg);

    fig = figure('Name', sampleID + " FM reconstruction", 'Color','w', 'Visible', cfg.figureVisible);
    tiledlayout(fig, 2, 1, 'TileSpacing','compact', 'Padding','compact');
    nexttile;
    hold on;
    for kk = selected
        if isfield(S.harm(kk), 'vibFmHz') && numel(synthData.harm) >= kk
            fm_meas = S.harm(kk).vibFmHz(:);
            fm_rec = local_match_length(synthData.harm(kk).fmSinHz(:), numel(fm_meas));
            if any(isfinite(fm_meas)) || any(isfinite(fm_rec))
                plot(t, fm_meas, '-', 'DisplayName', sprintf('H%d measured', kk));
                plot(t, fm_rec, '--', 'DisplayName', sprintf('H%d fitted', kk));
            end
        end
    end
    grid on; xlabel('Time (s)'); ylabel('FM residual (Hz)');
    title('Measured FM residual vs fitted FM residual');
    legend('Location','eastoutside');

    nexttile;
    bar(harmErr.harmonic, harmErr.fmRmseHz);
    grid on; xlabel('Harmonic number'); ylabel('FM RMSE (Hz)');
    title('FM reconstruction error by harmonic');
    sgtitle(sprintf('%s %s %s: instantaneous frequency reconstruction', meta.instrument, meta.note, meta.articulation), 'Interpreter','none');
    local_save_figure(fig, fullfile(figDir, sampleID + "_fm_reconstruction.png"));
end

function local_save_figure(fig, outPath)
    try
        exportgraphics(fig, outPath, 'Resolution', 200);
    catch
        saveas(fig, outPath);
    end
    close(fig);
end

function local_write_wav_scaled(outPath, y, fs)
    y = y(:);
    pk = max(abs(y), [], 'omitnan');
    if isfinite(pk) && pk > 0.999
        y = 0.95 * y / pk;
    end
    y(~isfinite(y)) = 0;
    audiowrite(outPath, y, fs);
end

function summary = local_auto_summary(meta, metrics)
    summary = struct();
    if metrics.logSpectralDistanceDb < 14 && metrics.envelopeCorr > 0.90
        summary.overallResult = "good";
    elseif metrics.logSpectralDistanceDb < 22 && metrics.envelopeCorr > 0.75
        summary.overallResult = "fair";
    else
        summary.overallResult = "limited";
    end

    fam = lower(string(meta.family));
    switch fam
        case "bowed string"
            summary.mainStrength = "sustained harmonic structure and vibrato motion";
            summary.mainLimitation = "bow noise, irregular vibrato, and upper partial variation";
        case "brass"
            summary.mainStrength = "stable harmonic spacing and bright sustain";
            summary.mainLimitation = "sharp attack brightness and noisy upper harmonics";
        case "woodwind/reed"
            summary.mainStrength = "low harmonic envelope and steady pitch region";
            summary.mainLimitation = "reed noise and weak upper harmonic tracking";
        case "plucked string"
            summary.mainStrength = "overall decay envelope and harmonic spacing";
            summary.mainLimitation = "pluck transient, fast decay, and nonharmonic attack content";
        otherwise
            summary.mainStrength = "overall harmonic envelope";
            summary.mainLimitation = "non-ideal transient or noisy components";
    end

    if metrics.meanAmpRelRmse > 0.50
        summary.mainLimitation = summary.mainLimitation + "; high harmonic amplitude error";
    elseif metrics.meanFmRmseHz > 3
        summary.mainLimitation = summary.mainLimitation + "; single-sinusoid FM mismatch";
    end
end

function local_write_error_log(outPath, ME)
    fid = fopen(outPath, 'w');
    if fid < 0
        return;
    end
    fprintf(fid, '%s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(fid, '  at %s line %d\n', ME.stack(k).name, ME.stack(k).line);
    end
    fclose(fid);
end

function local_write_readme(resultsDir)
    txt = [ ...
        "Real instrument resynthesis results output\n" + ...
        "\n" + ...
        "tables/sample_table.csv: sample metadata, duration, f0, harmonic counts, and storage estimates.\n" + ...
        "tables/metric_table.csv: waveform, envelope, spectrogram, and averaged harmonic metrics.\n" + ...
        "tables/harmonic_error_table.csv: per-harmonic AM/FM reconstruction errors.\n" + ...
        "tables/summary_table_auto.csv: auto-filled strengths and limitations. Replace the listeningNotes column after listening.\n" + ...
        "figures/: representative waveform, spectrogram, amplitude, and FM plots.\n" + ...
        "audio/: V27 resynthesized wav files for listening observations.\n" + ...
        "params/: compact parameter structs and metrics for each successful sample.\n"];
    fid = fopen(fullfile(resultsDir, 'README_real_results.txt'), 'w');
    if fid >= 0
        fprintf(fid, '%s', txt);
        fclose(fid);
    end
end
