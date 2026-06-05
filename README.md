# Compact Parametric Additive Synthesis

This repository contains MATLAB code for analyzing and resynthesizing single-note musical instrument recordings using a compact additive synthesis model. The project was developed as part of a thesis on parametric musical instrument synthesis, with an emphasis on harmonic amplitude envelopes, vibrato amplitude modulation (AM), vibrato frequency modulation (FM), and parameter reduction.

The main goal is to represent real instrument tones with a smaller set of parameters than raw audio while preserving important time-varying characteristics such as attack shape, harmonic envelope evolution, and vibrato behavior.

## Project Overview

The synthesis model represents a musical tone as a sum of harmonic sinusoidal components:

```text
y(t) = sum_k A_k(t) cos(theta_k(t))
```

where each harmonic has a reconstructed amplitude envelope and optional AM/FM vibrato controls. The analysis stage extracts compact parameters from an input audio file, and the resynthesis stage reconstructs a new audio waveform using only those parameters.

The repository includes:

* Harmonic analysis and compact parameter extraction
* Additive resynthesis from stored parameters
* Batch resynthesis for multiple instrument samples
* Pitch and duration modification experiments
* Envelope recovery and temporal segmentation result scripts
* Objective metric and parameter reduction result scripts
* V27 stable thesis-version scripts and V30 experimental scripts

## Repository Contents

| File                                                                | Purpose                                                                                                                                    |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `vib_analyze_harmonics_analysis_V27.m`                              | Main V27 analysis script. Extracts harmonic envelopes, AM/FM vibrato tracks, frequency information, and compact resynthesis parameters.    |
| `vib_analyze_harmonics_resynthesize_V27.m`                          | Main V27 resynthesis script. Reconstructs audio from the compact parameter structure.                                                      |
| `vib_analyze_harmonics_analysis_V27_synthetic_validation_patched.m` | Patched V27 analysis version used for synthetic validation tests.                                                                          |
| `vib_analyze_harmonics_analysis_V30.m`                              | Experimental newer analysis version. Used for continued parameter-reduction development.                                                   |
| `vib_analyze_harmonics_resynthesize_V30.m`                          | Experimental newer resynthesis version paired with the V30 analysis file.                                                                  |
| `batch_resynthesize_dataset_V1.m`                                   | Batch script for analyzing and resynthesizing multiple audio files. Useful for generating full, AM-only, FM-only, and no-vibrato variants. |
| `vib_analyze_harmonics_test_resynth_V4.m`                           | Small test script for running analysis, resynthesis, playback, plotting, and metric comparison on individual examples.                     |
| `real_instrument_resynthesis_results_V27.m`                         | Batch result script for real instrument resynthesis tests. Generates tables, figures, and resynthesized audio for listening.               |
| `envelope_results_V27.m`                                            | Evaluates how well the compact envelope model represents the measured harmonic envelopes.                                                  |
| `temporal_segmentation_results_V27.m`                               | Evaluates onset, attack, release, and note-end segmentation behavior.                                                                      |
| `pitch_duration_modification_results_V27_fixed.m`                   | Tests pitch shifting and duration modification using the compact V27 parameter model.                                                      |
| `objective_parameter_original_comparison_bitrate_results_V27.m`     | Compares original audio and compact resynthesis using objective metrics and bitrate/storage estimates.                                     |

## Requirements

This project was developed in MATLAB.

Recommended MATLAB toolboxes:

* Signal Processing Toolbox
* Audio Toolbox, if available
* Optimization Toolbox, optional for some nonlinear fitting options

The code expects input audio files such as `.wav` or `.mp3` recordings of isolated single-note instrument tones.

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/Andrewchook/Compact-Parametric-Additive-Synthesis
.git
cd Compact-Parametric-Additive-Synthesis

```


### 2. Open MATLAB in the repository folder

In MATLAB, navigate to the repository folder and add it to the path:

```matlab
addpath(pwd)
```

### 3. Analyze a single audio file

```matlab
audioPath = "path/to/your/audio_file.wav";

analysisOpts = struct();
analysisOpts.numHarmonics = 15;
analysisOpts.f0Method = 'majority';
analysisOpts.plot_waveform = true;
analysisOpts.plot_vib_overviews = true;

S = vib_analyze_harmonics_analysis_V27(audioPath, analysisOpts);
```

The output `S` contains the original audio, estimated fundamental frequency, harmonic analysis data, envelope models, AM/FM information, and compact resynthesis parameters in:

```matlab
S.params
```

### 4. Resynthesize from compact parameters

```matlab
synthOpts = struct();
synthOpts.resynthNormalize = true;
synthOpts.resynthPeak = 0.95;
synthOpts.playAudio = true;

[ySynth, synthData] = vib_analyze_harmonics_resynthesize_V27(S.params, synthOpts);
```

To save the output audio:

```matlab
synthOpts.saveAudio = true;
synthOpts.outputPath = "resynthesized_output.wav";

