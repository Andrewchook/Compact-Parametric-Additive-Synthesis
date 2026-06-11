%% objective_parameter_model_comparison_10_samples_V27.m
% Batch test script for thesis Results chapter original-vs-resynthesis quantitative tables.
%
% Purpose:
%   This script compares several compact V27 model variants against the
%   original audio recording. It is a smaller 10-sample version intended
%   for quick slide/table iteration while preserving instrument-family
%   coverage.
%
% Required on the MATLAB path:
%   vib_analyze_harmonics_analysis_V27.m
%   vib_analyze_harmonics_resynthesize_V27.m
%   vib_analyze_harmonics_metrics_V5_patched.m
%
% Reference result scripts used for the data set and conventions:
%   real_instrument_resynthesis_results_V27.m
%   envelope_results_V27.m
%   temporal_segmentation_results_V27.m
%   vib_analyze_harmonics_test_resynth_V4.m
%
% Main outputs:
%   objective_parameter_model_comparison_10_samples_V27/tables/combined_quantitative_table.csv
%   objective_parameter_model_comparison_10_samples_V27/tables/objective_metric_table.csv
%   objective_parameter_model_comparison_10_samples_V27/tables/parameter_reduction_table.csv
%   objective_parameter_model_comparison_10_samples_V27/tables/bitrate_comparison_table.csv
%   objective_parameter_model_comparison_10_samples_V27/tables/bitrate_summary_table.csv
%   objective_parameter_model_comparison_10_samples_V27/tables/literature_bitrate_template.csv
%   objective_parameter_model_comparison_10_samples_V27/tables/harmonic_error_table.csv
%   objective_parameter_model_comparison_10_samples_V27/tables/summary_by_family.csv
%   objective_parameter_model_comparison_10_samples_V27/tables/summary_by_model.csv
%   objective_parameter_model_comparison_10_samples_V27/tables/failure_table.csv
%
% Notes:
%   - The V5 patched metric function supplies the Horner/Beauchamp/So-style
%     harmonic, mel-band, and MFCC metrics, plus storage estimates.
%   - Audio-domain metrics are computed directly from original vs.
%     resynthesized waveforms.
%   - The stored-parameter counts are computed from the variant parameter
%     struct actually used to synthesize each comparison audio.

clear; close all; clc;

%% ---------------- User settings ----------------
cfg = struct();
cfg.resultsDir = fullfile(pwd, 'objective_parameter_model_comparison_10_samples_V27');
cfg.numHarmonics = 15;

% Run compact-model variants for a meaningful comparison.
% staticHarmonic : fixed harmonic amplitudes + fixed harmonic frequencies
% envelopeOnly   : compact harmonic envelopes only, no AM/FM vibrato
% noAM           : compact envelopes + FM only
% noFM           : compact envelopes + AM only
% full           : compact envelopes + AM + FM
cfg.comparisonLabels = ["staticHarmonic", "envelopeOnly", "noAM", "noFM", "full"];

% Objective metric settings.
cfg.validHarmonicMinPeakFrac = 0.005;
cfg.specWinMs = 46;
cfg.specHopMs = 10;
cfg.specNfft = 4096;
cfg.maxSpectrogramHz = 8000;
cfg.logSpecFloorDb = -120;

% Storage assumptions. These match the earlier V5 metrics defaults.
cfg.parameterBytesPerScalar = 8;       % double precision compact parameters
cfg.audioBytesPerSample = 2;           % 16-bit mono PCM reference
cfg.analysisBytesPerValue = 8;         % double precision analysis traces

% Bit-rate comparison assumptions.
% Model bit rate is computed as stored parameter bits divided by source duration.
% Input compressed bit rate is computed from the actual input audio file size.
% WAV bit rate is reported as a 16-bit mono PCM equivalent by default.
cfg.wavBitsPerSample = 16;
cfg.wavNumChannels = 1;

% Output controls.
cfg.savePerSampleMat = true;
cfg.saveResynthAudio = false;          % set true if you want wav files for all comparisons
cfg.figureVisible = 'off';
cfg.makeQuickFigures = false;

%% ---------------- Audio files ----------------
% Ten representative files, selected to keep all instrument families in the
% test set while keeping the batch fast enough for slide/table iteration.
%
% Family coverage:
%   woodwind/reed   : bass clarinet
%   brass           : trumpet, trombone, tuba
%   bowed string    : violin, cello
%   plucked string  : guitar, mandolin, banjo
%
% Update only the base folder below if your Validated_test_audio directory
% is in a different location.
baseAudioDir = "C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio";

audioFiles = fullfile(baseAudioDir, [
    "bass-clarinet_B3_05_piano_normal.mp3";              % woodwind/reed
    "bass-clarinet_A2_1_pianissimo_normal.mp3";          % woodwind/reed
    "trumpet_A4_15_fortissimo_normal.mp3";               % brass
    "trombone_As3_15_mezzo-forte_normal.mp3";            % brass
    "tuba_A2_long_mezzo-forte_vibrato.mp3";              % brass
    "violin_A4_1_fortissimo_arco-normal.mp3";            % bowed string
    "cello_Fs2_long_mezzo-piano_non-vibrato.mp3";        % bowed string
    "guitar_C3_very-long_forte_normal.mp3";              % plucked string
    "mandolin_D4_very-long_piano_normal.mp3";            % plucked string
    "banjo_A4_very-long_forte_normal.mp3"                % plucked string
]);

%% ---------------- Output folders ----------------
tableDir = fullfile(cfg.resultsDir, 'tables');
matDir = fullfile(cfg.resultsDir, 'mat');
audioDir = fullfile(cfg.resultsDir, 'audio');
figDir = fullfile(cfg.resultsDir, 'figures');
local_mkdir(cfg.resultsDir);
local_mkdir(tableDir);
local_mkdir(matDir);
local_mkdir(audioDir);
local_mkdir(figDir);

