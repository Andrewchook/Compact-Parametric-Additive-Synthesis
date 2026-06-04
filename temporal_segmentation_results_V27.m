%% temporal_segmentation_results_V27.m
% Batch test script for the thesis section:
%   \section{Temporal Segmentation Results}
%
% This script runs only the V27 analysis stage and extracts the global
% temporal segmentation boundaries:
%   onset, attack end, release start, and note end.
%
% Outputs:
%   temporal_segmentation_results_V27/tables/boundary_table.csv
%   temporal_segmentation_results_V27/tables/attack_duration_table.csv
%   temporal_segmentation_results_V27/tables/segmentation_summary_by_family.csv
%   temporal_segmentation_results_V27/tables/failure_table.csv
%   temporal_segmentation_results_V27/figures/global_envelopes/*.png
%   temporal_segmentation_results_V27/figures/attack_zoom/*.png
%
% Required on MATLAB path:
%   vib_analyze_harmonics_analysis_V27.m
%
% Recommended use:
%   Put this script in the same folder as vib_analyze_harmonics_analysis_V27.m,
%   update cfg.resultsDir if desired, and run this file.

clear; close all; clc;

%% ---------------- User settings ----------------
cfg = struct();
cfg.resultsDir = fullfile(pwd, 'temporal_segmentation_results_V27');
cfg.numHarmonics = 15;

% Plot controls. Keep false to make thesis figures only for representative
% samples. Set true if you want one global and one attack plot for every file.
cfg.makePlotsForAll = false;
cfg.representativeContains = [ ...
    "violin_A4_1_fortissimo", ...
    "trombone_As3_15", ...
    "banjo_A4_very-long", ...
    "bass-clarinet_B3_05", ...
    "guitar_C3_very-long", ...
    "tuba_A2_long" ...
];

% Envelope plotting settings. These do not affect V27 analysis; they are
% used only to draw clear thesis figures of the global envelope.
cfg.plotEnvelopeFs = 4000;
cfg.plotEnvelopeLpHz = 120;
cfg.attackPreMs = 80;
cfg.attackPostMs = 220;
cfg.globalEnvelopeYLimit = [0 1.08];
cfg.imageDpi = 200;

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
globalFigDir = fullfile(cfg.resultsDir, 'figures', 'global_envelopes');
attackFigDir = fullfile(cfg.resultsDir, 'figures', 'attack_zoom');
matDir = fullfile(cfg.resultsDir, 'mat');
local_mkdir(cfg.resultsDir);
local_mkdir(tableDir);
local_mkdir(globalFigDir);
local_mkdir(attackFigDir);
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
boundaryRows = {};
attackRows = {};
failureRows = {};

fprintf('Temporal segmentation V27 batch test starting.\n');
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
        [tEnv, envNorm, rawEnvNorm] = local_global_envelope_for_plot(S.x, S.fs, cfg);
        [att, body, rel] = local_segmentation_durations(timing);
        onsetInfo = local_get_struct(timing, 'onsetInfo');
        releaseInfo = local_get_struct(timing, 'releaseInfo');
        onsetMethod = local_get_string(onsetInfo, 'method', "");
        attackEndMethod = local_get_string(onsetInfo, 'attackEndMethod', "");
        usedBacktracked = local_get_logical(onsetInfo, 'usedBacktrackedOnset', false);
        onsetCorrectionSec = local_get_scalar(onsetInfo, 'correctionSec', NaN);
        oldPeakDelaySec = local_get_scalar(onsetInfo, 'oldPeakDelaySec', NaN);
        backPeakDelaySec = local_get_scalar(onsetInfo, 'backPeakDelaySec', NaN);
        releaseImprovement = local_get_scalar(releaseInfo, 'improvement', NaN);
        attackClass = local_attack_class(att.durationSec);

        boundaryRows(end+1,:) = { ... %#ok<SAGROW>
            sampleID, string(fileName), string(meta.instrument), string(meta.note), string(meta.durationToken), ...
            string(meta.dynamic), string(meta.articulation), string(meta.family), S.f0Hz, numel(S.x)/S.fs, ...
            timing.tOnset, timing.tAttackEnd, timing.tRelease, timing.tNoteEnd, ...
            att.durationSec, body.durationSec, rel.durationSec, logical(timing.hasRelease), ...
            onsetMethod, attackEndMethod, usedBacktracked, onsetCorrectionSec, releaseImprovement, ...
            "ADD MANUAL NOTE"};

        attackRows(end+1,:) = { ... %#ok<SAGROW>
            sampleID, string(meta.instrument), string(meta.note), string(meta.articulation), string(meta.family), ...
            att.durationSec, 1000*att.durationSec, attackClass, onsetMethod, attackEndMethod, ...
            usedBacktracked, 1000*onsetCorrectionSec, 1000*oldPeakDelaySec, 1000*backPeakDelaySec};

        if makePlots
            local_plot_global_envelope(tEnv, envNorm, rawEnvNorm, timing, meta, sampleID, globalFigDir, cfg);
            local_plot_attack_zoom(tEnv, envNorm, rawEnvNorm, timing, meta, sampleID, attackFigDir, cfg);
        end

        save(fullfile(matDir, sampleID + "_segmentation.mat"), 'S', 'timing', 'meta', 'sampleID');

    catch ME
        failureRows(end+1,:) = {sampleID, string(audioPath), "analysis_failed", string(ME.message)}; %#ok<SAGROW>
        warning('Analysis failed for %s: %s', fileName, ME.message);
    end
end

%% ---------------- Write tables ----------------
boundaryNames = {'sampleID','fileName','instrument','note','durationToken','dynamic','articulation','family', ...
    'f0Hz','durationSec','tOnsetSec','tAttackEndSec','tReleaseSec','tNoteEndSec', ...
    'attackDurSec','bodyDurSec','releaseDurSec','hasRelease','onsetMethod','attackEndMethod', ...
    'usedBacktrackedOnset','onsetCorrectionSec','releaseImprovement','manualNotes'};
attackNames = {'sampleID','instrument','note','articulation','family','attackDurSec','attackDurMs', ...
    'attackClass','onsetMethod','attackEndMethod','usedBacktrackedOnset','onsetCorrectionMs', ...
    'firstThresholdToPeakMs','backtrackedToPeakMs'};
failureNames = {'sampleID','audioPath','status','message'};

boundaryTable = local_cell2table(boundaryRows, boundaryNames);
attackTable = local_cell2table(attackRows, attackNames);
failureTable = local_cell2table(failureRows, failureNames);
summaryTable = local_summary_by_family(boundaryTable);
representativeBoundaryTable = local_representative_rows(boundaryTable, cfg.representativeContains);
representativeAttackTable = local_representative_rows(attackTable, cfg.representativeContains);

writetable(boundaryTable, fullfile(tableDir, 'boundary_table.csv'));
writetable(attackTable, fullfile(tableDir, 'attack_duration_table.csv'));
writetable(summaryTable, fullfile(tableDir, 'segmentation_summary_by_family.csv'));
writetable(representativeBoundaryTable, fullfile(tableDir, 'representative_boundary_table.csv'));
writetable(representativeAttackTable, fullfile(tableDir, 'representative_attack_duration_table.csv'));
writetable(failureTable, fullfile(tableDir, 'failure_table.csv'));
save(fullfile(cfg.resultsDir, 'temporal_segmentation_batch_summary.mat'), ...
    'cfg', 'boundaryTable', 'attackTable', 'summaryTable', 'representativeBoundaryTable', ...
    'representativeAttackTable', 'failureTable');

local_write_latex_snippets(tableDir, representativeBoundaryTable, representativeAttackTable);
local_write_readme(cfg.resultsDir);

fprintf('\nDone. Tables written to:\n  %s\n', tableDir);
fprintf('Envelope figures written to:\n  %s\n  %s\n', globalFigDir, attackFigDir);

%% ================= Local functions =================

function out = local_call_name_value(funHandle, firstArg, optsStruct)
    try
        out = funHandle(firstArg, optsStruct);
    catch
        nv = local_struct_to_nv(optsStruct);
        out = funHandle(firstArg, nv{:});
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

function timing = local_get_timing(S)
    if isfield(S, 'globalEnvTiming') && isstruct(S.globalEnvTiming)
        timing = S.globalEnvTiming;
    elseif isfield(S, 'params') && isfield(S.params, 'globalEnvTiming')
        timing = S.params.globalEnvTiming;
    else
        error('Could not find S.globalEnvTiming. Check the V27 analysis output.');
    end
    required = {'tOnset','tAttackEnd','tRelease','tNoteEnd','hasRelease'};
    for ii = 1:numel(required)
        if ~isfield(timing, required{ii})
            error('Timing field missing: %s', required{ii});
        end
    end
end

function [att, body, rel] = local_segmentation_durations(timing)
    att = struct(); body = struct(); rel = struct();
    att.durationSec = max(0, timing.tAttackEnd - timing.tOnset);
    body.durationSec = max(0, timing.tRelease - timing.tAttackEnd);
    rel.durationSec = max(0, timing.tNoteEnd - timing.tRelease);
end

function [tOut, envNorm, rawNorm] = local_global_envelope_for_plot(x, fs, cfg)
    x = x(:);
    t = (0:numel(x)-1).' / fs;
    raw = abs(hilbert(x));
    smooth = local_lowpass_or_smooth(raw, cfg.plotEnvelopeLpHz, fs);
    smooth = max(smooth, 0);
    raw = max(raw, 0);
    if cfg.plotEnvelopeFs > 0 && cfg.plotEnvelopeFs < fs
        tOut = (0:round(t(end)*cfg.plotEnvelopeFs)).' / cfg.plotEnvelopeFs;
        envPlot = interp1(t, smooth, tOut, 'linear', 'extrap');
        rawPlot = interp1(t, raw, tOut, 'linear', 'extrap');
    else
        tOut = t;
        envPlot = smooth;
        rawPlot = raw;
    end
    mx = max(envPlot);
    if ~isfinite(mx) || mx <= 0
        mx = 1;
    end
    envNorm = envPlot / mx;
    rawNorm = rawPlot / max(mx, eps);
    rawNorm = min(rawNorm, 1.5);
end

function y = local_lowpass_or_smooth(x, cutoffHz, fs)
    x = x(:);
    if cutoffHz <= 0 || cutoffHz >= fs/2
        y = x;
        return;
    end
    try
        y = lowpass(x, cutoffHz, fs);
    catch
        try
            [b,a] = butter(4, cutoffHz/(fs/2), 'low');
            y = filtfilt(b, a, x);
        catch
            winN = max(3, round(fs / max(cutoffHz, 1)));
            y = movmean(x, winN);
        end
    end
end

function local_plot_global_envelope(t, envNorm, rawNorm, timing, meta, sampleID, outDir, cfg)
    fig = figure('Color','w','Name',sampleID + " global envelope", 'Visible','off');
    plot(t, rawNorm, 'Color', [0.75 0.75 0.75], 'DisplayName','raw abs/Hilbert envelope'); hold on;
    plot(t, envNorm, 'LineWidth', 1.6, 'DisplayName','smoothed global envelope');
    local_add_segmentation_lines(timing);
    ylim(cfg.globalEnvelopeYLimit);
    xlim([0 max(t)]);
    grid on;
    xlabel('Time (s)');
    ylabel('Normalized envelope');
    title(sprintf('%s %s %s: global temporal segmentation', meta.instrument, meta.note, meta.articulation), 'Interpreter','none');
    legend('Location','northeastoutside');
    local_save_figure(fig, fullfile(outDir, sampleID + "_global_envelope.png"), cfg.imageDpi);
    close(fig);
end

function local_plot_attack_zoom(t, envNorm, rawNorm, timing, meta, sampleID, outDir, cfg)
    pre = cfg.attackPreMs / 1000;
    post = cfg.attackPostMs / 1000;
    x1 = max(0, timing.tOnset - pre);
    x2 = min(max(t), timing.tAttackEnd + post);
    if x2 <= x1
        x2 = min(max(t), timing.tOnset + 0.3);
    end
    fig = figure('Color','w','Name',sampleID + " attack zoom", 'Visible','off');
    plot(t, rawNorm, 'Color', [0.75 0.75 0.75], 'DisplayName','raw abs/Hilbert envelope'); hold on;
    plot(t, envNorm, 'LineWidth', 1.6, 'DisplayName','smoothed global envelope');
    local_add_segmentation_lines(timing);
    ylim(cfg.globalEnvelopeYLimit);
    xlim([x1 x2]);
    grid on;
    xlabel('Time (s)');
    ylabel('Normalized envelope');
    title(sprintf('%s %s %s: attack detection zoom', meta.instrument, meta.note, meta.articulation), 'Interpreter','none');
    legend('Location','northeastoutside');
    local_save_figure(fig, fullfile(outDir, sampleID + "_attack_zoom.png"), cfg.imageDpi);
    close(fig);
end

function local_add_segmentation_lines(timing)
    xline(timing.tOnset, 'g-', 'Onset', 'LineWidth', 1.4, 'LabelVerticalAlignment','bottom');
    xline(timing.tAttackEnd, 'b-', 'Attack end', 'LineWidth', 1.4, 'LabelVerticalAlignment','bottom');
    if isfield(timing, 'tPeak') && isfinite(timing.tPeak)
        xline(timing.tPeak, 'c:', 'Peak', 'LineWidth', 1.0, 'LabelVerticalAlignment','top');
    end
    if timing.hasRelease
        xline(timing.tRelease, 'm-', 'Release start', 'LineWidth', 1.4, 'LabelVerticalAlignment','bottom');
    else
        xline(timing.tRelease, 'm--', 'No clear release', 'LineWidth', 1.2, 'LabelVerticalAlignment','bottom');
    end
    xline(timing.tNoteEnd, 'r-', 'Note end', 'LineWidth', 1.4, 'LabelVerticalAlignment','bottom');
end

function local_save_figure(fig, outPath, dpi)
    try
        exportgraphics(fig, outPath, 'Resolution', dpi);
    catch
        print(fig, outPath, '-dpng', ['-r' num2str(dpi)]);
    end
end

function sampleID = local_sample_id(stem)
    sampleID = regexprep(string(stem), '[^A-Za-z0-9]+', '_');
    sampleID = regexprep(sampleID, '_+', '_');
    sampleID = regexprep(sampleID, '^_|_$', '');
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

function label = local_attack_class(attackSec)
    if ~isfinite(attackSec)
        label = "unknown";
    elseif attackSec < 0.025
        label = "very sharp";
    elseif attackSec < 0.075
        label = "sharp";
    elseif attackSec < 0.150
        label = "moderate";
    else
        label = "slow";
    end
end

function s = local_get_struct(parent, fieldName)
    if isstruct(parent) && isfield(parent, fieldName) && isstruct(parent.(fieldName))
        s = parent.(fieldName);
    else
        s = struct();
    end
end

function val = local_get_scalar(s, fieldName, defaultVal)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName)) && isnumeric(s.(fieldName))
        val = double(s.(fieldName));
        val = val(1);
    else
        val = defaultVal;
    end
end

function val = local_get_logical(s, fieldName, defaultVal)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        val = logical(s.(fieldName));
        val = val(1);
    else
        val = defaultVal;
    end
end

function val = local_get_string(s, fieldName, defaultVal)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        val = string(s.(fieldName));
    else
        val = string(defaultVal);
    end
end

function T = local_cell2table(rows, names)
    if isempty(rows)
        T = cell2table(cell(0, numel(names)), 'VariableNames', names);
    else
        T = cell2table(rows, 'VariableNames', names);
    end
end

function summaryTable = local_summary_by_family(boundaryTable)
    names = {'family','numSamples','meanAttackMs','medianAttackMs','meanBodySec','meanReleaseSec','numNoClearRelease','numBacktrackedOnsets'};
    if isempty(boundaryTable) || height(boundaryTable) == 0 || ~ismember('family', boundaryTable.Properties.VariableNames)
        summaryTable = cell2table(cell(0,numel(names)), 'VariableNames', names);
        return;
    end
    fams = unique(boundaryTable.family);
    rows = cell(numel(fams), numel(names));
    for ii = 1:numel(fams)
        mask = boundaryTable.family == fams(ii);
        sub = boundaryTable(mask,:);
        rows(ii,:) = {fams(ii), height(sub), ...
            mean(1000*sub.attackDurSec, 'omitnan'), median(1000*sub.attackDurSec, 'omitnan'), ...
            mean(sub.bodyDurSec, 'omitnan'), mean(sub.releaseDurSec, 'omitnan'), ...
            sum(~sub.hasRelease), sum(sub.usedBacktrackedOnset)};
    end
    summaryTable = cell2table(rows, 'VariableNames', names);
end

function Tsel = local_representative_rows(T, representativeContains)
    if isempty(T) || height(T) == 0 || ~ismember('sampleID', T.Properties.VariableNames)
        Tsel = T;
        return;
    end
    mask = false(height(T),1);
    for ii = 1:numel(representativeContains)
        key = regexprep(string(representativeContains(ii)), '[^A-Za-z0-9]+', '_');
        mask = mask | contains(T.sampleID, key, 'IgnoreCase', true);
    end
    Tsel = T(mask,:);
end

function local_write_latex_snippets(tableDir, repBoundary, repAttack)
    texPath = fullfile(tableDir, 'latex_table_snippets.tex');
    fid = fopen(texPath, 'w');
    if fid < 0
        return;
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '%% Auto-generated compact LaTeX table snippets.\n');
    fprintf(fid, '%% Copy into the Temporal Segmentation Results section and edit captions as needed.\n\n');

    fprintf(fid, '\\begin{table}[htbp]\n\\centering\n\\small\n\\setlength{\\tabcolsep}{4pt}\n');
    fprintf(fid, '\\caption{Representative attack detection results.}\n');
    fprintf(fid, '\\label{tab:attack_detection_results}\n');
    fprintf(fid, '\\begin{tabular}{@{}lllrll@{}}\n\\toprule\n');
    fprintf(fid, 'Sample & Family & Artic. & Attack (ms) & Class & Onset method \\\\\n\\midrule\n');
    for ii = 1:height(repAttack)
        sampleName = strrep(char(repAttack.instrument(ii) + " " + repAttack.note(ii)), '_', '\\_');
        artic = strrep(char(repAttack.articulation(ii)), '_', '\\_');
        fam = strrep(char(repAttack.family(ii)), '_', '\\_');
        fprintf(fid, '%s & %s & %s & %.1f & %s & %s \\\\\n', sampleName, fam, artic, repAttack.attackDurMs(ii), char(repAttack.attackClass(ii)), char(repAttack.onsetMethod(ii)));
    end
    fprintf(fid, '\\bottomrule\n\\end{tabular}\n\\end{table}\n\n');

    fprintf(fid, '\\begin{table}[htbp]\n\\centering\n\\small\n\\setlength{\\tabcolsep}{4pt}\n');
    fprintf(fid, '\\caption{Representative temporal segmentation boundaries.}\n');
    fprintf(fid, '\\label{tab:temporal_boundaries}\n');
    fprintf(fid, '\\begin{tabular}{@{}lrrrrr@{}}\n\\toprule\n');
    fprintf(fid, 'Sample & $t_{\\mathrm{on}}$ & $t_{\\mathrm{att}}$ & $t_{\\mathrm{rel}}$ & $t_{\\mathrm{end}}$ & Release? \\\\\n');
    fprintf(fid, ' & (s) & (s) & (s) & (s) & \\\\\n\\midrule\n');
    for ii = 1:height(repBoundary)
        sampleName = strrep(char(repBoundary.instrument(ii) + " " + repBoundary.note(ii)), '_', '\\_');
        relText = 'yes';
        if ~repBoundary.hasRelease(ii)
            relText = 'no';
        end
        fprintf(fid, '%s & %.3f & %.3f & %.3f & %.3f & %s \\\\\n', sampleName, repBoundary.tOnsetSec(ii), repBoundary.tAttackEndSec(ii), repBoundary.tReleaseSec(ii), repBoundary.tNoteEndSec(ii), relText);
    end
    fprintf(fid, '\\bottomrule\n\\end{tabular}\n\\end{table}\n');
end

function local_write_readme(resultsDir)
    readmePath = fullfile(resultsDir, 'README_temporal_segmentation_outputs.txt');
    fid = fopen(readmePath, 'w');
    if fid < 0
        return;
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, 'Temporal segmentation V27 output guide\n');
    fprintf(fid, '======================================\n\n');
    fprintf(fid, 'tables/boundary_table.csv: onset, attack end, release start, and note end for every analyzed sample.\n');
    fprintf(fid, 'tables/attack_duration_table.csv: attack duration and attack classification for each sample.\n');
    fprintf(fid, 'tables/segmentation_summary_by_family.csv: averaged segmentation statistics by instrument family.\n');
    fprintf(fid, 'tables/representative_boundary_table.csv: thesis-sized boundary table for selected representative samples.\n');
    fprintf(fid, 'tables/representative_attack_duration_table.csv: thesis-sized attack-duration table for selected representative samples.\n');
    fprintf(fid, 'tables/latex_table_snippets.tex: compact LaTeX tables generated from representative rows.\n');
    fprintf(fid, 'figures/global_envelopes: normalized global envelope plots with segmentation markers.\n');
    fprintf(fid, 'figures/attack_zoom: attack-region zoom plots with onset and attack-end markers.\n');
end

function local_mkdir(p)
    if ~exist(p, 'dir')
        mkdir(p);
    end
end