[ySynth, synthData] = vib_analyze_harmonics_resynthesize_V27(S.params, synthOpts);
```

## Pitch and Duration Modification

The resynthesis function can synthesize a tone at a different duration or pitch using the stored compact parameters.

### Change duration

```matlab
synthOpts = struct();
synthOpts.targetDurationSec = 2.0;
synthOpts.durationMode = 'preserveAttackRelease';
synthOpts.resynthNormalize = true;
synthOpts.playAudio = true;

[yStretch, Dstretch] = vib_analyze_harmonics_resynthesize_V27(S.params, synthOpts);
```

### Shift pitch by semitones

```matlab
semitones = 2;
sourceF0 = S.params.f0Hz;
targetF0 = sourceF0 * 2^(semitones/12);

synthOpts = struct();
synthOpts.targetF0Hz = targetF0;
synthOpts.resynthNormalize = true;
synthOpts.playAudio = true;

[yPitch, Dpitch] = vib_analyze_harmonics_resynthesize_V27(S.params, synthOpts);
```

## Batch Result Scripts

Several scripts are included for thesis-style evaluation. These scripts generate output folders containing CSV tables, plots, audio files, and failure logs.

Before running these scripts, update the hard-coded `audioFiles` paths inside each file so they point to your local dataset.

### Real instrument resynthesis

```matlab
real_instrument_resynthesis_results_V27
```

Typical outputs:

```text
real_instrument_results_V27/
    audio/
    figures/
    mat/
    tables/
```

### Envelope model evaluation

```matlab
envelope_results_V27
```

Typical outputs:

```text
envelope_results_V27/
    figures/
    mat/
    tables/
```

### Temporal segmentation evaluation

```matlab
temporal_segmentation_results_V27
```

Typical outputs:

```text
temporal_segmentation_results_V27/
    figures/
    mat/
    tables/
```

### Pitch and duration modification tests

```matlab
pitch_duration_modification_results_V27_fixed
```

Typical outputs:

```text
pitch_duration_results_V27/
    audio/
    figures/
    logs/
    mat/
    tables/
```

### Objective metric and bitrate comparison

```matlab
objective_parameter_original_comparison_bitrate_results_V27
```

Typical outputs:

```text
objective_parameter_original_results_V27/
    tables/
    mat/
```

## Model Variants

The compact model can be evaluated using different parameter subsets:

* Full model: envelope + AM + FM
* No AM: envelope + FM only
* No FM: envelope + AM only
* Envelope only: no AM or FM vibrato model
* No vibrato: envelope-based resynthesis without vibrato modulation

These variants are useful for studying how much each parameter group contributes to perceptual quality and storage cost.

## Notes on Input Audio

The current workflow assumes the input audio is:

* A single instrument
* A single isolated note
* Mostly monophonic
* Reasonably clean, with limited background noise
* Long enough to estimate envelope and vibrato behavior

Very short notes, noisy recordings, weak harmonics, or octave errors in pitch detection may reduce analysis quality.

## Version Notes

### V27

V27 is the main stable thesis version. It includes:

* Majority-vote fundamental frequency estimation
* Per-harmonic envelope extraction
* Compact knot-based envelope storage
* Multiplicative AM modeling
* FM vibrato estimation
* Global envelope timing and segmentation
* Parameter-only additive resynthesis
* Pitch and duration modification controls

### V30

V30 is an experimental continuation of the model. It is intended for testing additional parameter-reduction ideas and should be treated as less finalized than V27 unless otherwise documented in the script comments.

## Example Minimal Workflow

```matlab
clear; close all; clc;

audioPath = "path/to/audio.wav";

analysisOpts = struct();
analysisOpts.numHarmonics = 15;
analysisOpts.f0Method = 'majority';
analysisOpts.plot_waveform = false;
analysisOpts.plot_vib_overviews = false;

S = vib_analyze_harmonics_analysis_V27(audioPath, analysisOpts);

synthOpts = struct();
synthOpts.resynthNormalize = true;
synthOpts.resynthPeak = 0.95;
synthOpts.playAudio = true;

[ySynth, synthData] = vib_analyze_harmonics_resynthesize_V27(S.params, synthOpts);

audiowrite("resynthesized_output.wav", ySynth, synthData.fs);
```

## Known Limitations

* The model is designed for isolated single-note recordings, not full musical passages.
* Pitch detection can fail for very low notes or recordings with weak fundamentals.
* The envelope model may store unnecessary points for some sounds.
* AM vibrato is often unreliable for weak harmonics and may be rejected by confidence gates.
* Octave pitch shifts can sound less natural than small semitone shifts.
* Plucked instruments may require careful attack handling because the attack can dominate the perceived timbre.
* The scripts currently contain local absolute paths that should be edited before running on another machine.

## Suggested Folder Organization

A useful local structure is:

```text
project/
    MATLAB files
    audio/
        input/
        output/
    results/
        real_instrument_results_V27/
        envelope_results_V27/
        temporal_segmentation_results_V27/
        pitch_duration_results_V27/
        objective_parameter_original_results_V27/
```

## Citation / Academic Context

This project is part of a thesis investigation into compact additive resynthesis of musical instrument tones. The code is intended for research, prototyping, and educational use.

## Author

Andrew Chook

## License

Add a license before public release. If unsure, MIT License is a common choice for open-source research code, but confirm that all included code and datasets are allowed to be shared.