%% ---------------- V27 analysis/resynthesis options ----------------
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
synthOpts.noiseEnable = false;
synthOpts.freqJitterEnable = false;

metricOptsBase = struct();
metricOptsBase.paperMetrics = true;
metricOptsBase.paperVerbose = false;
metricOptsBase.storageMetrics = true;
metricOptsBase.storageVerbose = false;
metricOptsBase.storageParameterBytes = cfg.parameterBytesPerScalar;
metricOptsBase.storageAudioBytesPerSample = cfg.audioBytesPerSample;
metricOptsBase.storageAnalysisBytesPerValue = cfg.analysisBytesPerValue;
metricOptsBase.storageUseCompactParams = true;
metricOptsBase.storageIncludeAnalysisMetrics = false;
metricOptsBase.compactModelMetrics = true;
metricOptsBase.comparisonMetrics = false;
metricOptsBase.comparisonDisplay = 'none';

%% ---------------- Verify required functions ----------------
local_require_function('vib_analyze_harmonics_analysis_V27');
local_require_function('vib_analyze_harmonics_resynthesize_V27');
local_require_function('vib_analyze_harmonics_metrics_V5_patched');

%% ---------------- Batch run ----------------
objectiveRows = {};
storageRows = {};
combinedRows = {};
harmRows = {};
bitrateRows = {};
failureRows = {};

fprintf('10-sample model-comparison V27 batch starting.\n');
fprintf('Output folder: %s\n', cfg.resultsDir);
fprintf('Samples: %d | Comparisons per sample: %d\n\n', numel(audioFiles), numel(cfg.comparisonLabels));

