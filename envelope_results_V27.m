%% envelope_results_V27.m
% Batch test script for the thesis section:
%   \section{Envelope Results}
%
% This script runs the V27 analysis stage and evaluates how well the
% compact knot-based envelope model represents the measured slowly varying
% harmonic amplitude envelope.
%
% Outputs:
%   envelope_results_V27/tables/envelope_fit_by_harmonic.csv
%   envelope_results_V27/tables/envelope_summary_by_sample.csv
%   envelope_results_V27/tables/envelope_summary_by_family.csv
%   envelope_results_V27/tables/envelope_failure_cases.csv
%   envelope_results_V27/tables/representative_envelope_summary.csv
%   envelope_results_V27/tables/failure_table.csv
%   envelope_results_V27/tables/latex_table_snippets.tex
%   envelope_results_V27/figures/envelope_grid/*.png
%   envelope_results_V27/figures/low_mid_high/*.png
%   envelope_results_V27/figures/error_by_harmonic/*.png
%   envelope_results_V27/figures/failure_cases/*.png
%
% Required on MATLAB path:
%   vib_analyze_harmonics_analysis_V27.m
%
% use:
%   Put this script in the same folder as additive_synth_analysis_V27.m,
%   update cfg.resultsDir if desired, and run this file.

clear; close all; clc;

%% ---------------- User settings ----------------
cfg = struct();
cfg.resultsDir = fullfile(pwd, 'envelope_results_V27');
cfg.numHarmonics = 15;

% Plot controls. Keep false to make thesis figures only for representative
% samples. Set true if you want figures for every file.
cfg.makePlotsForAll = false;
cfg.representativeContains = [ ...
    "violin_A4_1_fortissimo", ...
    "trombone_As3_15", ...
    "banjo_A4_very-long", ...
    "bass-clarinet_B3_05", ...
    "guitar_C3_very-long", ...
    "trumpet_A4_15" ...
];

% Error and plotting settings.
cfg.validEnvelopeMinFrac = 0.005;     % ignore near-zero tail samples in fit metrics
cfg.weakHarmonicRelPeak = 0.05;       % weak if max harmonic envelope is <5% of strongest harmonic peak
cfg.failureRelRmseThreshold = 0.35;   % plot obvious failures above this error
cfg.maxFailurePlotsPerSample = 2;
cfg.imageDpi = 200;
cfg.gridMaxHarmonics = 15;
cfg.plotNormalizePerHarmonic = true;

% Same validated files used in the real-instrument results batch.
audioFiles = [
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
tableDir = fullfile(cfg.resultsDir, 'tables');
gridFigDir = fullfile(cfg.resultsDir, 'figures', 'envelope_grid');
lmhFigDir = fullfile(cfg.resultsDir, 'figures', 'low_mid_high');
errFigDir = fullfile(cfg.resultsDir, 'figures', 'error_by_harmonic');
failFigDir = fullfile(cfg.resultsDir, 'figures', 'failure_cases');
matDir = fullfile(cfg.resultsDir, 'mat');
local_mkdir(cfg.resultsDir);
local_mkdir(tableDir);
local_mkdir(gridFigDir);
local_mkdir(lmhFigDir);
local_mkdir(errFigDir);
local_mkdir(failFigDir);
local_mkdir(matDir);

%% ---------------- V27 analysis options ----------------
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

%% ---------------- Batch run ----------------
envelopeRows = {};
summaryRows = {};
failureRows = {};

fprintf('Envelope V27 batch test starting.\n');
fprintf('Output folder: %s\n\n', cfg.resultsDir);

for iFile = 1:numel(audioFiles)
    audioPath = audioFiles(iFile);
    [~, stem, ext] = fileparts(audioPath);
    fileName = stem + ext;
    sampleID = local_sample_id(stem);
    meta = local_parse_sample_name(stem);
    makePlots = cfg.makePlotsForAll || any(contains(stem, cfg.representativeContains, 'IgnoreCase', true));

    fprintf('[%02d/%02d] %s\n', iFile, numel(audioFiles), fileName);

    if ~isfile(audioPath)
        failureRows(end+1,:) = {sampleID, string(audioPath), "file_not_found", ""}; %#ok<SAGROW>
        fprintf('  skipped: file not found\n');
        continue;
    end

    try
        S = local_call_name_value(@vib_analyze_harmonics_analysis_V27, audioPath, analysisOpts);
        timing = local_get_timing(S);
        sourceDur = numel(S.x) / S.fs;
        t = (0:numel(S.x)-1).' / S.fs;
        K = min(cfg.numHarmonics, numel(S.harm));

        measuredMat = nan(numel(t), K);
        reconMat = nan(numel(t), K);
        errByHarm = nan(K,1);
        corrByHarm = nan(K,1);
        r2ByHarm = nan(K,1);
        harmRelPeak = nan(K,1);
        attackErr = nan(K,1);
        bodyErr = nan(K,1);
        releaseErr = nan(K,1);
        knotCount = nan(K,1);

        strongestPeak = local_max_harmonic_peak(S, K);
        if ~isfinite(strongestPeak) || strongestPeak <= 0
            strongestPeak = 1;
        end

        for k = 1:K
            measured = local_get_harmonic_measured_envelope(S, k, numel(t));
            recon = local_get_compact_reconstructed_envelope(S, k, t, sourceDur);
            measuredMat(:,k) = measured;
            reconMat(:,k) = recon;

            relPeak = max(measured, [], 'omitnan') / max(strongestPeak, eps);
            harmRelPeak(k) = relPeak;
            isWeak = relPeak < cfg.weakHarmonicRelPeak;
            valid = local_env_valid_mask(t, measured, recon, timing, cfg);

            [relRmse, mae, corrVal, r2Val] = local_envelope_metrics(measured, recon, valid);
            errByHarm(k) = relRmse;
            corrByHarm(k) = corrVal;
            r2ByHarm(k) = r2Val;
            attackErr(k) = local_region_rel_rmse(t, measured, recon, timing.tOnset, timing.tAttackEnd, cfg);
            bodyErr(k) = local_region_rel_rmse(t, measured, recon, timing.tAttackEnd, timing.tRelease, cfg);
            releaseErr(k) = local_region_rel_rmse(t, measured, recon, timing.tRelease, timing.tNoteEnd, cfg);
            knotCount(k) = local_count_env_knots(S, k);
            cause = local_failure_cause(meta, k, relRmse, isWeak, attackErr(k), bodyErr(k), releaseErr(k));

            envelopeRows(end+1,:) = { ... %#ok<SAGROW>
                sampleID, string(fileName), string(meta.instrument), string(meta.note), string(meta.durationToken), ...
                string(meta.dynamic), string(meta.articulation), string(meta.family), S.f0Hz, sourceDur, ...
                k, relPeak, isWeak, relRmse, mae, corrVal, r2Val, attackErr(k), bodyErr(k), releaseErr(k), ...
                knotCount(k), timing.tOnset, timing.tAttackEnd, timing.tRelease, timing.tNoteEnd, cause, "ADD MANUAL NOTE"};
        end

        lowMask = (1:K).' <= min(5,K);
        midMask = (1:K).' > min(5,K) & (1:K).' <= min(10,K);
        highMask = (1:K).' > min(10,K);
        summaryRows(end+1,:) = { ... %#ok<SAGROW>
            sampleID, string(fileName), string(meta.instrument), string(meta.note), string(meta.articulation), string(meta.family), ...
            S.f0Hz, sourceDur, K, local_nanmean(errByHarm), local_nanmedian(errByHarm), local_nanmax(errByHarm), ...
            local_nanmean(corrByHarm), local_nanmean(r2ByHarm), local_nanmean(errByHarm(lowMask)), ...
            local_nanmean(errByHarm(midMask)), local_nanmean(errByHarm(highMask)), nnz(harmRelPeak < cfg.weakHarmonicRelPeak), ...
            local_nanmean(attackErr), local_nanmean(bodyErr), local_nanmean(releaseErr), "ADD LISTENING NOTE"};

        if makePlots
            local_plot_envelope_grid(t, measuredMat, reconMat, timing, meta, sampleID, gridFigDir, cfg);
            local_plot_low_mid_high(t, measuredMat, reconMat, timing, meta, sampleID, lmhFigDir, cfg);
            local_plot_error_by_harmonic(errByHarm, corrByHarm, harmRelPeak, meta, sampleID, errFigDir, cfg);
            local_plot_failure_harmonics(t, measuredMat, reconMat, errByHarm, timing, meta, sampleID, failFigDir, cfg);
        end

        save(fullfile(matDir, sampleID + "_envelope_results.mat"), ...
            'S', 'timing', 'meta', 'sampleID', 'measuredMat', 'reconMat', ...
            'errByHarm', 'corrByHarm', 'r2ByHarm', 'harmRelPeak', 'attackErr', 'bodyErr', 'releaseErr');

    catch ME
        failureRows(end+1,:) = {sampleID, string(audioPath), "analysis_failed", string(ME.message)}; %#ok<SAGROW>
        warning('Envelope analysis failed for %s: %s', fileName, ME.message);
    end
end

%% ---------------- Write tables ----------------
envelopeNames = {'sampleID','fileName','instrument','note','durationToken','dynamic','articulation','family', ...
    'f0Hz','durationSec','harmonic','relativePeak','isWeakHarmonic','envRelRMSE','envMAE','envCorr','envR2', ...
    'attackRelRMSE','bodyRelRMSE','releaseRelRMSE','numEnvelopeKnots','tOnsetSec','tAttackEndSec', ...
    'tReleaseSec','tNoteEndSec','likelyFailureCause','manualNotes'};
summaryNames = {'sampleID','fileName','instrument','note','articulation','family','f0Hz','durationSec', ...
    'numHarmonics','meanEnvRelRMSE','medianEnvRelRMSE','maxEnvRelRMSE','meanEnvCorr','meanEnvR2', ...
    'lowHarmMeanRelRMSE','midHarmMeanRelRMSE','highHarmMeanRelRMSE','numWeakHarmonics', ...
    'meanAttackRelRMSE','meanBodyRelRMSE','meanReleaseRelRMSE','listeningNotes'};
failureNames = {'sampleID','audioPath','status','message'};

envelopeTable = local_cell2table(envelopeRows, envelopeNames);
summaryTable = local_cell2table(summaryRows, summaryNames);
failureTable = local_cell2table(failureRows, failureNames);
familySummaryTable = local_summary_by_family(summaryTable);
failureCaseTable = local_failure_case_table(envelopeTable, 30);
representativeSummaryTable = local_representative_rows(summaryTable, cfg.representativeContains);

writetable(envelopeTable, fullfile(tableDir, 'envelope_fit_by_harmonic.csv'));
writetable(summaryTable, fullfile(tableDir, 'envelope_summary_by_sample.csv'));
writetable(familySummaryTable, fullfile(tableDir, 'envelope_summary_by_family.csv'));
writetable(failureCaseTable, fullfile(tableDir, 'envelope_failure_cases.csv'));
writetable(representativeSummaryTable, fullfile(tableDir, 'representative_envelope_summary.csv'));
writetable(failureTable, fullfile(tableDir, 'failure_table.csv'));
local_write_latex_snippets(representativeSummaryTable, failureCaseTable, fullfile(tableDir, 'latex_table_snippets.tex'));

save(fullfile(cfg.resultsDir, 'envelope_batch_summary.mat'), ...
    'cfg', 'envelopeTable', 'summaryTable', 'familySummaryTable', 'failureCaseTable', ...
    'representativeSummaryTable', 'failureTable');

fprintf('\nEnvelope batch complete.\n');
fprintf('Tables:  %s\n', tableDir);
fprintf('Figures: %s\n', fullfile(cfg.resultsDir, 'figures'));

%% ========================================================================
%                              Local functions
% ========================================================================

function S = local_call_name_value(funHandle, audioPath, opts)
fields = fieldnames(opts);
nv = cell(1, 2*numel(fields));
for ii = 1:numel(fields)
    nv{2*ii-1} = fields{ii};
    nv{2*ii} = opts.(fields{ii});
end
S = funHandle(audioPath, nv{:});
end

function local_mkdir(pathStr)
if ~exist(pathStr, 'dir')
    mkdir(pathStr);
end
end

function id = local_sample_id(stem)
id = regexprep(string(stem), '[^A-Za-z0-9]+', '_');
id = regexprep(id, '_+', '_');
id = regexprep(id, '^_|_$', '');
end

function meta = local_parse_sample_name(stem)
parts = split(string(stem), '_');
meta = struct();
meta.instrument = "unknown";
meta.note = "";
meta.durationToken = "";
meta.dynamic = "";
meta.articulation = "";
if numel(parts) >= 1, meta.instrument = parts(1); end
if numel(parts) >= 2, meta.note = parts(2); end
if numel(parts) >= 3, meta.durationToken = parts(3); end
if numel(parts) >= 4, meta.dynamic = parts(4); end
if numel(parts) >= 5
    meta.articulation = strjoin(parts(5:end), "_");
end
meta.family = local_family(meta.instrument, meta.articulation);
end

function family = local_family(instrument, articulation)
inst = lower(string(instrument));
art = lower(string(articulation));
if any(inst == ["trumpet", "trombone", "tuba"])
    family = "brass";
elseif contains(inst, "clarinet")
    family = "woodwind/reed";
elseif any(inst == ["banjo", "guitar", "mandolin"])
    family = "plucked string";
elseif contains(art, "pizz")
    family = "plucked string";
elseif any(inst == ["violin", "cello", "double-bass"])
    family = "bowed string";
else
    family = "other";
end
end

function timing = local_get_timing(S)
sourceDur = NaN;
if isfield(S, 'fs') && isfield(S, 'x') && isfinite(S.fs) && S.fs > 0
    sourceDur = numel(S.x) / S.fs;
end
if isfield(S, 'globalEnvTiming') && isstruct(S.globalEnvTiming)
    timing = S.globalEnvTiming;
elseif isfield(S, 'params') && isfield(S.params, 'globalEnvTiming') && isstruct(S.params.globalEnvTiming)
    timing = S.params.globalEnvTiming;
else
    timing = struct();
end
if ~isfield(timing, 'tOnset') || ~isfinite(timing.tOnset), timing.tOnset = 0; end
if ~isfield(timing, 'tAttackEnd') || ~isfinite(timing.tAttackEnd), timing.tAttackEnd = timing.tOnset; end
if ~isfield(timing, 'tRelease') || ~isfinite(timing.tRelease), timing.tRelease = sourceDur; end
if ~isfield(timing, 'tNoteEnd') || ~isfinite(timing.tNoteEnd), timing.tNoteEnd = sourceDur; end
if ~isfield(timing, 'hasRelease') || isempty(timing.hasRelease), timing.hasRelease = false; end
if isfinite(sourceDur)
    timing.tOnset = min(max(timing.tOnset, 0), sourceDur);
    timing.tAttackEnd = min(max(timing.tAttackEnd, timing.tOnset), sourceDur);
    timing.tRelease = min(max(timing.tRelease, timing.tAttackEnd), sourceDur);
    timing.tNoteEnd = min(max(timing.tNoteEnd, timing.tRelease), sourceDur);
end
end

function strongestPeak = local_max_harmonic_peak(S, K)
peaks = nan(K,1);
for k = 1:K
    e = local_get_harmonic_measured_envelope(S, k, []);
    if ~isempty(e)
        peaks(k) = max(e, [], 'omitnan');
    end
end
strongestPeak = max(peaks, [], 'omitnan');
end

function measured = local_get_harmonic_measured_envelope(S, k, targetN)
measured = [];
if isfield(S, 'harm') && numel(S.harm) >= k
    hk = S.harm(k);
    if isfield(hk, 'ampNoVib') && ~isempty(hk.ampNoVib)
        measured = hk.ampNoVib(:);
    elseif isfield(hk, 'ampEnv') && ~isempty(hk.ampEnv)
        measured = hk.ampEnv(:);
    end
end
if isempty(measured)
    if isempty(targetN), targetN = 0; end
    measured = nan(targetN,1);
elseif ~isempty(targetN) && numel(measured) ~= targetN
    measured = local_match_length(measured, targetN);
end
measured(~isfinite(measured)) = NaN;
end

function recon = local_get_compact_reconstructed_envelope(S, k, t, sourceDur)
recon = nan(numel(t),1);
if isfield(S, 'params') && isfield(S.params, 'harm') && numel(S.params.harm) >= k && ...
        isfield(S.params.harm(k), 'envModel') && isstruct(S.params.harm(k).envModel)
    recon = local_rebuild_envelope_from_model(S.params.harm(k).envModel, t, sourceDur);
elseif isfield(S, 'harm') && numel(S.harm) >= k && isfield(S.harm(k), 'expEnv') && ...
        isfield(S.harm(k).expEnv, 'envFit') && ~isempty(S.harm(k).expEnv.envFit)
    recon = local_match_length(S.harm(k).expEnv.envFit(:), numel(t));
end
recon(~isfinite(recon)) = NaN;
end

function out = local_match_length(x, N)
x = x(:);
if isempty(x)
    out = nan(N,1);
elseif numel(x) == N
    out = x;
elseif numel(x) == 1
    out = repmat(x, N, 1);
else
    xi = linspace(0, 1, numel(x)).';
    xo = linspace(0, 1, N).';
    out = interp1(xi, x, xo, 'linear', 'extrap');
end
end

function valid = local_env_valid_mask(t, measured, recon, timing, cfg)
peak = max(measured, [], 'omitnan');
if ~isfinite(peak) || peak <= 0
    peak = 1;
end
valid = isfinite(measured) & isfinite(recon) & ...
    t >= timing.tOnset & t <= timing.tNoteEnd & ...
    (measured >= cfg.validEnvelopeMinFrac*peak | recon >= cfg.validEnvelopeMinFrac*peak);
end

function [relRmse, mae, corrVal, r2Val] = local_envelope_metrics(measured, recon, valid)
relRmse = NaN; mae = NaN; corrVal = NaN; r2Val = NaN;
if nargin < 3 || isempty(valid)
    valid = isfinite(measured) & isfinite(recon);
end
if nnz(valid) < 3
    return;
end
m = measured(valid);
r = recon(valid);
err = r - m;
mae = mean(abs(err), 'omitnan');
relRmse = sqrt(mean(err.^2, 'omitnan')) / max(sqrt(mean(m.^2, 'omitnan')), eps);
if local_nanstd(m) > eps && local_nanstd(r) > eps
    cc = corrcoef(m, r);
    if numel(cc) >= 4
        corrVal = cc(1,2);
    end
end
den = sum((m - mean(m, 'omitnan')).^2, 'omitnan');
if den > eps
    r2Val = 1 - sum(err.^2, 'omitnan') / den;
end
end

function relRmse = local_region_rel_rmse(t, measured, recon, t0, t1, cfg)
relRmse = NaN;
if ~isfinite(t0) || ~isfinite(t1) || t1 <= t0
    return;
end
peak = max(measured, [], 'omitnan');
if ~isfinite(peak) || peak <= 0, peak = 1; end
mask = isfinite(measured) & isfinite(recon) & t >= t0 & t <= t1 & ...
    (measured >= cfg.validEnvelopeMinFrac*peak | recon >= cfg.validEnvelopeMinFrac*peak);
if nnz(mask) < 3
    return;
end
m = measured(mask);
r = recon(mask);
relRmse = sqrt(mean((r-m).^2, 'omitnan')) / max(sqrt(mean(m.^2, 'omitnan')), eps);
end

function count = local_count_env_knots(S, k)
count = NaN;
if ~(isfield(S, 'params') && isfield(S.params, 'harm') && numel(S.params.harm) >= k && ...
        isfield(S.params.harm(k), 'envModel'))
    return;
end
envModel = S.params.harm(k).envModel;
count = 0;
if isfield(envModel, 'segments') && isstruct(envModel.segments)
    names = {'attack','body','release'};
    for ii = 1:numel(names)
        nm = names{ii};
        if isfield(envModel.segments, nm) && isfield(envModel.segments.(nm), 'knotTimes')
            count = count + numel(envModel.segments.(nm).knotTimes);
        end
    end
end
end

function cause = local_failure_cause(meta, k, relRmse, isWeak, attackErr, bodyErr, releaseErr)
if isWeak
    cause = "weak/noisy harmonic";
elseif contains(lower(string(meta.family)), "plucked") && isfinite(attackErr) && attackErr > 0.30
    cause = "pluck transient or rapid decay too simple";
elseif contains(lower(string(meta.family)), "brass") && isfinite(attackErr) && isfinite(bodyErr) && attackErr > 1.4*bodyErr
    cause = "sharp brass attack not captured";
elseif isfinite(releaseErr) && isfinite(bodyErr) && releaseErr > 1.5*bodyErr
    cause = "release or tail mismatch";
elseif k >= 10 && isfinite(relRmse) && relRmse > 0.30
    cause = "upper harmonic irregularity";
elseif isfinite(relRmse) && relRmse > 0.30
    cause = "too few knots or irregular amplitude variation";
else
    cause = "acceptable fit";
end
end

function envFit = local_rebuild_envelope_from_model(envModel, tEval, sourceDur)
tEval = tEval(:);
baseline = local_get_scalar(envModel, 'baseline', 0);
if ~isfinite(baseline) || baseline < 0, baseline = 0; end
envFit = baseline * ones(size(tEval));
if ~isfield(envModel, 'segments') || ~isstruct(envModel.segments)
    envFit(:) = 0;
    return;
end
lastSegmentEnd = NaN;
if isfield(envModel.segments, 'attack')
    [envFit, segEnd] = local_apply_envelope_segment(envFit, tEval, envModel.segments.attack, envModel, 'attack');
    if isfinite(segEnd), lastSegmentEnd = segEnd; end
end
if isfield(envModel.segments, 'body')
    [envFit, segEnd] = local_apply_envelope_segment(envFit, tEval, envModel.segments.body, envModel, 'body');
    if isfinite(segEnd), lastSegmentEnd = segEnd; end
end
if isfield(envModel.segments, 'release')
    rel = envModel.segments.release;
    useRelease = true;
    if isfield(rel, 'hasRelease') && ~rel.hasRelease
        useRelease = false;
    end
    if useRelease
        [envFit, segEnd] = local_apply_envelope_segment(envFit, tEval, rel, envModel, 'release');
        if isfinite(segEnd), lastSegmentEnd = segEnd; end
    elseif isfield(rel, 'tEnd') && isfinite(rel.tEnd)
        lastSegmentEnd = rel.tEnd;
    end
end
if isfinite(lastSegmentEnd) && lastSegmentEnd < max(tEval)
    idx0 = find(tEval <= lastSegmentEnd, 1, 'last');
    if isempty(idx0), y0 = baseline; else, y0 = envFit(idx0); end
    mask = tEval >= lastSegmentEnd;
    x = (tEval(mask) - lastSegmentEnd) ./ max(sourceDur - lastSegmentEnd, eps);
    x = min(max(x, 0), 1);
    envFit(mask) = y0 + (baseline - y0) .* local_smoothstep_poly(x, 5);
end
envFit(~isfinite(envFit)) = 0;
envFit = max(envFit, 0);
end

function [envFit, segEnd] = local_apply_envelope_segment(envFit, tEval, seg, envModel, segName) %#ok<INUSD>
segEnd = NaN;
if ~isstruct(seg) || ~isfield(seg, 'tStart') || ~isfield(seg, 'tEnd') || ...
        ~isfinite(seg.tStart) || ~isfinite(seg.tEnd)
    return;
end
segStart = seg.tStart;
segEnd = seg.tEnd;
if segEnd < segStart
    tmp = segStart; segStart = segEnd; segEnd = tmp;
end
mask = tEval >= segStart & tEval <= segEnd;
if ~any(mask)
    return;
end
[knT, knV] = local_get_env_knots(seg);
if numel(knT) < 1
    return;
elseif numel(knT) == 1 || segEnd == segStart
    envFit(mask) = max(knV(1), 0);
    return;
end
method = '';
if isfield(seg, 'model') && ~isempty(seg.model), method = lower(char(seg.model)); end
if ~isempty(strfind(method, 'smoothstep')) %#ok<STREMP>
    order = round(local_get_scalar(envModel, 'attackShapeOrder', 5));
    x = (tEval(mask) - segStart) ./ max(segEnd - segStart, eps);
    x = min(max(x, 0), 1);
    envFit(mask) = knV(1) + (knV(end) - knV(1)) .* local_smoothstep_poly(x, order);
else
    envFit(mask) = interp1(knT, knV, tEval(mask), 'pchip', 'extrap');
end
envFit(mask) = max(envFit(mask), 0);
end

function [knT, knV] = local_get_env_knots(seg)
knT = [];
knV = [];
if isfield(seg, 'knotTimes') && isfield(seg, 'knotValues')
    knT = seg.knotTimes(:);
    knV = seg.knotValues(:);
end
valid = isfinite(knT) & isfinite(knV);
knT = knT(valid);
knV = knV(valid);
if isempty(knT), return; end
[knT, ia] = unique(knT, 'stable');
knV = knV(ia);
[knT, order] = sort(knT);
knV = knV(order);
end

function y = local_smoothstep_poly(x, order)
x = min(max(x, 0), 1);
if order <= 1
    y = x;
elseif order <= 3
    y = x.^2 .* (3 - 2*x);
else
    y = x.^3 .* (10 - 15*x + 6*x.^2);
end
end

function val = local_get_scalar(s, fieldName, defaultVal)
val = defaultVal;
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName)) && isnumeric(s.(fieldName)) && isscalar(s.(fieldName))
    val = s.(fieldName);
end
end

function local_plot_envelope_grid(t, measuredMat, reconMat, timing, meta, sampleID, outDir, cfg)
K = min(size(measuredMat,2), cfg.gridMaxHarmonics);
rows = ceil(K/3); cols = 3;
fig = figure('Visible','off','Color','w','Name',char(sampleID + " envelope grid"));
set(fig, 'Position', [100 100 1300 900]);
for k = 1:K
    ax = subplot(rows, cols, k);
    [m, r] = local_plot_scaled_pair(measuredMat(:,k), reconMat(:,k), cfg);
    plot(ax, t, m, 'LineWidth', 1.0); hold(ax, 'on');
    plot(ax, t, r, '--', 'LineWidth', 1.2);
    local_add_boundaries(ax, timing);
    grid(ax, 'on');
    title(ax, sprintf('H%d', k));
    if k > K-cols, xlabel(ax, 'Time (s)'); end
    if mod(k-1, cols) == 0, ylabel(ax, 'Envelope'); end
end
sgtitle(sprintf('%s %s %s: compact envelope fits', meta.instrument, meta.note, meta.articulation), 'Interpreter','none');
local_save_figure(fig, fullfile(outDir, sampleID + "_envelope_grid.png"), cfg.imageDpi);
close(fig);
end

function local_plot_low_mid_high(t, measuredMat, reconMat, timing, meta, sampleID, outDir, cfg)
K = size(measuredMat,2);
hList = unique([1, max(1, round(K/2)), K], 'stable');
fig = figure('Visible','off','Color','w','Name',char(sampleID + " low mid high envelopes"));
set(fig, 'Position', [100 100 1200 800]);
for ii = 1:numel(hList)
    k = hList(ii);
    ax = subplot(numel(hList),1,ii);
    [m, r] = local_plot_scaled_pair(measuredMat(:,k), reconMat(:,k), cfg);
    plot(ax, t, m, 'LineWidth', 1.1, 'DisplayName', sprintf('H%d measured', k)); hold(ax, 'on');
    plot(ax, t, r, '--', 'LineWidth', 1.4, 'DisplayName', sprintf('H%d compact model', k));
    local_add_boundaries(ax, timing);
    grid(ax, 'on');
    ylabel(ax, 'Envelope');
    legend(ax, 'Location', 'best');
    title(ax, sprintf('Harmonic %d', k));
end
xlabel('Time (s)');
sgtitle(sprintf('%s %s %s: low, middle, and high harmonic envelopes', meta.instrument, meta.note, meta.articulation), 'Interpreter','none');
local_save_figure(fig, fullfile(outDir, sampleID + "_low_mid_high_envelopes.png"), cfg.imageDpi);
close(fig);
end

function [m, r] = local_plot_scaled_pair(measured, recon, cfg)
m = measured(:);
r = recon(:);
if cfg.plotNormalizePerHarmonic
    scale = max(m, [], 'omitnan');
    if ~isfinite(scale) || scale <= 0
        scale = max(r, [], 'omitnan');
    end
    if isfinite(scale) && scale > 0
        m = m ./ scale;
        r = r ./ scale;
    end
end
end

function local_plot_error_by_harmonic(errByHarm, corrByHarm, harmRelPeak, meta, sampleID, outDir, cfg)
K = numel(errByHarm);
fig = figure('Visible','off','Color','w','Name',char(sampleID + " envelope error"));
set(fig, 'Position', [100 100 1200 700]);
ax1 = subplot(2,1,1);
bar(ax1, 1:K, errByHarm);
grid(ax1, 'on');
ylabel(ax1, 'Rel. RMSE');
title(ax1, 'Envelope reconstruction error by harmonic');
ax2 = subplot(2,1,2);
plot(ax2, 1:K, corrByHarm, '-o', 'DisplayName', 'Envelope correlation'); hold(ax2, 'on');
plot(ax2, 1:K, harmRelPeak, '-s', 'DisplayName', 'Relative harmonic peak');
grid(ax2, 'on');
xlabel(ax2, 'Harmonic number'); ylabel(ax2, 'Value');
legend(ax2, 'Location', 'best');
sgtitle(sprintf('%s %s %s: envelope fit metrics', meta.instrument, meta.note, meta.articulation), 'Interpreter','none');
local_save_figure(fig, fullfile(outDir, sampleID + "_envelope_error_by_harmonic.png"), cfg.imageDpi);
close(fig);
end

function local_plot_failure_harmonics(t, measuredMat, reconMat, errByHarm, timing, meta, sampleID, outDir, cfg)
[errSorted, order] = sort(errByHarm, 'descend', 'MissingPlacement', 'last');
count = 0;
for ii = 1:numel(order)
    k = order(ii);
    if ~isfinite(errSorted(ii)) || errSorted(ii) < cfg.failureRelRmseThreshold
        continue;
    end
    count = count + 1;
    fig = figure('Visible','off','Color','w','Name',char(sampleID + " H" + k + " envelope failure"));
    set(fig, 'Position', [100 100 1100 500]);
    [m, r] = local_plot_scaled_pair(measuredMat(:,k), reconMat(:,k), cfg);
    plot(t, m, 'LineWidth', 1.1, 'DisplayName', 'Measured slow envelope'); hold on;
    plot(t, r, '--', 'LineWidth', 1.4, 'DisplayName', 'Compact knot model');
    local_add_boundaries(gca, timing);
    grid on; xlabel('Time (s)'); ylabel('Normalized envelope');
    title(sprintf('%s %s %s H%d envelope failure, rel. RMSE = %.3f', ...
        meta.instrument, meta.note, meta.articulation, k, errSorted(ii)), 'Interpreter','none');
    legend('Location','best');
    local_save_figure(fig, fullfile(outDir, sampleID + sprintf('_H%02d_envelope_failure.png', k)), cfg.imageDpi);
    close(fig);
    if count >= cfg.maxFailurePlotsPerSample
        break;
    end
end
end

function local_add_boundaries(ax, timing)
yl = ylim(ax);
local_vline(ax, timing.tOnset, yl, '-', 'on');
local_vline(ax, timing.tAttackEnd, yl, '--', 'attack');
local_vline(ax, timing.tRelease, yl, ':', 'release');
local_vline(ax, timing.tNoteEnd, yl, '-.', 'end');
ylim(ax, yl);
end

function local_vline(ax, x, yl, style, labelText)
if ~isfinite(x), return; end
line(ax, [x x], yl, 'LineStyle', style, 'LineWidth', 0.8, 'HandleVisibility','off');
if nargin >= 5 && ~isempty(labelText)
    text(ax, x, yl(2), [' ' labelText], 'Rotation', 90, 'VerticalAlignment','top', 'FontSize', 7, 'Interpreter','none');
end
end

function local_save_figure(fig, outPath, dpi)
try
    exportgraphics(fig, outPath, 'Resolution', dpi);
catch
    saveas(fig, outPath);
end
end

function T = local_cell2table(rows, names)
if isempty(rows)
    T = cell2table(cell(0, numel(names)), 'VariableNames', names);
else
    T = cell2table(rows, 'VariableNames', names);
end
end

function out = local_representative_rows(T, representativeContains)
out = T;
if isempty(T) || height(T) == 0 || ~ismember('fileName', T.Properties.VariableNames)
    return;
end
fileNames = string(T.fileName);
mask = false(height(T),1);
for ii = 1:numel(representativeContains)
    mask = mask | contains(fileNames, representativeContains(ii), 'IgnoreCase', true);
end
out = T(mask,:);
end

function out = local_summary_by_family(summaryTable)
vars = {'family','numSamples','meanEnvRelRMSE','medianEnvRelRMSE','meanEnvCorr','meanLowRelRMSE','meanMidRelRMSE','meanHighRelRMSE','meanWeakHarmonics'};
if isempty(summaryTable) || height(summaryTable) == 0
    out = cell2table(cell(0,numel(vars)), 'VariableNames', vars);
    return;
end
families = unique(string(summaryTable.family), 'stable');
rows = {};
for ii = 1:numel(families)
    fam = families(ii);
    mask = string(summaryTable.family) == fam;
    rows(end+1,:) = {fam, nnz(mask), ... %#ok<AGROW>
        local_nanmean(local_numeric_column(summaryTable, 'meanEnvRelRMSE', mask)), ...
        local_nanmedian(local_numeric_column(summaryTable, 'medianEnvRelRMSE', mask)), ...
        local_nanmean(local_numeric_column(summaryTable, 'meanEnvCorr', mask)), ...
        local_nanmean(local_numeric_column(summaryTable, 'lowHarmMeanRelRMSE', mask)), ...
        local_nanmean(local_numeric_column(summaryTable, 'midHarmMeanRelRMSE', mask)), ...
        local_nanmean(local_numeric_column(summaryTable, 'highHarmMeanRelRMSE', mask)), ...
        local_nanmean(local_numeric_column(summaryTable, 'numWeakHarmonics', mask))};
end
out = cell2table(rows, 'VariableNames', vars);
end

function out = local_failure_case_table(envelopeTable, nRows)
if isempty(envelopeTable) || height(envelopeTable) == 0
    out = envelopeTable;
    return;
end
err = local_numeric_column(envelopeTable, 'envRelRMSE', true(height(envelopeTable),1));
[~, order] = sort(err, 'descend', 'MissingPlacement', 'last');
order = order(1:min(nRows, numel(order)));
keep = {'sampleID','instrument','note','articulation','family','harmonic','relativePeak','envRelRMSE', ...
    'envCorr','attackRelRMSE','bodyRelRMSE','releaseRelRMSE','likelyFailureCause','manualNotes'};
keep = keep(ismember(keep, envelopeTable.Properties.VariableNames));
out = envelopeTable(order, keep);
end

function x = local_numeric_column(T, varName, mask)
if nargin < 3 || isempty(mask)
    mask = true(height(T),1);
elseif islogical(mask) && isscalar(mask)
    mask = repmat(mask, height(T), 1);
end
v = T.(varName);
if iscell(v)
    try
        x = cell2mat(v(mask));
    catch
        x = str2double(string(v(mask)));
    end
elseif isnumeric(v) || islogical(v)
    x = double(v(mask));
else
    x = str2double(string(v(mask)));
end
x = x(:);
end

function m = local_nanmean(x)
x = x(:);
x = x(isfinite(x));
if isempty(x), m = NaN; else, m = mean(x); end
end

function m = local_nanmedian(x)
x = x(:);
x = x(isfinite(x));
if isempty(x), m = NaN; else, m = median(x); end
end

function m = local_nanmax(x)
x = x(:);
x = x(isfinite(x));
if isempty(x), m = NaN; else, m = max(x); end
end

function s = local_nanstd(x)
x = x(:);
x = x(isfinite(x));
if numel(x) < 2
    s = NaN;
else
    s = std(x);
end
end

function local_write_latex_snippets(repSummary, failureCases, outPath)
fid = fopen(outPath, 'w');
if fid < 0
    warning('Could not write latex snippets to %s', outPath);
    return;
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%% Auto-generated by envelope_results_V27.m\n\n');
fprintf(fid, '%% Representative envelope summary table. Edit captions/labels as needed.\n');
fprintf(fid, '\\begin{table}[htbp]\n\\centering\n\\small\n\\setlength{\\tabcolsep}{4pt}\n');
fprintf(fid, '\\caption{Representative compact envelope reconstruction results.}\n');
fprintf(fid, '\\label{tab:envelope_representative_results}\n');
fprintf(fid, '\\begin{tabular}{lrrrrr}\n\\hline\n');
fprintf(fid, 'Sample & $K$ & Mean RMSE & Low & Mid & High \\\\ \n\\hline\n');
if ~isempty(repSummary) && height(repSummary) > 0
    for ii = 1:height(repSummary)
        sample = sprintf('%s %s', string(repSummary.instrument(ii)), string(repSummary.note(ii)));
        fprintf(fid, '%s & %.0f & %.3f & %.3f & %.3f & %.3f \\\\ \n', ...
            local_latex_escape(sample), repSummary.numHarmonics(ii), repSummary.meanEnvRelRMSE(ii), ...
            repSummary.lowHarmMeanRelRMSE(ii), repSummary.midHarmMeanRelRMSE(ii), repSummary.highHarmMeanRelRMSE(ii));
    end
end
fprintf(fid, '\\hline\n\\end{tabular}\n\\end{table}\n\n');

fprintf(fid, '%% Largest envelope failure cases.\n');
fprintf(fid, '\\begin{table}[htbp]\n\\centering\n\\small\n\\setlength{\\tabcolsep}{4pt}\n');
fprintf(fid, '\\caption{Largest compact envelope reconstruction errors.}\n');
fprintf(fid, '\\label{tab:envelope_failure_cases}\n');
fprintf(fid, '\\begin{tabular}{llrrl}\n\\hline\n');
fprintf(fid, 'Sample & Harm. & Rel. peak & RMSE & Likely cause \\\\ \n\\hline\n');
if ~isempty(failureCases) && height(failureCases) > 0
    n = min(8, height(failureCases));
    for ii = 1:n
        sample = sprintf('%s %s', string(failureCases.instrument(ii)), string(failureCases.note(ii)));
        fprintf(fid, '%s & H%d & %.3f & %.3f & %s \\\\ \n', ...
            local_latex_escape(sample), failureCases.harmonic(ii), failureCases.relativePeak(ii), ...
            failureCases.envRelRMSE(ii), local_latex_escape(string(failureCases.likelyFailureCause(ii))));
    end
end
fprintf(fid, '\\hline\n\\end{tabular}\n\\end{table}\n');
end

function s = local_latex_escape(s)
s = char(string(s));
s = strrep(s, '\', '\textbackslash{}');
s = strrep(s, '_', '\_');
s = strrep(s, '%', '\%');
s = strrep(s, '&', '\&');
s = strrep(s, '#', '\#');
end
