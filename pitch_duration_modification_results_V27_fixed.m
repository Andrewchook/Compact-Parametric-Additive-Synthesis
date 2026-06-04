%% pitch_duration_modification_results_V27.m
% Batch test script for thesis section:
%   \section{Pitch and Duration Modification Results}
%
% Purpose:
%   Test whether the compact V27 parameter model can synthesize tones at
%   new durations and pitches beyond the original analyzed recording.
%
% Required on the MATLAB path:
%   vib_analyze_harmonics_analysis_V27.m
%   vib_analyze_harmonics_resynthesize_V27.m
%
% Main outputs:
%   pitch_duration_results_V27/audio/*.wav
%   pitch_duration_results_V27/figures/duration_envelopes/*.png
%   pitch_duration_results_V27/figures/pitch_spectrograms/*.png
%   pitch_duration_results_V27/figures/pitch_timbre_trends/*.png
%   pitch_duration_results_V27/tables/all_tests.csv
%   pitch_duration_results_V27/tables/duration_tests.csv
%   pitch_duration_results_V27/tables/small_pitch_tests.csv
%   pitch_duration_results_V27/tables/octave_pitch_tests.csv
%   pitch_duration_results_V27/tables/summary_by_group.csv
%   pitch_duration_results_V27/tables/listening_notes_template.csv
%   pitch_duration_results_V27/tables/failure_table.csv
%
% How to use:
%   1) Put this script in the same MATLAB folder as the V27 analysis and
%      resynthesis files.
%   2) Update audioFiles to the source notes you want to test.
%   3) Optional: update realTargetMap if you have real recordings at the
%      target pitches. These are used only for feature comparison and
%      spectrogram figure labels.
%   4) Run the script. Then listen to the generated wav files and fill in
%      listening_notes_template.csv.
%
% Notes for the thesis section:
%   - Duration tests use targetDurationSec while holding targetF0Hz equal to
%     the analyzed source f0.
%   - Pitch tests use targetF0Hz = sourceF0Hz*2^(semitones/12) while keeping
%     duration fixed.
%   - durationMode='preserveAttackRelease' is the main thesis condition
%     because it keeps attack/release timing closer to the analyzed note and
%     stretches/compresses the middle body region.
%   - durationMode='stretchEnvelope' can be added to cfg.durationModes if you
%     want a direct comparison against uniform time stretching.

clear; close all; clc;

%% ---------------- User settings ----------------
cfg = struct();
cfg.resultsDir = fullfile(pwd, 'pitch_duration_results_V27');
cfg.numHarmonics = 15;
cfg.figureVisible = 'off';       % 'off' for batch mode, 'on' for interactive viewing
cfg.saveResynthAudio = true;
cfg.savePerSampleMat = true;
cfg.makeFiguresForAll = true;
cfg.playPreview = false;

% Duration tests. 1.0 is omitted because the baseline row already covers it.
cfg.durationScales = [0.50 0.75 1.50 2.00];
cfg.durationModes = "preserveAttackRelease";
% To compare uniform envelope stretching too, use:
% cfg.durationModes = ["preserveAttackRelease" "stretchEnvelope"];

% Pitch tests. Small shifts test nearby-note generalization. Octave shifts
% test whether one analyzed note can represent a wider range.
cfg.smallPitchSemitones = [-2 -1 1 2];
cfg.octavePitchSemitones = [-12 12];

% Safety setting for octave-up tests. If the highest modeled harmonic is far
% above Nyquist after pitch scaling, the synthesis can become misleading.
% The script still runs, but it records the warning in the table.
cfg.maxAllowedTopHarmonicFracNyquist = 0.95;

% Spectrogram settings for thesis figures.
cfg.maxSpectrogramHz = 8000;
cfg.specWinMs = 46;
cfg.specHopMs = 10;
cfg.specNfft = 4096;
cfg.specDynRangeDb = 80;

% Feature settings for the timbre-change table.
cfg.highBandSplitHz = 3000;
cfg.rolloffPercent = 0.95;
cfg.envelopeSmoothMs = 10;

% Representative sources. These are intentionally a smaller set than the
% full objective-results batch so the modification test stays manageable.
% Add or remove files as needed.
audioFiles = [ ...
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\tuba_A2_long_mezzo-forte_vibrato.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trombone_As3_15_mezzo-forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trumpet_A3_1_fortissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trumpet_A4_15_fortissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\bass-clarinet_A2_1_pianissimo_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\violin_A4_1_fortissimo_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\violin_A5_1_pianissimo_arco-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\cello_Fs2_long_mezzo-piano_non-vibrato.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\double-bass_A1_025_piano_pizz-normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\guitar_C3_very-long_forte_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\mandolin_D4_very-long_piano_normal.mp3"
"C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\banjo_A4_very-long_forte_normal.mp3"
];

% Optional real target recordings for pitch-scaling comparisons.
% These are not required for the synthetic pitch-shift test. They only let
% the script compute feature differences and produce source/synth/target
% spectrogram figures when a matching target exists.
realTargetMap = table( ...
    string.empty(0,1), zeros(0,1), string.empty(0,1), ...
    'VariableNames', {'sourceContains','semitones','targetFile'});

realTargetMap = [realTargetMap; local_target_row("trumpet_A3_1_fortissimo", 1,  "C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trumpet_As3_1_forte_normal.mp3")];
realTargetMap = [realTargetMap; local_target_row("trumpet_A3_1_fortissimo", 12, "C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\trumpet_A4_15_fortissimo_normal.mp3")];
realTargetMap = [realTargetMap; local_target_row("bass-clarinet_A2_1_pianissimo", 1,  "C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\bass-clarinet_As2_1_pianissimo_normal.mp3")];
realTargetMap = [realTargetMap; local_target_row("violin_A4_1_fortissimo", 12, "C:\Users\Andre\OneDrive\Documents\MATLAB\Validated_test_audio\violin_A5_1_pianissimo_arco-normal.mp3")];

%% ---------------- Output folders ----------------
audioDir = fullfile(cfg.resultsDir, 'audio');
tableDir = fullfile(cfg.resultsDir, 'tables');
matDir = fullfile(cfg.resultsDir, 'mat');
logDir = fullfile(cfg.resultsDir, 'logs');
durationFigDir = fullfile(cfg.resultsDir, 'figures', 'duration_envelopes');
pitchSpecFigDir = fullfile(cfg.resultsDir, 'figures', 'pitch_spectrograms');
pitchTrendFigDir = fullfile(cfg.resultsDir, 'figures', 'pitch_timbre_trends');

local_mkdir(cfg.resultsDir);
local_mkdir(audioDir);
local_mkdir(tableDir);
local_mkdir(matDir);
local_mkdir(logDir);
local_mkdir(durationFigDir);
local_mkdir(pitchSpecFigDir);
local_mkdir(pitchTrendFigDir);

%% ---------------- V27 analysis and resynthesis options ----------------
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

baseSynthOpts = struct();
baseSynthOpts.resynthNormalize = true;
baseSynthOpts.resynthPeak = 0.95;
baseSynthOpts.resynthUsePhaseIntegral = true;
baseSynthOpts.scaleFmWithPitch = true;
baseSynthOpts.noiseEnable = false;
baseSynthOpts.playAudio = false;
baseSynthOpts.saveAudio = cfg.saveResynthAudio;
baseSynthOpts.plot_waveform = false;
baseSynthOpts.plot_amfm = false;
baseSynthOpts.plot_harmonic_controls = false;

%% ---------------- Batch run ----------------
rows = repmat(local_empty_result_row(), 0, 1);
failRows = repmat(local_empty_failure_row(), 0, 1);

fprintf('Pitch/duration modification V27 test started.\n');
fprintf('Results folder: %s\n', cfg.resultsDir);

for ii = 1:numel(audioFiles)
    audioPath = string(audioFiles(ii));
    [~, sampleStem, ext] = fileparts(audioPath);
    sampleName = string(sampleStem) + string(ext);
    safeStem = local_safe_name(sampleStem);

    fprintf('\n[%d/%d] %s\n', ii, numel(audioFiles), audioPath);

    if ~isfile(audioPath)
        failRows(end+1) = local_failure_row(ii, sampleName, audioPath, 'missing_file', 'Source audio file was not found.'); %#ok<SAGROW>
        fprintf('  Skipped: file not found.\n');
        continue;
    end

    try
        analysisArgs = local_struct_to_name_value_cell(analysisOpts);
        S = vib_analyze_harmonics_analysis_V27(audioPath, analysisArgs{:});
        params = S.params;
        sourceF0 = local_get_scalar(params, 'f0Hz', local_get_scalar(S, 'f0Hz', NaN));
        sourceDur = local_get_source_duration(params, S);
        sourceFs = local_get_scalar(params, 'sourceFs', local_get_scalar(S, 'fs', NaN));
        sourceX = local_get_audio_vector(S);

        if ~isfinite(sourceF0) || sourceF0 <= 0
            error('Invalid source f0.');
        end
        if ~isfinite(sourceDur) || sourceDur <= 0
            error('Invalid source duration.');
        end

        sourceFeatures = local_audio_features(sourceX, sourceFs, cfg);
        sourceEnvStats = local_envelope_stats(sourceX, sourceFs, cfg.envelopeSmoothMs);

        %% Baseline compact resynthesis at original pitch and duration
        synthOpts = baseSynthOpts;
        synthOpts.targetF0Hz = sourceF0;
        synthOpts.targetDurationSec = sourceDur;
        synthOpts.durationMode = 'preserveAttackRelease';
        synthOpts.outputPath = fullfile(audioDir, safeStem + "__baseline_V27.wav");
        synthArgs = local_struct_to_name_value_cell(synthOpts);
        [yBase, Dbase] = vib_analyze_harmonics_resynthesize_V27(params, synthArgs{:});
        baseFeatures = local_synth_features(Dbase, yBase, cfg);
        baseEnvStats = local_envelope_stats(yBase, Dbase.fs, cfg.envelopeSmoothMs);
        baseVib = local_vibrato_summary(Dbase);

        rows(end+1) = local_result_row(ii, sampleName, audioPath, ...
            "baseline", "baseline_original_pitch_duration", "preserveAttackRelease", ...
            0, 1, sourceF0, sourceF0, sourceDur, sourceDur, numel(yBase)/Dbase.fs, ...
            synthOpts.outputPath, "", false, "", sourceFeatures, baseFeatures, ...
            sourceEnvStats, baseEnvStats, baseVib, NaN, NaN, ""); %#ok<SAGROW>

        %% Duration modification tests
        for mm = 1:numel(cfg.durationModes)
            durMode = string(cfg.durationModes(mm));
            for dd = 1:numel(cfg.durationScales)
                durScale = cfg.durationScales(dd);
                targetDur = max(0.05, sourceDur * durScale);
                label = sprintf('duration_%s_%0.2fx', durMode, durScale);

                synthOpts = baseSynthOpts;
                synthOpts.targetF0Hz = sourceF0;
                synthOpts.targetDurationSec = targetDur;
                synthOpts.durationMode = char(durMode);
                synthOpts.outputPath = fullfile(audioDir, safeStem + "__" + local_safe_name(label) + "_V27.wav");
                synthArgs = local_struct_to_name_value_cell(synthOpts);
                [yMod, Dmod] = vib_analyze_harmonics_resynthesize_V27(params, synthArgs{:});

                modFeatures = local_synth_features(Dmod, yMod, cfg);
                modEnvStats = local_envelope_stats(yMod, Dmod.fs, cfg.envelopeSmoothMs);
                modVib = local_vibrato_summary(Dmod);

                rows(end+1) = local_result_row(ii, sampleName, audioPath, ...
                    "duration", string(label), durMode, ...
                    0, durScale, sourceF0, sourceF0, sourceDur, targetDur, numel(yMod)/Dmod.fs, ...
                    synthOpts.outputPath, "", false, "", sourceFeatures, modFeatures, ...
                    sourceEnvStats, modEnvStats, modVib, ...
                    modFeatures.centroidHz - baseFeatures.centroidHz, ...
                    modFeatures.highBandFrac - baseFeatures.highBandFrac, ""); %#ok<SAGROW>

                if cfg.makeFiguresForAll
                    figPath = fullfile(durationFigDir, safeStem + "__" + local_safe_name(label) + "_envelope.png");
                    local_plot_duration_envelopes(sourceX, sourceFs, yMod, Dmod.fs, ...
                        sampleName, string(label), sourceDur, targetDur, figPath, cfg);
                end

                if cfg.savePerSampleMat
                    matPath = fullfile(matDir, safeStem + "__" + local_safe_name(label) + ".mat");
                    save(matPath, 'audioPath', 'S', 'params', 'yMod', 'Dmod', 'modFeatures', 'modEnvStats', 'modVib', '-v7.3');
                end
            end
        end

        %% Pitch scaling tests
        pitchCases = [ ...
            local_pitch_case_rows("pitch_small", cfg.smallPitchSemitones); ...
            local_pitch_case_rows("pitch_octave", cfg.octavePitchSemitones) ...
        ];

        pitchRowsForTrend = repmat(local_empty_result_row(), 0, 1);
        for pp = 1:numel(pitchCases)
            testGroup = pitchCases(pp).group;
            semitones = pitchCases(pp).semitones;
            pitchRatio = 2^(semitones/12);
            targetF0 = sourceF0 * pitchRatio;
            label = sprintf('%s_%+d_st', testGroup, semitones);
            warnText = local_pitch_warning(sourceF0, targetF0, cfg.numHarmonics, Dbase.fs, cfg);

            synthOpts = baseSynthOpts;
            synthOpts.targetF0Hz = targetF0;
            synthOpts.targetDurationSec = sourceDur;
            synthOpts.durationMode = 'preserveAttackRelease';
            synthOpts.outputPath = fullfile(audioDir, safeStem + "__" + local_safe_name(label) + "_V27.wav");
            synthArgs = local_struct_to_name_value_cell(synthOpts);
            [yPitch, Dpitch] = vib_analyze_harmonics_resynthesize_V27(params, synthArgs{:});

            pitchFeatures = local_synth_features(Dpitch, yPitch, cfg);
            pitchEnvStats = local_envelope_stats(yPitch, Dpitch.fs, cfg.envelopeSmoothMs);
            pitchVib = local_vibrato_summary(Dpitch);

            [realTargetFile, hasTarget] = local_find_real_target(realTargetMap, audioPath, semitones);
            realCompared = false;
            realFeatureDeltaCentroid = NaN;
            realFeatureDeltaHighBand = NaN;
            if hasTarget && isfile(realTargetFile)
                [targetAudio, targetFs] = audioread(realTargetFile);
                targetAudio = local_mono(targetAudio);
                targetFeatures = local_audio_features(targetAudio, targetFs, cfg);
                realFeatureDeltaCentroid = pitchFeatures.centroidHz - targetFeatures.centroidHz;
                realFeatureDeltaHighBand = pitchFeatures.highBandFrac - targetFeatures.highBandFrac;
                realCompared = true;
            else
                targetAudio = [];
                targetFs = NaN;
            end

            newRow = local_result_row(ii, sampleName, audioPath, ...
                testGroup, string(label), "preserveAttackRelease", ...
                semitones, 1, sourceF0, targetF0, sourceDur, sourceDur, numel(yPitch)/Dpitch.fs, ...
                synthOpts.outputPath, realTargetFile, realCompared, warnText, sourceFeatures, pitchFeatures, ...
                sourceEnvStats, pitchEnvStats, pitchVib, ...
                pitchFeatures.centroidHz - baseFeatures.centroidHz, ...
                pitchFeatures.highBandFrac - baseFeatures.highBandFrac, "");
            rows(end+1) = newRow; %#ok<SAGROW>
            pitchRowsForTrend(end+1) = newRow; %#ok<SAGROW>

            if cfg.makeFiguresForAll
                figPath = fullfile(pitchSpecFigDir, safeStem + "__" + local_safe_name(label) + "_spectrogram.png");
                local_plot_pitch_spectrograms(sourceX, sourceFs, yPitch, Dpitch.fs, ...
                    targetAudio, targetFs, sampleName, string(label), sourceF0, targetF0, realTargetFile, figPath, cfg);
            end

            if cfg.savePerSampleMat
                matPath = fullfile(matDir, safeStem + "__" + local_safe_name(label) + ".mat");
                save(matPath, 'audioPath', 'S', 'params', 'yPitch', 'Dpitch', 'pitchFeatures', 'pitchEnvStats', 'pitchVib', 'realTargetFile', '-v7.3');
            end
        end

        if cfg.makeFiguresForAll && ~isempty(pitchRowsForTrend)
            figPath = fullfile(pitchTrendFigDir, safeStem + "__pitch_timbre_trend.png");
            local_plot_pitch_timbre_trend(pitchRowsForTrend, sampleName, figPath, cfg);
        end

        if cfg.playPreview
            fprintf('  Playing baseline preview...\n');
            soundsc(yBase, Dbase.fs);
            pause(numel(yBase)/Dbase.fs + 0.25);
        end

        fprintf('  Completed.\n');

    catch ME
        failRows(end+1) = local_failure_row(ii, sampleName, audioPath, ME.identifier, ME.message); %#ok<SAGROW>
        fprintf('  Failed: %s\n', ME.message);
    end
end

%% ---------------- Write tables ----------------
if isempty(rows)
    allTable = struct2table(repmat(local_empty_result_row(), 0, 1));
else
    allTable = struct2table(rows);
end

if isempty(failRows)
    failureTable = struct2table(repmat(local_empty_failure_row(), 0, 1));
else
    failureTable = struct2table(failRows);
end

writetable(allTable, fullfile(tableDir, 'all_tests.csv'));
writetable(allTable(strcmp(allTable.testGroup, "duration"), :), fullfile(tableDir, 'duration_tests.csv'));
writetable(allTable(strcmp(allTable.testGroup, "pitch_small"), :), fullfile(tableDir, 'small_pitch_tests.csv'));
writetable(allTable(strcmp(allTable.testGroup, "pitch_octave"), :), fullfile(tableDir, 'octave_pitch_tests.csv'));
writetable(failureTable, fullfile(tableDir, 'failure_table.csv'));

summaryTable = local_summary_by_group(allTable);
writetable(summaryTable, fullfile(tableDir, 'summary_by_group.csv'));

listeningTemplate = allTable(:, {'sampleName','testGroup','testLabel','audioPath','sourceF0Hz','targetF0Hz','semitones','targetDurationSec'});
listeningTemplate.listeningNotes = strings(height(listeningTemplate),1);
listeningTemplate.instrumentIdentityPreserved = strings(height(listeningTemplate),1);
listeningTemplate.brightnessChange = strings(height(listeningTemplate),1);
listeningTemplate.naturalnessRating_1to5 = NaN(height(listeningTemplate),1);
writetable(listeningTemplate, fullfile(tableDir, 'listening_notes_template.csv'));

fprintf('\nDone. Wrote tables to:\n  %s\n', tableDir);
fprintf('Generated audio is in:\n  %s\n', audioDir);

%% ======================= Local helper functions =======================

function args = local_struct_to_name_value_cell(opts)
%LOCAL_STRUCT_TO_NAME_VALUE_CELL Convert an options struct to V27 name-value inputs.
% V27 uses MATLAB arguments-block name-value syntax, so passing the whole
% options struct as a second positional argument causes:
%   "Invalid argument at position 2. Function requires 0 to 1 positional input(s)."
% This helper converts opts.field = value into {'field', value, ...}.

names = fieldnames(opts);
args = cell(1, 2*numel(names));
for ii = 1:numel(names)
    val = opts.(names{ii});

    % Several V27 options are declared as char in the arguments block.
    % Convert scalar strings so paths and modes validate correctly.
    if isstring(val) && isscalar(val)
        val = char(val);
    end

    args{2*ii - 1} = names{ii};
    args{2*ii} = val;
end
end

function row = local_target_row(sourceContains, semitones, targetFile)
row = table(string(sourceContains), semitones, string(targetFile), ...
    'VariableNames', {'sourceContains','semitones','targetFile'});
end

function cases = local_pitch_case_rows(groupName, semitoneList)
cases = repmat(struct('group', string(groupName), 'semitones', 0), numel(semitoneList), 1);
for i = 1:numel(semitoneList)
    cases(i).group = string(groupName);
    cases(i).semitones = semitoneList(i);
end
end

function row = local_empty_result_row()
row = struct();
row.sampleIndex = NaN;
row.sampleName = "";
row.sourceFile = "";
row.testGroup = "";
row.testLabel = "";
row.durationMode = "";
row.semitones = NaN;
row.durationScale = NaN;
row.sourceF0Hz = NaN;
row.targetF0Hz = NaN;
row.pitchRatio = NaN;
row.sourceDurationSec = NaN;
row.targetDurationSec = NaN;
row.actualDurationSec = NaN;
row.durationErrorMs = NaN;
row.audioPath = "";
row.realTargetFile = "";
row.realTargetCompared = false;
row.warning = "";
row.sourceCentroidHz = NaN;
row.synthCentroidHz = NaN;
row.centroidDeltaVsSourceHz = NaN;
row.centroidDeltaVsBaselineHz = NaN;
row.sourceHighBandFrac = NaN;
row.synthHighBandFrac = NaN;
row.highBandDeltaVsSource = NaN;
row.highBandDeltaVsBaseline = NaN;
row.synthRolloffHz = NaN;
row.synthRms = NaN;
row.synthPeak = NaN;
row.sourceAttackRiseMs = NaN;
row.synthAttackRiseMs = NaN;
row.attackRiseDeltaMs = NaN;
row.sourceReleaseMs = NaN;
row.synthReleaseMs = NaN;
row.releaseDeltaMs = NaN;
row.medianAmRateHz = NaN;
row.medianFmRateHz = NaN;
row.medianFmDepthHz = NaN;
row.medianFmDepthCentsApprox = NaN;
row.medianVibratoStartSec = NaN;
row.medianVibratoEndSec = NaN;
row.numActiveAmHarmonics = NaN;
row.numActiveFmHarmonics = NaN;
row.userListeningNotes = "";
end

function row = local_result_row(sampleIndex, sampleName, sourceFile, testGroup, testLabel, durationMode, ...
    semitones, durationScale, sourceF0, targetF0, sourceDur, targetDur, actualDur, ...
    audioPath, realTargetFile, realTargetCompared, warningText, sourceFeatures, synthFeatures, ...
    sourceEnvStats, synthEnvStats, vib, centroidDeltaVsBaselineHz, highBandDeltaVsBaseline, userNotes)
row = local_empty_result_row();
row.sampleIndex = sampleIndex;
row.sampleName = string(sampleName);
row.sourceFile = string(sourceFile);
row.testGroup = string(testGroup);
row.testLabel = string(testLabel);
row.durationMode = string(durationMode);
row.semitones = semitones;
row.durationScale = durationScale;
row.sourceF0Hz = sourceF0;
row.targetF0Hz = targetF0;
row.pitchRatio = targetF0 / max(sourceF0, eps);
row.sourceDurationSec = sourceDur;
row.targetDurationSec = targetDur;
row.actualDurationSec = actualDur;
row.durationErrorMs = 1000 * (actualDur - targetDur);
row.audioPath = string(audioPath);
row.realTargetFile = string(realTargetFile);
row.realTargetCompared = logical(realTargetCompared);
row.warning = string(warningText);
row.sourceCentroidHz = sourceFeatures.centroidHz;
row.synthCentroidHz = synthFeatures.centroidHz;
row.centroidDeltaVsSourceHz = synthFeatures.centroidHz - sourceFeatures.centroidHz;
row.centroidDeltaVsBaselineHz = centroidDeltaVsBaselineHz;
row.sourceHighBandFrac = sourceFeatures.highBandFrac;
row.synthHighBandFrac = synthFeatures.highBandFrac;
row.highBandDeltaVsSource = synthFeatures.highBandFrac - sourceFeatures.highBandFrac;
row.highBandDeltaVsBaseline = highBandDeltaVsBaseline;
row.synthRolloffHz = synthFeatures.rolloffHz;
row.synthRms = synthFeatures.rms;
row.synthPeak = synthFeatures.peak;
row.sourceAttackRiseMs = sourceEnvStats.attackRiseMs;
row.synthAttackRiseMs = synthEnvStats.attackRiseMs;
row.attackRiseDeltaMs = synthEnvStats.attackRiseMs - sourceEnvStats.attackRiseMs;
row.sourceReleaseMs = sourceEnvStats.releaseMs;
row.synthReleaseMs = synthEnvStats.releaseMs;
row.releaseDeltaMs = synthEnvStats.releaseMs - sourceEnvStats.releaseMs;
row.medianAmRateHz = vib.medianAmRateHz;
row.medianFmRateHz = vib.medianFmRateHz;
row.medianFmDepthHz = vib.medianFmDepthHz;
row.medianFmDepthCentsApprox = vib.medianFmDepthCentsApprox;
row.medianVibratoStartSec = vib.medianVibratoStartSec;
row.medianVibratoEndSec = vib.medianVibratoEndSec;
row.numActiveAmHarmonics = vib.numActiveAmHarmonics;
row.numActiveFmHarmonics = vib.numActiveFmHarmonics;
row.userListeningNotes = string(userNotes);
end

function row = local_empty_failure_row()
row = struct('sampleIndex', NaN, 'sampleName', "", 'sourceFile', "", 'identifier', "", 'message', "");
end

function row = local_failure_row(sampleIndex, sampleName, sourceFile, identifier, message)
row = local_empty_failure_row();
row.sampleIndex = sampleIndex;
row.sampleName = string(sampleName);
row.sourceFile = string(sourceFile);
row.identifier = string(identifier);
row.message = string(message);
end

function local_mkdir(folderPath)
if ~exist(folderPath, 'dir')
    mkdir(folderPath);
end
end

function safe = local_safe_name(nameIn)
safe = regexprep(string(nameIn), '[^A-Za-z0-9_\-\+\.]+', '_');
safe = regexprep(safe, '_+', '_');
safe = strip(safe, '_');
if strlength(safe) == 0
    safe = "unnamed";
end
end

function value = local_get_scalar(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    tmp = s.(fieldName);
    if isnumeric(tmp) || islogical(tmp)
        tmp = tmp(:);
        if ~isempty(tmp)
            value = double(tmp(1));
        end
    end
end
end

function x = local_get_audio_vector(S)
if isfield(S, 'x') && ~isempty(S.x)
    x = local_mono(S.x);
else
    x = [];
end
end

function x = local_mono(x)
if isempty(x)
    x = [];
    return;
end
if size(x,2) > 1
    x = mean(x, 2);
end
x = x(:);
x(~isfinite(x)) = 0;
end

function sourceDur = local_get_source_duration(params, S)
sourceDur = NaN;
fsSrc = local_get_scalar(params, 'sourceFs', NaN);
Nsrc = local_get_scalar(params, 'sourceNumSamples', NaN);
if isfinite(fsSrc) && fsSrc > 0 && isfinite(Nsrc) && Nsrc > 0
    sourceDur = Nsrc / fsSrc;
    return;
end
sourceDur = local_get_scalar(params, 'sourceDurationSec', NaN);
if (~isfinite(sourceDur) || sourceDur <= 0) && isfield(S, 'x') && isfield(S, 'fs') && S.fs > 0
    sourceDur = numel(S.x) / S.fs;
end
end

function warningText = local_pitch_warning(sourceF0, targetF0, K, fs, cfg)
warningText = "";
if ~isfinite(targetF0) || targetF0 <= 0 || ~isfinite(fs) || fs <= 0
    return;
end
topHarm = K * targetF0;
nyq = fs / 2;
if topHarm > cfg.maxAllowedTopHarmonicFracNyquist * nyq
    warningText = sprintf('Highest requested harmonic %.1f Hz is near/above Nyquist %.1f Hz.', topHarm, nyq);
end
if targetF0 > sourceF0 * 1.5
    warningText = strjoin([warningText, "large upward extrapolation; spectral envelope may become too bright/thin"], " ");
elseif targetF0 < sourceF0 / 1.5
    warningText = strjoin([warningText, "large downward extrapolation; spectral envelope may become too dark/heavy"], " ");
end
warningText = strip(warningText);
end

function [realTargetFile, hasTarget] = local_find_real_target(realTargetMap, sourceFile, semitones)
realTargetFile = "";
hasTarget = false;
if isempty(realTargetMap) || height(realTargetMap) == 0
    return;
end
src = string(sourceFile);
for i = 1:height(realTargetMap)
    if contains(src, realTargetMap.sourceContains(i), 'IgnoreCase', true) && realTargetMap.semitones(i) == semitones
        realTargetFile = realTargetMap.targetFile(i);
        hasTarget = strlength(realTargetFile) > 0;
        return;
    end
end
end

function features = local_synth_features(D, y, cfg)
features = local_audio_features(y, D.fs, cfg);
% For additive output, use the model harmonic tracks for a cleaner centroid
% when available. This avoids the FFT centroid being dominated by silence.
if isfield(D, 'harm') && ~isempty(D.harm)
    [centroidHz, highBandFrac, rolloffHz] = local_harmonic_track_features(D, cfg);
    if isfinite(centroidHz)
        features.centroidHz = centroidHz;
    end
    if isfinite(highBandFrac)
        features.highBandFrac = highBandFrac;
    end
    if isfinite(rolloffHz)
        features.rolloffHz = rolloffHz;
    end
end
end

function features = local_audio_features(x, fs, cfg)
x = local_mono(x);
features = struct('centroidHz', NaN, 'highBandFrac', NaN, 'rolloffHz', NaN, 'rms', NaN, 'peak', NaN);
if isempty(x) || ~isfinite(fs) || fs <= 0
    return;
end
features.rms = sqrt(mean(x.^2));
features.peak = max(abs(x));

% Use middle 80 percent to reduce onset/release effects in timbre features.
N = numel(x);
i1 = max(1, floor(0.10*N));
i2 = max(i1, ceil(0.90*N));
xMid = x(i1:i2);
if numel(xMid) < 32 || max(abs(xMid)) <= 0
    return;
end

nfft = 2^nextpow2(max(numel(xMid), 1024));
w = local_hann(numel(xMid));
X = abs(fft(xMid(:).*w(:), nfft)).^2;
X = X(1:floor(nfft/2)+1);
f = (0:numel(X)-1).' * fs / nfft;
valid = f <= min(fs/2, cfg.maxSpectrogramHz);
f = f(valid);
X = X(valid);
if sum(X) <= 0
    return;
end
features.centroidHz = sum(f .* X) / sum(X);
features.highBandFrac = sum(X(f >= cfg.highBandSplitHz)) / sum(X);
cs = cumsum(X) / sum(X);
idx = find(cs >= cfg.rolloffPercent, 1, 'first');
if ~isempty(idx)
    features.rolloffHz = f(idx);
end
end

function [centroidHz, highBandFrac, rolloffHz] = local_harmonic_track_features(D, cfg)
centroidHz = NaN;
highBandFrac = NaN;
rolloffHz = NaN;
if ~isfield(D, 'harm') || isempty(D.harm)
    return;
end
freqVals = [];
ampVals = [];
for k = 1:numel(D.harm)
    hk = D.harm(k);
    if ~isfield(hk, 'Ak') || ~isfield(hk, 'fkHz') || isempty(hk.Ak) || isempty(hk.fkHz)
        continue;
    end
    Ak = abs(hk.Ak(:));
    fk = hk.fkHz(:);
    n = min(numel(Ak), numel(fk));
    if n < 1
        continue;
    end
    Ak = Ak(1:n);
    fk = fk(1:n);
    valid = isfinite(Ak) & isfinite(fk) & Ak > 0;
    if ~any(valid)
        continue;
    end
    ampVals(end+1,1) = median(Ak(valid)); %#ok<AGROW>
    freqVals(end+1,1) = median(fk(valid)); %#ok<AGROW>
end
if isempty(ampVals) || sum(ampVals) <= 0
    return;
end
centroidHz = sum(freqVals .* ampVals) / sum(ampVals);
highBandFrac = sum(ampVals(freqVals >= cfg.highBandSplitHz)) / sum(ampVals);
[fsort, idx] = sort(freqVals);
asort = ampVals(idx);
cs = cumsum(asort) / sum(asort);
idxR = find(cs >= cfg.rolloffPercent, 1, 'first');
if ~isempty(idxR)
    rolloffHz = fsort(idxR);
end
end

function stats = local_envelope_stats(x, fs, smoothMs)
x = local_mono(x);
stats = struct('attackRiseMs', NaN, 'releaseMs', NaN, 'onsetSec', NaN, 'peakSec', NaN, 'endSec', NaN);
if isempty(x) || ~isfinite(fs) || fs <= 0
    return;
end
env = local_smooth_abs_envelope(x, fs, smoothMs);
if isempty(env) || max(env) <= 0
    return;
end
env = env ./ max(env);
t = (0:numel(env)-1).' / fs;
idxPeak = find(env == max(env), 1, 'first');
stats.peakSec = t(idxPeak);
idxOn = find(env >= 0.05, 1, 'first');
idxEnd = find(env >= 0.05, 1, 'last');
if ~isempty(idxOn), stats.onsetSec = t(idxOn); end
if ~isempty(idxEnd), stats.endSec = t(idxEnd); end
prePeak = 1:idxPeak;
idx10 = find(env(prePeak) >= 0.10, 1, 'first');
idx90 = find(env(prePeak) >= 0.90, 1, 'first');
if ~isempty(idx10) && ~isempty(idx90) && idx90 >= idx10
    stats.attackRiseMs = 1000 * (t(idx90) - t(idx10));
end
postPeak = idxPeak:numel(env);
idxRelStartLocal = find(env(postPeak) <= 0.70, 1, 'first');
idxRelEndLocal = find(env(postPeak) <= 0.10, 1, 'first');
if ~isempty(idxRelStartLocal) && ~isempty(idxRelEndLocal) && idxRelEndLocal >= idxRelStartLocal
    idxRelStart = postPeak(idxRelStartLocal);
    idxRelEnd = postPeak(idxRelEndLocal);
    stats.releaseMs = 1000 * (t(idxRelEnd) - t(idxRelStart));
end
end

function env = local_smooth_abs_envelope(x, fs, smoothMs)
x = local_mono(x);
if isempty(x)
    env = [];
    return;
end
win = max(1, round((smoothMs/1000) * fs));
env = movmean(abs(x), win);
end

function vib = local_vibrato_summary(D)
vib = struct('medianAmRateHz', NaN, 'medianFmRateHz', NaN, 'medianFmDepthHz', NaN, ...
    'medianFmDepthCentsApprox', NaN, 'medianVibratoStartSec', NaN, 'medianVibratoEndSec', NaN, ...
    'numActiveAmHarmonics', 0, 'numActiveFmHarmonics', 0);
if ~isfield(D, 'harm') || isempty(D.harm)
    return;
end
amRate = [];
fmRate = [];
fmDepth = [];
fmDepthCents = [];
vStart = [];
vEnd = [];
for k = 1:numel(D.harm)
    hk = D.harm(k);
    carrierHz = NaN;
    if isfield(hk, 'fkHz') && ~isempty(hk.fkHz)
        carrierHz = median(hk.fkHz(isfinite(hk.fkHz)));
    end
    if isfield(hk, 'amModel') && isstruct(hk.amModel)
        rate = local_get_scalar(hk.amModel, 'freqHz', NaN);
        depth = abs(local_get_scalar(hk.amModel, 'amp', 0));
        if isfinite(rate) && rate > 0 && depth > 0
            amRate(end+1) = rate; %#ok<AGROW>
        end
    end
    if isfield(hk, 'fmModel') && isstruct(hk.fmModel)
        rate = local_get_scalar(hk.fmModel, 'freqHz', NaN);
        depth = abs(local_get_scalar(hk.fmModel, 'amp', 0));
        if isfinite(rate) && rate > 0 && depth > 0
            fmRate(end+1) = rate; %#ok<AGROW>
            fmDepth(end+1) = depth; %#ok<AGROW>
            if isfinite(carrierHz) && carrierHz > 0
                fmDepthCents(end+1) = 1200 * log2((carrierHz + depth) / carrierHz); %#ok<AGROW>
            end
        end
    end
    if isfield(hk, 'vibratoWindow') && isstruct(hk.vibratoWindow)
        st = local_get_scalar(hk.vibratoWindow, 'targetStartSec', NaN);
        en = local_get_scalar(hk.vibratoWindow, 'targetEndSec', NaN);
        if isfinite(st), vStart(end+1) = st; end %#ok<AGROW>
        if isfinite(en), vEnd(end+1) = en; end %#ok<AGROW>
    end
end
if ~isempty(amRate), vib.medianAmRateHz = median(amRate); end
if ~isempty(fmRate), vib.medianFmRateHz = median(fmRate); end
if ~isempty(fmDepth), vib.medianFmDepthHz = median(fmDepth); end
if ~isempty(fmDepthCents), vib.medianFmDepthCentsApprox = median(fmDepthCents); end
if ~isempty(vStart), vib.medianVibratoStartSec = median(vStart); end
if ~isempty(vEnd), vib.medianVibratoEndSec = median(vEnd); end
vib.numActiveAmHarmonics = numel(amRate);
vib.numActiveFmHarmonics = numel(fmRate);
end

function local_plot_duration_envelopes(xSource, fsSource, yMod, fsMod, sampleName, label, sourceDur, targetDur, figPath, cfg)
fig = figure('Visible', cfg.figureVisible, 'Color', 'w', 'Position', [100 100 900 450]);
sourceEnv = local_smooth_abs_envelope(xSource, fsSource, cfg.envelopeSmoothMs);
modEnv = local_smooth_abs_envelope(yMod, fsMod, cfg.envelopeSmoothMs);
if max(sourceEnv) > 0, sourceEnv = sourceEnv ./ max(sourceEnv); end
if max(modEnv) > 0, modEnv = modEnv ./ max(modEnv); end
tSource = (0:numel(sourceEnv)-1).' / fsSource;
tMod = (0:numel(modEnv)-1).' / fsMod;
plot(tSource, sourceEnv, 'LineWidth', 1.2, 'DisplayName', sprintf('Source %.2f s', sourceDur)); hold on;
plot(tMod, modEnv, 'LineWidth', 1.2, 'DisplayName', sprintf('Synth %.2f s', targetDur));
grid on;
xlabel('Time (s)');
ylabel('Normalized amplitude envelope');
title(sprintf('%s: %s', sampleName, label), 'Interpreter', 'none');
legend('Location', 'best');
local_save_figure(fig, figPath);
end

function local_plot_pitch_spectrograms(xSource, fsSource, yPitch, fsPitch, targetAudio, targetFs, sampleName, label, sourceF0, targetF0, realTargetFile, figPath, cfg)
fig = figure('Visible', cfg.figureVisible, 'Color', 'w', 'Position', [100 100 1100 650]);
if isempty(targetAudio)
    tiledlayout(2,1, 'TileSpacing', 'compact');
else
    tiledlayout(3,1, 'TileSpacing', 'compact');
end
nexttile;
local_plot_spectrogram_panel(xSource, fsSource, cfg);
title(sprintf('Source: %.1f Hz', sourceF0), 'Interpreter', 'none');
nexttile;
local_plot_spectrogram_panel(yPitch, fsPitch, cfg);
title(sprintf('V27 pitch-scaled: %.1f Hz (%s)', targetF0, label), 'Interpreter', 'none');
if ~isempty(targetAudio)
    nexttile;
    local_plot_spectrogram_panel(targetAudio, targetFs, cfg);
    title(sprintf('Real target: %s', realTargetFile), 'Interpreter', 'none');
end
sgtitle(sprintf('%s', sampleName), 'Interpreter', 'none');
local_save_figure(fig, figPath);
end

function local_plot_spectrogram_panel(x, fs, cfg)
x = local_mono(x);
if isempty(x) || ~isfinite(fs) || fs <= 0
    text(0.5, 0.5, 'No audio'); axis off;
    return;
end
winN = max(32, round(cfg.specWinMs/1000 * fs));
hopN = max(1, round(cfg.specHopMs/1000 * fs));
nfft = max(cfg.specNfft, 2^nextpow2(winN));
[Sdb, f, t] = local_simple_spectrogram_db(x, fs, winN, hopN, nfft);
maxF = min(cfg.maxSpectrogramHz, fs/2);
mask = f <= maxF;
imagesc(t, f(mask), Sdb(mask,:));
axis xy;
ylabel('Frequency (Hz)');
xlabel('Time (s)');
caxis([-cfg.specDynRangeDb 0]);
colorbar;
end

function [Sdb, f, t] = local_simple_spectrogram_db(x, fs, winN, hopN, nfft)
x = local_mono(x);
N = numel(x);
if N < winN
    x(end+1:winN) = 0;
    N = numel(x);
end
numFrames = 1 + floor((N - winN) / hopN);
w = local_hann(winN);
S = zeros(floor(nfft/2)+1, numFrames);
for m = 1:numFrames
    idx = (1:winN) + (m-1)*hopN;
    frame = x(idx) .* w;
    X = abs(fft(frame, nfft));
    S(:,m) = X(1:floor(nfft/2)+1);
end
S = S ./ max(S(:) + eps);
Sdb = 20*log10(S + eps);
f = (0:size(S,1)-1).' * fs / nfft;
t = ((0:numFrames-1)*hopN + winN/2) / fs;
end

function local_plot_pitch_timbre_trend(rows, sampleName, figPath, cfg)
T = struct2table(rows);
fig = figure('Visible', cfg.figureVisible, 'Color', 'w', 'Position', [100 100 750 450]);
plot(T.semitones, T.centroidDeltaVsBaselineHz, 'o-', 'LineWidth', 1.2, 'DisplayName', 'Centroid delta vs baseline'); hold on;
yyaxis right;
plot(T.semitones, T.highBandDeltaVsBaseline, 's-', 'LineWidth', 1.2, 'DisplayName', 'High-band fraction delta');
grid on;
xlabel('Pitch shift (semitones)');
ylabel('High-band fraction delta');
yyaxis left;
ylabel('Centroid delta (Hz)');
title(sprintf('Pitch-scaling timbre trend: %s', sampleName), 'Interpreter', 'none');
legend('Location', 'best');
local_save_figure(fig, figPath);
end

function w = local_hann(N)
if N <= 1
    w = ones(max(1,N),1);
else
    n = (0:N-1).';
    w = 0.5 - 0.5*cos(2*pi*n/(N-1));
end
end

function local_save_figure(fig, figPath)
[folderPath,~,~] = fileparts(figPath);
local_mkdir(folderPath);
try
    exportgraphics(fig, figPath, 'Resolution', 200);
catch
    saveas(fig, figPath);
end
close(fig);
end

function summaryTable = local_summary_by_group(T)
if isempty(T) || height(T) == 0
    summaryTable = table();
    return;
end
groups = unique(T.testGroup, 'stable');
summaryTable = table();
for i = 1:numel(groups)
    g = groups(i);
    mask = strcmp(T.testGroup, g);
    row = table( ...
        g, ...
        sum(mask), ...
        local_nanmean(abs(T.durationErrorMs(mask))), ...
        local_nanmean(T.centroidDeltaVsSourceHz(mask)), ...
        local_nanmean(abs(T.centroidDeltaVsSourceHz(mask))), ...
        local_nanmean(T.highBandDeltaVsSource(mask)), ...
        local_nanmedian(T.medianAmRateHz(mask)), ...
        local_nanmedian(T.medianFmRateHz(mask)), ...
        local_nanmedian(T.medianFmDepthHz(mask)), ...
        'VariableNames', {'testGroup','numTests','meanAbsDurationErrorMs', ...
        'meanCentroidDeltaVsSourceHz','meanAbsCentroidDeltaVsSourceHz', ...
        'meanHighBandDeltaVsSource','medianAmRateHz','medianFmRateHz','medianFmDepthHz'});
    summaryTable = [summaryTable; row]; %#ok<AGROW>
end
end

function y = local_nanmean(x)
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = mean(x);
end
end

function y = local_nanmedian(x)
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = median(x);
end
end