for iFile = 1:numel(audioFiles)
    audioPath = audioFiles(iFile);
    [~, stem, ext] = fileparts(audioPath);
    fileName = stem + ext;
    sampleID = local_sample_id(stem);
    meta = local_parse_sample_name(stem);

    fprintf('[%02d/%02d] %s\n', iFile, numel(audioFiles), fileName);

    if ~isfile(audioPath)
        failureRows(end+1,:) = {sampleID, string(audioPath), "all", "file_not_found", ""}; %#ok<SAGROW>
        fprintf('  skipped: file not found\n');
        continue;
    end

    fileInfo = local_audio_file_info(audioPath);

    try
        S = local_call_name_value(@vib_analyze_harmonics_analysis_V27, audioPath, analysisOpts);
        sourceDur = numel(S.x) / S.fs;
        numValidHarm = local_count_valid_harmonics(S, cfg);
    catch ME
        failureRows(end+1,:) = {sampleID, string(audioPath), "analysis", "analysis_failed", string(ME.message)}; %#ok<SAGROW>
        warning('Analysis failed for %s: %s', fileName, ME.message);
        local_write_error_log(fullfile(matDir, sampleID + "_analysis_error.txt"), ME);
        continue;
    end

    for iVar = 1:numel(cfg.comparisonLabels)
        variant = cfg.comparisonLabels(iVar);
        fprintf('    comparison: original vs %s\n', variant);
        try
            paramsVariant = local_make_variant_params(S.params, variant);
            [ySynth, synthData] = local_call_name_value_two(@vib_analyze_harmonics_resynthesize_V27, paramsVariant, synthOpts);

            audioMetrics = local_compute_audio_objective_metrics(S, ySynth, synthData.fs, cfg);
            harmErr = local_compute_harmonic_errors(S, synthData);
            audioMetrics.meanAmpRelRmse = local_nanmean(harmErr.ampRelRmse);
            audioMetrics.meanFmRmseHz = local_nanmean(harmErr.fmRmseHz);

            metricOpts = metricOptsBase;
            metricOpts.params = paramsVariant;
            metricOpts.synthData = synthData;
            metricOpts.currentLabel = char(variant);
            M = vib_analyze_harmonics_metrics_V5_patched(S, metricOpts);
            paper = local_extract_paper_metrics(M);
            storage = local_extract_storage_metrics(M, paramsVariant, S.x, cfg);
            bitrate = local_compute_bitrate_metrics(storage, sourceDur, S.fs, fileInfo, cfg);

            numAM = local_count_stored_modulated_harmonics(paramsVariant, 'amModel');
            numFM = local_count_stored_modulated_harmonics(paramsVariant, 'fmModel');

            objectiveRows(end+1,:) = { ... %#ok<SAGROW>
                sampleID, string(fileName), string(meta.instrument), string(meta.note), string(meta.durationToken), ...
                string(meta.dynamic), string(meta.articulation), string(meta.family), string(variant), ...
                sourceDur, S.f0Hz, numValidHarm, audioMetrics.waveformNrmse, audioMetrics.waveformCorr, ...
                audioMetrics.envelopeCorr, audioMetrics.logSpectralDistanceDb, audioMetrics.centroidMeanAbsErrorHz, ...
                audioMetrics.spectralConvergence, audioMetrics.meanAmpRelRmse, audioMetrics.meanFmRmseHz, ...
                paper.primaryMetricName, paper.harmonicRelative, paper.melRelativeSimple, paper.melRmsRelative, ...
                paper.melDecibel, paper.mfccError};

            storageRows(end+1,:) = { ... %#ok<SAGROW>
                sampleID, string(fileName), string(meta.instrument), string(meta.note), string(meta.articulation), ...
                string(meta.family), string(variant), sourceDur, S.f0Hz, numValidHarm, numAM, numFM, ...
                storage.parameterScalars, storage.parameterBytes, storage.parameterKiB, storage.rawAudioSamples, ...
                storage.rawAudioBytes, storage.rawAudioKiB, storage.parameterVsRawPct, storage.rawToParameterRatio, ...
                storage.analysisTraceValues, storage.analysisTraceBytes, storage.analysisTraceKiB, ...
                storage.parameterVsAnalysisPct, storage.analysisToParameterRatio, ...
                bitrate.parameterBitrateKbps, bitrate.inputFileBitrateKbps, bitrate.inputFileBytes, string(bitrate.inputFileExtension), ...
                bitrate.wavPcmBitrateKbps, bitrate.wavPcmBytesEquivalent, bitrate.inputFileToParameterBitrateRatio, ...
                bitrate.wavToParameterBitrateRatio, bitrate.parameterPctOfInputFileBitrate, bitrate.parameterPctOfWavPcmBitrate};

            combinedRows(end+1,:) = { ... %#ok<SAGROW>
                sampleID, string(fileName), string(meta.instrument), string(meta.note), string(meta.articulation), ...
                string(meta.family), string(variant), sourceDur, S.f0Hz, numValidHarm, numAM, numFM, ...
                audioMetrics.waveformNrmse, audioMetrics.envelopeCorr, audioMetrics.logSpectralDistanceDb, ...
                audioMetrics.centroidMeanAbsErrorHz, paper.harmonicRelative, paper.melRmsRelative, ...
                paper.melDecibel, paper.mfccError, audioMetrics.meanAmpRelRmse, audioMetrics.meanFmRmseHz, ...
                storage.parameterScalars, storage.parameterKiB, storage.parameterVsRawPct, storage.rawToParameterRatio, ...
                storage.parameterVsAnalysisPct, storage.analysisToParameterRatio, ...
                bitrate.parameterBitrateKbps, bitrate.inputFileBitrateKbps, bitrate.inputFileBytes, string(bitrate.inputFileExtension), ...
                bitrate.wavPcmBitrateKbps, bitrate.wavPcmBytesEquivalent, bitrate.inputFileToParameterBitrateRatio, ...
                bitrate.wavToParameterBitrateRatio, bitrate.parameterPctOfInputFileBitrate, bitrate.parameterPctOfWavPcmBitrate};

            bitrateRows(end+1,:) = { ... %#ok<SAGROW>
                sampleID, string(fileName), string(meta.instrument), string(meta.note), string(meta.articulation), ...
                string(meta.family), string(variant), sourceDur, S.f0Hz, storage.parameterScalars, storage.parameterBytes, ...
                bitrate.parameterBitrateKbps, bitrate.inputFileBitrateKbps, bitrate.inputFileBytes, string(bitrate.inputFileExtension), ...
                bitrate.wavPcmBitrateKbps, bitrate.wavPcmBytesEquivalent, bitrate.parameterPctOfInputFileBitrate, ...
                bitrate.inputFileToParameterBitrateRatio, bitrate.parameterPctOfWavPcmBitrate, bitrate.wavToParameterBitrateRatio};

            for h = 1:height(harmErr)
                harmRows(end+1,:) = { ... %#ok<SAGROW>
                    sampleID, string(meta.instrument), string(meta.note), string(meta.articulation), string(meta.family), ...
                    string(variant), harmErr.harmonic(h), harmErr.ampRelRmse(h), harmErr.fmRmseHz(h), ...
                    harmErr.vibRateHz(h), harmErr.amDepthPct(h), harmErr.fmDepthHz(h)};
            end

            if cfg.saveResynthAudio
                outWav = fullfile(audioDir, sampleID + "_" + variant + ".wav");
                local_write_wav_scaled(outWav, ySynth, synthData.fs);
            end

            if cfg.savePerSampleMat
                save(fullfile(matDir, sampleID + "_" + variant + "_quant.mat"), ...
                    'paramsVariant', 'synthData', 'audioMetrics', 'paper', 'storage', 'harmErr', '-v7.3');
            end

            fprintf('      NRMSE %.3f | LSD %.2f dB | MFCC %.2f | %.3f KiB | %.2f kbps | %.1f:1 WAV/model\n', ...
                audioMetrics.waveformNrmse, audioMetrics.logSpectralDistanceDb, paper.mfccError, ...
                storage.parameterKiB, bitrate.parameterBitrateKbps, bitrate.wavToParameterBitrateRatio);

        catch ME
            failureRows(end+1,:) = {sampleID, string(audioPath), string(variant), "comparison_failed", string(ME.message)}; %#ok<SAGROW>
            warning('Comparison %s failed for %s: %s', variant, fileName, ME.message);
            local_write_error_log(fullfile(matDir, sampleID + "_" + variant + "_error.txt"), ME);
        end
    end
end

%% ---------------- Write output tables ----------------
objectiveNames = {'sampleID','fileName','instrument','note','durationToken','dynamic','articulation','family','comparisonLabel', ...
    'durationSec','estimatedF0Hz','numValidHarmonics','waveformNRMSE','waveformCorrelation','envelopeCorrelation', ...
    'logSpectralDistanceDb','centroidMeanAbsErrorHz','spectralConvergence','meanAmpRelRMSE','meanFmRMSEHz', ...
    'primaryPaperMetric','harmonicRelativeError','melRelativeSimpleError','melRmsRelativeError','melDecibelError','mfccError'};

storageNames = {'sampleID','fileName','instrument','note','articulation','family','comparisonLabel','durationSec','estimatedF0Hz', ...
    'numValidHarmonics','numAMHarmonicsStored','numFMHarmonicsStored','parameterScalars','parameterBytes','parameterKiB', ...
    'rawAudioSamples','rawAudioBytes','rawAudioKiB','parameterPctOfRaw','rawToParameterRatio', ...
    'analysisTraceValues','analysisTraceBytes','analysisTraceKiB','parameterPctOfAnalysisTraces','analysisToParameterRatio', ...
    'parameterBitrateKbps','inputFileBitrateKbps','inputFileBytes','inputFileExtension','wavPcmBitrateKbps', ...
    'wavPcmBytesEquivalent','inputFileToParameterBitrateRatio','wavToParameterBitrateRatio', ...
    'parameterPctOfInputFileBitrate','parameterPctOfWavPcmBitrate'};

