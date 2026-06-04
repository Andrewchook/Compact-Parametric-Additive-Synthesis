close all; clear; clc;
violinVibrato = "C:\Users\Andre\OneDrive\Documents\MATLAB\Violin Vibrato Samples\violin_Gs5_long_forte_molto-vibrato.mp3";
violin2 = "C:\Users\Andre\OneDrive\Desktop\Thesis\Audio Samples\Strings\Strings\violin\violin_D4_1_forte_arco-normal.mp3";
violin3 = "C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\violin_A4_1_fortissimo_arco-normal.mp3";

celloSample1 = "C:\Users\Andre\OneDrive\Desktop\Thesis\Audio Samples\Strings\Strings\cello\cello_A2_15_forte_arco-normal.mp3";

guitarSample1 = "C:\Users\Andre\OneDrive\Documents\MATLAB\guitar_Gs2_very-long_forte_normal.mp3";
guitarSample2 = "C:\Users\Andre\OneDrive\Documents\MATLAB\guitar_Gs5_very-long_forte_normal.mp3";

trumpetSample1 = "C:\Users\Andre\OneDrive\Documents\MATLAB\trumpet_Gs5_1_forte_normal.mp3";
trumpetSample2 = "C:\Users\Andre\OneDrive\Documents\MATLAB\trumpet\trumpet_A4_long_mezzo-piano_normal.mp3";

tromboneSample = "C:\Users\Andre\OneDrive\Documents\MATLAB\trombone_Gs4_1_forte_normal.mp3";
tromboneVibrato = "C:\Users\Andre\OneDrive\Documents\MATLAB\trombone_Gs4_long_forte_vibrato.mp3";

tubaSample1 = "C:\Users\Andre\OneDrive\Documents\MATLAB\tuba\tuba_A1_1_pianissimo_normal.mp3";
tubaSample2 = "C:\Users\Andre\OneDrive\Documents\MATLAB\tuba\tuba_A3_05_mezzo-piano_normal.mp3";
tubaSample3 = "C:\Users\Andre\OneDrive\Documents\MATLAB\tuba\tuba_Fs3_long_mezzo-forte_vibrato.mp3";

bassClarinetSample1 = "C:\Users\Andre\OneDrive\Documents\MATLAB\bass clarinet\bass-clarinet_A3_very-long_mezzo-piano_harmonic.mp3";

resynth = "C:\Users\Andre\OneDrive\Documents\MATLAB\note_V15_resynth.wav";

audioPath = violin3;

% Run baseline sms analysis
S_baseline = vib_sms_baseline_V3(audioPath);

% Run current version analysis model
tic
S_V27 = vib_analyze_harmonics_analysis_V27(audioPath,plot_spectrogram=true,specWinMs=100,numHarmonics=8);
S_V30 = vib_analyze_harmonics_analysis_V30(audioPath,plot_spectrogram=true,specWinMs=100,numHarmonics=8);
S = S_V27;
vib_export_params_embedded_V27(S_V27.params, "instrument_params.h", ...
    instrumentName="violin_A4", ...
    cSymbolPrefix="g_violin_A4", ...
    maxHarmonics=12);

analysisTimer = toc
resynthParams_V27 = S_V27.params;
resynthParams_V30 = S_V30.params;