combinedNames = {'sampleID','fileName','instrument','note','articulation','family','comparisonLabel','durationSec','estimatedF0Hz', ...
    'numValidHarmonics','numAMHarmonicsStored','numFMHarmonicsStored','waveformNRMSE','envelopeCorrelation', ...
    'logSpectralDistanceDb','centroidMeanAbsErrorHz','harmonicRelativeError','melRmsRelativeError','melDecibelError','mfccError', ...
    'meanAmpRelRMSE','meanFmRMSEHz','parameterScalars','parameterKiB','parameterPctOfRaw','rawToParameterRatio', ...
    'parameterPctOfAnalysisTraces','analysisToParameterRatio', ...
    'parameterBitrateKbps','inputFileBitrateKbps','inputFileBytes','inputFileExtension','wavPcmBitrateKbps', ...
    'wavPcmBytesEquivalent','inputFileToParameterBitrateRatio','wavToParameterBitrateRatio', ...
    'parameterPctOfInputFileBitrate','parameterPctOfWavPcmBitrate'};

harmonicNames = {'sampleID','instrument','note','articulation','family','comparisonLabel','harmonic','ampRelRMSE','fmRMSEHz', ...
    'vibratoRateHz','amDepthPct','fmDepthHz'};

bitrateNames = {'sampleID','fileName','instrument','note','articulation','family','comparisonLabel','durationSec','estimatedF0Hz', ...
    'parameterScalars','parameterBytes','parameterBitrateKbps','inputFileBitrateKbps','inputFileBytes','inputFileExtension', ...
    'wavPcmBitrateKbps','wavPcmBytesEquivalent','parameterPctOfInputFileBitrate','inputFileToParameterBitrateRatio', ...
    'parameterPctOfWavPcmBitrate','wavToParameterBitrateRatio'};

failureNames = {'sampleID','audioPath','comparisonLabel','status','message'};

objectiveTable = local_cell2table(objectiveRows, objectiveNames);
storageTable = local_cell2table(storageRows, storageNames);
combinedTable = local_cell2table(combinedRows, combinedNames);
harmonicErrorTable = local_cell2table(harmRows, harmonicNames);
bitrateTable = local_cell2table(bitrateRows, bitrateNames);
bitrateSummaryTable = local_bitrate_summary_table(bitrateTable);
literatureBitrateTemplate = local_literature_bitrate_template();
failureTable = local_cell2table(failureRows, failureNames);
summaryTable = local_summary_by_family_variant(combinedTable);
modelSummaryTable = local_summary_by_model_variant(combinedTable);

writetable(objectiveTable, fullfile(tableDir, 'objective_metric_table.csv'));
writetable(storageTable, fullfile(tableDir, 'parameter_reduction_table.csv'));
writetable(combinedTable, fullfile(tableDir, 'combined_quantitative_table.csv'));
writetable(bitrateTable, fullfile(tableDir, 'bitrate_comparison_table.csv'));
writetable(bitrateSummaryTable, fullfile(tableDir, 'bitrate_summary_table.csv'));
writetable(literatureBitrateTemplate, fullfile(tableDir, 'literature_bitrate_template.csv'));
writetable(harmonicErrorTable, fullfile(tableDir, 'harmonic_error_table.csv'));
writetable(summaryTable, fullfile(tableDir, 'summary_by_family.csv'));
writetable(modelSummaryTable, fullfile(tableDir, 'summary_by_model.csv'));
writetable(failureTable, fullfile(tableDir, 'failure_table.csv'));
save(fullfile(cfg.resultsDir, 'objective_parameter_batch_summary.mat'), ...
    'cfg', 'objectiveTable', 'storageTable', 'combinedTable', 'bitrateTable', 'bitrateSummaryTable', ...
    'literatureBitrateTemplate', 'harmonicErrorTable', 'summaryTable', 'modelSummaryTable', 'failureTable');

local_write_readme(cfg.resultsDir);

fprintf('\nDone. Tables written to:\n  %s\n', tableDir);
fprintf('Main table for thesis:\n  %s\n', fullfile(tableDir, 'combined_quantitative_table.csv'));

%% ================= Local functions =================

function local_require_function(functionName)
    if exist(functionName, 'file') ~= 2
        error('Required function is not on the MATLAB path: %s.m', functionName);
    end
end

function out = local_call_name_value(funHandle, firstArg, optsStruct)
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


function info = local_audio_file_info(audioPath)
    info = struct();
    d = dir(audioPath);
    [~,~,ext] = fileparts(audioPath);
    info.bytes = NaN;
    info.extension = string(lower(ext));
    info.durationSec = NaN;
    info.sampleRate = NaN;
    info.numChannels = NaN;
    if ~isempty(d)
        info.bytes = double(d.bytes);
    end
    try
        A = audioinfo(audioPath);
        if isfield(A, 'Duration') && isfinite(A.Duration)
            info.durationSec = double(A.Duration);
        end
        if isfield(A, 'SampleRate') && isfinite(A.SampleRate)
            info.sampleRate = double(A.SampleRate);
        end
        if isfield(A, 'NumChannels') && isfinite(A.NumChannels)
            info.numChannels = double(A.NumChannels);
        end
    catch
        % audioinfo is used only for reference-file metadata. The analysis
        % stage still reads the file and determines the actual source length.
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

function paramsOut = local_make_variant_params(paramsIn, comparisonLabel)
    paramsOut = paramsIn;
    label = lower(string(comparisonLabel));

    switch label
        case {"full", "compactv27", "fullmodel"}
            % Full compact V27 model: envelope + AM + FM.
            return;

        case {"noam", "envelopefm", "envelope+fm"}
            % Envelope + FM only.
            paramsOut = local_remove_harm_field(paramsOut, 'amModel');

        case {"nofm", "envelopeam", "envelope+am"}
            % Envelope + AM only.
            paramsOut = local_remove_harm_field(paramsOut, 'fmModel');

        case {"envelopeonly", "novibrato"}
            % Compact harmonic envelopes only.
            paramsOut = local_remove_harm_field(paramsOut, 'amModel');
            paramsOut = local_remove_harm_field(paramsOut, 'fmModel');
            paramsOut = local_remove_harm_field(paramsOut, 'vibrato');

        case {"staticharmonic", "static", "staticadditive"}
            % Fixed harmonic amplitudes + fixed harmonic frequencies.
            paramsOut = local_make_static_harmonic_params(paramsOut);

        otherwise
            error('Unknown model variant: %s', comparisonLabel);
    end
end

function paramsOut = local_make_static_harmonic_params(paramsIn)
    paramsOut = paramsIn;
    paramsOut = local_remove_harm_field(paramsOut, 'amModel');
    paramsOut = local_remove_harm_field(paramsOut, 'fmModel');
    paramsOut = local_remove_harm_field(paramsOut, 'vibrato');

    sourceDur = local_get_source_duration_from_params(paramsOut);
    if ~isfield(paramsOut, 'harm') || isempty(paramsOut.harm)
        return;
    end

    for ih = 1:numel(paramsOut.harm)
        hk = paramsOut.harm(ih);
        staticAmp = local_static_amp_from_env_model(hk);
        if ~isfinite(staticAmp) || staticAmp < 0
            staticAmp = 0;
        end

        envModel = struct();
        envModel.type = 'staticHarmonic';
        envModel.baseline = 0;
        envModel.attackShapeOrder = 1;
        envModel.segments = struct();
        envModel.segments.body = struct( ...
            'tStart', 0, ...
            'tEnd', sourceDur, ...
            'model', 'pchip', ...
            'knotTimes', [0; sourceDur], ...
            'knotValues', [staticAmp; staticAmp]);

        paramsOut.harm(ih).envModel = envModel;
    end
end

function sourceDur = local_get_source_duration_from_params(params)
    sourceDur = local_get_scalar(params, 'sourceDurationSec', NaN);
    if ~isfinite(sourceDur) || sourceDur <= 0
        sourceDur = local_get_scalar(params, 'durationSec', NaN);
    end
    if (~isfinite(sourceDur) || sourceDur <= 0) && ...
            isfield(params, 'sourceNumSamples') && isfield(params, 'sourceFs') && ...
            isfinite(params.sourceNumSamples) && isfinite(params.sourceFs) && params.sourceFs > 0
        sourceDur = double(params.sourceNumSamples) / double(params.sourceFs);
    end
    if ~isfinite(sourceDur) || sourceDur <= 0
        sourceDur = 1;
    end
end

function staticAmp = local_static_amp_from_env_model(hk)
    staticAmp = NaN;
    vals = [];

    if isfield(hk, 'envModel') && isstruct(hk.envModel) && ...
            isfield(hk.envModel, 'segments') && isstruct(hk.envModel.segments)
        segNames = fieldnames(hk.envModel.segments);
        for iseg = 1:numel(segNames)
            seg = hk.envModel.segments.(segNames{iseg});
            if isstruct(seg) && isfield(seg, 'knotValues')
                vals = [vals; double(seg.knotValues(:))]; %#ok<AGROW>
            end
        end
    end

    vals = vals(isfinite(vals) & vals > 0);
    if ~isempty(vals)
        % Median avoids the attack/release endpoints dominating the static baseline.
        staticAmp = median(vals);
        return;
    end

    % Backward-compatible fallbacks if the parameter struct changes.
    staticAmp = local_get_scalar(hk, 'ampMean', NaN);
    if ~isfinite(staticAmp)
        staticAmp = local_get_scalar(hk, 'amp', NaN);
    end
end

function paramsOut = local_remove_harm_field(paramsIn, fieldName)
    paramsOut = paramsIn;
    if isfield(paramsOut, 'harm') && isstruct(paramsOut.harm) && isfield(paramsOut.harm, fieldName)
        paramsOut.harm = rmfield(paramsOut.harm, fieldName);
    end
end

function metrics = local_compute_audio_objective_metrics(S, ySynth, fsSynth, cfg)
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
    yScaled = local_match_gain(x, y);

    metrics = struct();
    metrics.waveformNrmse = local_rms(x - yScaled) / max(local_rms(x), eps);
    metrics.waveformCorr = local_corr(x, yScaled);

    envWin = max(8, round(0.010 * fs));
    ex = movmean(abs(x), envWin);
    ey = movmean(abs(yScaled), envWin);
    metrics.envelopeCorr = local_corr(ex, ey);

    [lsdDb, centErrHz, specConv] = local_spectral_metrics(x, yScaled, fs, cfg);
    metrics.logSpectralDistanceDb = lsdDb;
    metrics.centroidMeanAbsErrorHz = centErrHz;
    metrics.spectralConvergence = specConv;
    metrics.meanAmpRelRmse = NaN;
    metrics.meanFmRmseHz = NaN;
end

function harmErr = local_compute_harmonic_errors(S, synthData)
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

    ampScale = 2;
    if isfield(S, 'params') && isfield(S.params, 'analyticAmpScale') && isfinite(S.params.analyticAmpScale)
        ampScale = S.params.analyticAmpScale;
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
                A_rec_scaled = local_match_gain(A_meas(valid), A_rec(valid));
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