slashidxs = strfind((audioPath),'\');
outpath_V27 = "resynth\V27_full_synth_" + audioPath{1}(slashidxs(end)+1:end);
outpath_V30 = "resynth\V30_full_synth_" + audioPath{1}(slashidxs(end)+1:end);

% resynthesize with current model
tic
[ySynth_V27, synthData_V27] = vib_analyze_harmonics_resynthesize_V27(resynthParams_V27,playAudio=true,outputPath=outpath_V27);
pause(numel(synthData_V27.t)/synthData_V27.fs);
[ySynth_V30, synthData_V30] = vib_analyze_harmonics_resynthesize_V30(resynthParams_V30,playAudio=true,outputPath=outpath_V30);
resynthTime = toc
ySynth=ySynth_V27;
synthData = synthData_V27;
% soundsc(S.x,S.fs); 
% pause(numel(S.t)/S.fs);
% soundsc(ySynth,synthData.fs);

N = min(numel(S.x), numel(ySynth));
t = (0:N-1).' / S.fs;
figure('Name','V15 Additive AM/FM Resynthesis','Color','w');
plot(t, S.x(1:N), 'DisplayName','Original'); hold on;
plot(t, ySynth(1:N), 'DisplayName','V15 resynth');


grid on; xlabel('Time (s)'); ylabel('Amplitude');
title('Original vs V15 additive AM/FM resynthesis');
legend('Location','best');

% Compare the vibrato tracks estimated during analysis against the
% vibrato tracks actually used by the resynthesis stage.
local_plot_vibrato_analysis_vs_resynthesis(S, synthData);

% plot(t,S_baseline.y_sms);
% legend('Location','best','SMS');



% Metrics options
metricOpts = struct();
metricOpts.params = S.params;
metricOpts.synthData = synthData;
metricOpts.currentLabel = 'V21 compact model';
% metricOpts.compareSets = {S_baseline};      % SMS or older model metric result
% metricOpts.compareLabels = {'Baseline'};
metricOpts.comparisonDisplay = 'both';

% Run metrics
M = vib_analyze_harmonics_metrics_V5_patched(S, metricOpts);

function fig = local_plot_vibrato_analysis_vs_resynthesis(S, synthData, maxHarmonics)
%LOCAL_PLOT_VIBRATO_ANALYSIS_VS_RESYNTHESIS
%   Plots analysis vibrato tracks against the controls used by resynthesis.
%   This version uses regular figure() + subplot() calls and one subplot per
%   harmonic, matching the compact analysis overview style.

if nargin < 3 || isempty(maxHarmonics)
    maxHarmonics = inf;
end

if ~isfield(S, 'harm') || isempty(S.harm) || ~isfield(synthData, 'harm') || isempty(synthData.harm)
    warning('vibTest:vibratoCompareMissingData', ...
        'Could not plot vibrato comparison because S.harm or synthData.harm is missing.');
    fig = gobjects(0);
    return;
end

K = min([numel(S.harm), numel(synthData.harm), maxHarmonics]);
if K < 1
    fig = gobjects(0);
    return;
end

% Match the regular analysis overview layout: 15 harmonics fit well in a
% 4-by-4 grid, with one unused tile when K = 15.
harmonicsPerFigure = 16;
rows = 4;
cols = 4;
numPages = ceil(K / harmonicsPerFigure);

% Get resynthesis time axis.
tSynth = local_column_or_empty(synthData, 't');
if isempty(tSynth)
    if isfield(synthData, 'y') && isfield(synthData, 'fs')
        nSynth = numel(synthData.y);
        tSynth = (0:nSynth-1).' / synthData.fs;
    else
        warning('vibTest:vibratoCompareMissingTime', ...
            'Could not plot vibrato comparison because synthData.t/y/fs are missing.');
        fig = gobjects(0);
        return;
    end
end

% If resynthesis duration changes, this maps each resynthesis sample back to
% the corresponding source-analysis time.
if isfield(synthData, 'sourceTimeMap') && numel(synthData.sourceTimeMap) == numel(tSynth)
    tSourceForSynth = synthData.sourceTimeMap(:);
else
    tSourceForSynth = tSynth;
end

% Get analysis time axis.
if isfield(S, 't') && ~isempty(S.t)
    tAnalysis = S.t(:);
elseif isfield(S, 'fs') && isfield(S, 'x')
    tAnalysis = (0:numel(S.x)-1).' / S.fs;
else
    warning('vibTest:vibratoCompareMissingTime', ...
        'Could not plot vibrato comparison because the analysis time axis is missing.');
    fig = gobjects(0);
    return;
end

fig = gobjects(numPages, 2);

for page = 1:numPages
    kStart = (page-1)*harmonicsPerFigure + 1;
    kEnd = min(K, page*harmonicsPerFigure);

    fig(page,1) = figure();
    set(fig(page,1), 'Color','w');
    for k = kStart:kEnd
        tileIdx = k - kStart + 1;
        subplot(rows, cols, tileIdx);

        hAnal = S.harm(k);
        hSynth = synthData.harm(k);
        harmNum = local_get_scalar(hSynth, 'k', k);

        amAnalysis = local_get_track(hAnal, 'am');
        amAnalysis = local_interp_track(tAnalysis, amAnalysis, tSourceForSynth);

        amSynth = local_get_track(hSynth, 'amSin');
        amSynth = local_match_length(amSynth, numel(tSynth));

        plotMask = local_zoom_mask(tSynth, amAnalysis, amSynth);
        plot(tSynth(plotMask), amAnalysis(plotMask), 'LineWidth',0.75); hold on;
        plot(tSynth(plotMask), amSynth(plotMask), '--', 'LineWidth',0.9);
        grid on;
        title(sprintf('H%d AM', harmNum));
        xlabel('s');
        ylabel('AM frac.');
        local_apply_tight_xlim(tSynth, plotMask);
    end

    fig(page,2) = figure();
    set(fig(page,2), 'Color','w');
    for k = kStart:kEnd
        tileIdx = k - kStart + 1;
        subplot(rows, cols, tileIdx);

        hAnal = S.harm(k);
        hSynth = synthData.harm(k);
        harmNum = local_get_scalar(hSynth, 'k', k);

        fmAnalysis = local_get_track(hAnal, 'vibFmHz');
        fmAnalysis = local_interp_track(tAnalysis, fmAnalysis, tSourceForSynth);

        fmSynth = local_get_track(hSynth, 'fmSinHz');
        fmSynth = local_match_length(fmSynth, numel(tSynth));

        plotMask = local_zoom_mask(tSynth, fmAnalysis, fmSynth);
        plot(tSynth(plotMask), fmAnalysis(plotMask), 'LineWidth',0.75); hold on;
        plot(tSynth(plotMask), fmSynth(plotMask), '--', 'LineWidth',0.9);
        grid on;
        title(sprintf('H%d freq', harmNum));
        xlabel('s');
        ylabel('Hz');
        local_apply_tight_xlim(tSynth, plotMask);
    end
end
end

function mask = local_zoom_mask(t, yAnalysis, ySynth)
% Prefer the valid analysis region so that long zero-valued resynthesis
% controls do not force the x-axis to show the whole note.
mask = isfinite(t) & isfinite(yAnalysis);
if nnz(mask) < 2
    mask = isfinite(t) & (isfinite(yAnalysis) | isfinite(ySynth));
end
if nnz(mask) < 2
    mask = isfinite(t);
end
end

function local_apply_tight_xlim(t, mask)
if nnz(mask) < 2
    return;
end
tMin = min(t(mask));
tMax = max(t(mask));
if ~isfinite(tMin) || ~isfinite(tMax) || tMax <= tMin
    return;
end
pad = 0.05 * (tMax - tMin);
xlim([tMin-pad, tMax+pad]);
end

function y = local_interp_track(tIn, yIn, tOut)
yIn = local_match_length(yIn, numel(tIn));
if isempty(yIn) || all(~isfinite(yIn))
    y = nan(numel(tOut), 1);
    return;
end
valid = isfinite(tIn) & isfinite(yIn);
if nnz(valid) < 2
    y = nan(numel(tOut), 1);
    return;
end
[tValid, uniqueIdx] = unique(tIn(valid), 'stable');
yValid = yIn(valid);
yValid = yValid(uniqueIdx);
y = interp1(tValid, yValid, tOut(:), 'linear', NaN);
end

function y = local_get_track(s, fieldName)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    y = s.(fieldName)(:);
else
    y = [];
end
end

function y = local_column_or_empty(s, fieldName)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    y = s.(fieldName)(:);
else
    y = [];
end
end

function y = local_match_length(y, N)
if isempty(y)
    y = nan(N, 1);
    return;
end
y = y(:);
if numel(y) == N
    return;
end
if numel(y) > N
    y = y(1:N);
else
    y = [y; nan(N-numel(y), 1)]; %#ok<AGROW>
end
end

function value = local_get_scalar(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName) && isscalar(s.(fieldName)) && isfinite(s.(fieldName))
    value = s.(fieldName);
end
end