function P = local_extract_paper_metrics(M)
    P = struct();
    P.primaryMetricName = "";
    P.harmonicRelative = NaN;
    P.melRelativeSimple = NaN;
    P.melRmsRelative = NaN;
    P.melDecibel = NaN;
    P.mfccError = NaN;
    if ~isfield(M, 'paper') || ~isstruct(M.paper)
        return;
    end
    if isfield(M.paper, 'primaryName')
        P.primaryMetricName = string(M.paper.primaryName);
    end
    if isfield(M.paper, 'primary') && isstruct(M.paper.primary) && isfield(M.paper.primary, 'available') && M.paper.primary.available
        Q = M.paper.primary;
    else
        Q = [];
    end
    if isempty(Q)
        return;
    end
    P.harmonicRelative = local_get_scalar(Q, 'harmonicRelative', NaN);
    P.melRelativeSimple = local_get_scalar(Q, 'melRelativeSimple', NaN);
    P.melRmsRelative = local_get_scalar(Q, 'melRmsRelative', NaN);
    P.melDecibel = local_get_scalar(Q, 'melDecibel', NaN);
    P.mfccError = local_get_scalar(Q, 'mfccError', NaN);
end

function G = local_extract_storage_metrics(M, params, x, cfg)
    G = struct();
    G.parameterScalars = NaN;
    G.parameterBytes = NaN;
    G.parameterKiB = NaN;
    G.rawAudioSamples = numel(x);
    G.rawAudioBytes = cfg.audioBytesPerSample * numel(x);
    G.rawAudioKiB = G.rawAudioBytes / 1024;
    G.analysisTraceValues = NaN;
    G.analysisTraceBytes = NaN;
    G.analysisTraceKiB = NaN;
    G.parameterVsRawPct = NaN;
    G.rawToParameterRatio = NaN;
    G.parameterVsAnalysisPct = NaN;
    G.analysisToParameterRatio = NaN;

    if isfield(M, 'storage') && isstruct(M.storage) && isfield(M.storage, 'available') && M.storage.available
        S = M.storage;
        G.parameterScalars = local_get_scalar(S, 'parameterScalars', NaN);
        G.parameterBytes = local_get_scalar(S, 'parameterBytes', NaN);
        G.parameterKiB = local_get_scalar(S, 'parameterKiB', NaN);
        G.rawAudioSamples = local_get_scalar(S, 'rawAudioSamples', G.rawAudioSamples);
        G.rawAudioBytes = local_get_scalar(S, 'rawAudioBytes', G.rawAudioBytes);
        G.rawAudioKiB = local_get_scalar(S, 'rawAudioKiB', G.rawAudioKiB);
        G.analysisTraceValues = local_get_scalar(S, 'analysisTraceValues', NaN);
        G.analysisTraceBytes = local_get_scalar(S, 'analysisTraceBytes', NaN);
        G.analysisTraceKiB = local_get_scalar(S, 'analysisTraceKiB', NaN);
        G.parameterVsRawPct = local_get_scalar(S, 'parameterVsRawPct', NaN);
        G.rawToParameterRatio = local_get_scalar(S, 'rawToParameterRatio', NaN);
        G.parameterVsAnalysisPct = local_get_scalar(S, 'parameterVsAnalysisPct', NaN);
        G.analysisToParameterRatio = local_get_scalar(S, 'analysisToParameterRatio', NaN);
        return;
    end

    % Fallback if the V5 storage section is unavailable.
    G.parameterScalars = local_count_scalars(params);
    G.parameterBytes = cfg.parameterBytesPerScalar * G.parameterScalars;
    G.parameterKiB = G.parameterBytes / 1024;
    G.parameterVsRawPct = 100 * G.parameterBytes / max(G.rawAudioBytes, eps);
    G.rawToParameterRatio = G.rawAudioBytes / max(G.parameterBytes, eps);
end


function B = local_compute_bitrate_metrics(storage, durationSec, fs, fileInfo, cfg)
    B = struct();
    B.parameterBitrateKbps = NaN;
    B.inputFileBitrateKbps = NaN;
    B.inputFileBytes = NaN;
    B.inputFileExtension = "";
    B.wavPcmBitrateKbps = NaN;
    B.wavPcmBytesEquivalent = NaN;
    B.parameterPctOfInputFileBitrate = NaN;
    B.inputFileToParameterBitrateRatio = NaN;
    B.parameterPctOfWavPcmBitrate = NaN;
    B.wavToParameterBitrateRatio = NaN;

    dur = durationSec;
    if (~isfinite(dur) || dur <= 0) && isfield(fileInfo, 'durationSec')
        dur = fileInfo.durationSec;
    end

    if isfinite(storage.parameterBytes) && isfinite(dur) && dur > 0
        B.parameterBitrateKbps = (8 * storage.parameterBytes) / dur / 1000;
    end

    if isfield(fileInfo, 'bytes')
        B.inputFileBytes = fileInfo.bytes;
    end
    if isfield(fileInfo, 'extension')
        B.inputFileExtension = fileInfo.extension;
    end
    if isfinite(B.inputFileBytes) && isfinite(dur) && dur > 0
        B.inputFileBitrateKbps = (8 * B.inputFileBytes) / dur / 1000;
    end

    if isfinite(fs) && fs > 0
        B.wavPcmBitrateKbps = (fs * cfg.wavBitsPerSample * cfg.wavNumChannels) / 1000;
    end
    if isfinite(B.wavPcmBitrateKbps) && isfinite(dur) && dur > 0
        B.wavPcmBytesEquivalent = (B.wavPcmBitrateKbps * 1000 / 8) * dur;
    end

    B.parameterPctOfInputFileBitrate = local_safe_pct(B.parameterBitrateKbps, B.inputFileBitrateKbps);
    B.inputFileToParameterBitrateRatio = local_safe_ratio(B.inputFileBitrateKbps, B.parameterBitrateKbps);
    B.parameterPctOfWavPcmBitrate = local_safe_pct(B.parameterBitrateKbps, B.wavPcmBitrateKbps);
    B.wavToParameterBitrateRatio = local_safe_ratio(B.wavPcmBitrateKbps, B.parameterBitrateKbps);
end

function pct = local_safe_pct(num, den)
    if isfinite(num) && isfinite(den) && den > 0
        pct = 100 * num / den;
    else
        pct = NaN;
    end
end

function r = local_safe_ratio(num, den)
    if isfinite(num) && isfinite(den) && den > 0
        r = num / den;
    else
        r = NaN;
    end
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

function n = local_count_stored_modulated_harmonics(params, modelField)
    n = 0;
    if ~isfield(params, 'harm') || ~isfield(params.harm, modelField)
        return;
    end
    for k = 1:numel(params.harm)
        m = params.harm(k).(modelField);
        if isstruct(m) && isfield(m, 'amp') && isfinite(m.amp) && abs(m.amp) > 0
            n = n + 1;
        end
    end
end

function yScaled = local_match_gain(x, y)
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
    xv = x(valid) - mean(x(valid));
    yv = y(valid) - mean(y(valid));
    den = sqrt(sum(xv.^2) * sum(yv.^2));
    if den <= 0
        c = NaN;
    else
        c = sum(xv.*yv) / den;
    end
end

function [lsdDb, centroidErrHz, specConv] = local_spectral_metrics(x, y, fs, cfg)
    [Xdb, f, Xmag] = local_stft_db_and_mag(x, fs, cfg);
    [Ydb, ~, Ymag] = local_stft_db_and_mag(y, fs, cfg);
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

    specConv = norm(Xmag(band,:) - Ymag(band,:), 'fro') / max(norm(Xmag(band,:), 'fro'), eps);
end

function [db, ff, mag] = local_stft_db_and_mag(x, fs, cfg)
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
    for m = 1:numFrames
        idx = (1:winN) + (m-1)*hopN;
        frame = x(idx) .* w;
        X = fft(frame, nfft);
        mag(:,m) = abs(X(1:numBins));
    end
    ff = (0:numBins-1).' * fs/nfft;
    db = 20*log10(mag + 10^(cfg.logSpecFloorDb/20));
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

function val = local_get_scalar(s, fieldName, defaultVal)
    val = defaultVal;
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName)) && isnumeric(s.(fieldName)) && isscalar(s.(fieldName))
        if isfinite(s.(fieldName))
            val = double(s.(fieldName));
        end
    end
end

function m = local_nanmean(x)
    x = x(:);
    x = x(isfinite(x));
    if isempty(x)
        m = NaN;
    else
        m = mean(x);
    end
end

function T = local_cell2table(rows, names)
    if isempty(rows)
        T = cell2table(cell(0, numel(names)), 'VariableNames', names);
    else
        T = cell2table(rows, 'VariableNames', names);
    end
end

function summaryTable = local_summary_by_family_variant(T)
    names = {'family','comparisonLabel','numSamples','meanWaveformNRMSE','meanEnvelopeCorrelation', ...
        'meanLogSpectralDistanceDb','meanHarmonicRelativeError','meanMelRmsRelativeError','meanMFCCError', ...
        'meanParameterKiB','meanParameterPctOfRaw','meanRawToParameterRatio', ...
        'meanParameterPctOfAnalysisTraces','meanAnalysisToParameterRatio', ...
        'meanParameterBitrateKbps','meanInputFileBitrateKbps','meanWavPcmBitrateKbps', ...
        'meanInputFileToParameterBitrateRatio','meanWavToParameterBitrateRatio'};
    if isempty(T) || height(T) == 0
        summaryTable = cell2table(cell(0,numel(names)), 'VariableNames', names);
        return;
    end
    fam = string(T.family);
    var = string(T.comparisonLabel);
    keys = unique(strcat(fam, "|||", var), 'stable');
    rows = cell(numel(keys), numel(names));
    for i = 1:numel(keys)
        parts = split(keys(i), "|||");
        f = parts(1);
        v = parts(2);
        mask = fam == f & var == v;
        rows(i,:) = {f, v, nnz(mask), ...
            local_nanmean(T.waveformNRMSE(mask)), local_nanmean(T.envelopeCorrelation(mask)), ...
            local_nanmean(T.logSpectralDistanceDb(mask)), local_nanmean(T.harmonicRelativeError(mask)), ...
            local_nanmean(T.melRmsRelativeError(mask)), local_nanmean(T.mfccError(mask)), ...
            local_nanmean(T.parameterKiB(mask)), local_nanmean(T.parameterPctOfRaw(mask)), ...
            local_nanmean(T.rawToParameterRatio(mask)), local_nanmean(T.parameterPctOfAnalysisTraces(mask)), ...
            local_nanmean(T.analysisToParameterRatio(mask)), ...
            local_nanmean(T.parameterBitrateKbps(mask)), local_nanmean(T.inputFileBitrateKbps(mask)), ...
            local_nanmean(T.wavPcmBitrateKbps(mask)), local_nanmean(T.inputFileToParameterBitrateRatio(mask)), ...
            local_nanmean(T.wavToParameterBitrateRatio(mask))};
    end
    summaryTable = cell2table(rows, 'VariableNames', names);
end



function summaryTable = local_summary_by_model_variant(T)
    names = {'comparisonLabel','numSamples','meanWaveformNRMSE','meanEnvelopeCorrelation', ...
        'meanLogSpectralDistanceDb','meanHarmonicRelativeError','meanMelRmsRelativeError','meanMFCCError', ...
        'meanParameterKiB','meanParameterBitrateKbps','meanParameterPctOfRaw','meanRawToParameterRatio', ...
        'meanInputFileToParameterBitrateRatio','meanWavToParameterBitrateRatio'};
    if isempty(T) || height(T) == 0
        summaryTable = cell2table(cell(0,numel(names)), 'VariableNames', names);
        return;
    end
    var = string(T.comparisonLabel);
    keys = unique(var, 'stable');
    rows = cell(numel(keys), numel(names));
    for i = 1:numel(keys)
        v = keys(i);
        mask = var == v;
        rows(i,:) = {v, nnz(mask), ...
            local_nanmean(T.waveformNRMSE(mask)), local_nanmean(T.envelopeCorrelation(mask)), ...
            local_nanmean(T.logSpectralDistanceDb(mask)), local_nanmean(T.harmonicRelativeError(mask)), ...
            local_nanmean(T.melRmsRelativeError(mask)), local_nanmean(T.mfccError(mask)), ...
            local_nanmean(T.parameterKiB(mask)), local_nanmean(T.parameterBitrateKbps(mask)), ...
            local_nanmean(T.parameterPctOfRaw(mask)), local_nanmean(T.rawToParameterRatio(mask)), ...
            local_nanmean(T.inputFileToParameterBitrateRatio(mask)), local_nanmean(T.wavToParameterBitrateRatio(mask))};
    end
    summaryTable = cell2table(rows, 'VariableNames', names);
end

function T = local_bitrate_summary_table(B)
    names = {'sourceType','meanBitrateKbps','medianBitrateKbps','minBitrateKbps','maxBitrateKbps','notes'};
    if isempty(B) || height(B) == 0
        T = cell2table(cell(0,numel(names)), 'VariableNames', names);
        return;
    end

    rows = {
        "compact V27 parameter model", local_nanmean(B.parameterBitrateKbps), local_nanmedian(B.parameterBitrateKbps), ...
            local_nanmin(B.parameterBitrateKbps), local_nanmax(B.parameterBitrateKbps), ...
            "parameter bytes times 8 divided by tone duration";
        "input compressed audio file", local_nanmean(B.inputFileBitrateKbps), local_nanmedian(B.inputFileBitrateKbps), ...
            local_nanmin(B.inputFileBitrateKbps), local_nanmax(B.inputFileBitrateKbps), ...
            "actual input file size times 8 divided by tone duration; usually MP3 for this dataset";
        "16-bit mono WAV PCM equivalent", local_nanmean(B.wavPcmBitrateKbps), local_nanmedian(B.wavPcmBitrateKbps), ...
            local_nanmin(B.wavPcmBitrateKbps), local_nanmax(B.wavPcmBitrateKbps), ...
            "sample rate times 16 bits times one channel";
        "[ADD LITERATURE METHOD 1]", NaN, NaN, NaN, NaN, "fill in from cited literature";
        "[ADD LITERATURE METHOD 2]", NaN, NaN, NaN, NaN, "fill in from cited literature";
        "[ADD LITERATURE METHOD 3]", NaN, NaN, NaN, NaN, "fill in from cited literature"
        };
    T = cell2table(rows, 'VariableNames', names);
end

function T = local_literature_bitrate_template()
    T = table( ...
        ["[ADD LITERATURE METHOD 1]"; "[ADD LITERATURE METHOD 2]"; "[ADD LITERATURE METHOD 3]"], ...
        ["[ADD CITATION]"; "[ADD CITATION]"; "[ADD CITATION]"], ...
        [NaN; NaN; NaN], ...
        ["[ADD CONDITIONS: mono/stereo, sample rate, parameter precision, model assumptions]"; ...
         "[ADD CONDITIONS: mono/stereo, sample rate, parameter precision, model assumptions]"; ...
         "[ADD CONDITIONS: mono/stereo, sample rate, parameter precision, model assumptions]"], ...
        'VariableNames', {'method','source','bitrateKbps','notes'});
end

function m = local_nanmedian(x)
    x = x(:);
    x = x(isfinite(x));
    if isempty(x)
        m = NaN;
    else
        m = median(x);
    end
end

function m = local_nanmin(x)
    x = x(:);
    x = x(isfinite(x));
    if isempty(x)
        m = NaN;
    else
        m = min(x);
    end
end

function m = local_nanmax(x)
    x = x(:);
    x = x(isfinite(x));
    if isempty(x)
        m = NaN;
    else
        m = max(x);
    end
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
        "10-sample objective + parameter model-comparison results output" + newline + newline + ...
        "tables/combined_quantitative_table.csv: main thesis table with objective metrics and storage ratios." + newline + ...
        "tables/objective_metric_table.csv: waveform, envelope, spectral, harmonic, mel, and MFCC metrics." + newline + ...
        "tables/parameter_reduction_table.csv: compact parameter counts and storage ratios." + newline + ...
        "tables/bitrate_comparison_table.csv: per-sample model, input-file, and WAV-equivalent bit rates." + newline + ...
        "tables/bitrate_summary_table.csv: average bit-rate comparison, including blank literature rows to fill in." + newline + ...
        "tables/literature_bitrate_template.csv: blank template for literature bit-rate comparisons." + newline + ...
        "tables/harmonic_error_table.csv: per-harmonic AM and FM reconstruction errors." + newline + ...
        "tables/summary_by_family.csv: family-level averages for each compact-model variant." + newline + ...
        "tables/summary_by_model.csv: overall averages for each model variant, useful for the objective-metrics slide." + newline + ...
        "tables/failure_table.csv: missing files or failed analysis/resynthesis runs." + newline + newline + ...
        "Suggested thesis use: report one compact table from combined_quantitative_table.csv, " + ...
        "then summarize model tradeoffs using summary_by_model.csv, summary_by_family.csv, and bitrate_summary_table.csv." + newline];
    fid = fopen(fullfile(resultsDir, 'README_objective_parameter_results.txt'), 'w');
    if fid >= 0
        fprintf(fid, '%s', txt);
        fclose(fid);
    end
end
