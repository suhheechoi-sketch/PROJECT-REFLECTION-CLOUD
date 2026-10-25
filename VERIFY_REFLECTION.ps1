param([switch]$VisualReview)

$ErrorActionPreference = 'Stop'
$enginePath = Join-Path $PSScriptRoot 'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Bundled Godot 4.7.2 engine is missing.' }
$validationPath = Join-Path $PSScriptRoot 'tools/validation'
New-Item -ItemType Directory -Force -Path $validationPath | Out-Null

function Assert-CleanGodotRun([string]$logPath, [int]$processExitCode) {
    if ($processExitCode -ne 0) { throw "Godot failed with exit code $processExitCode. See $logPath" }
    # The restricted Windows runner cannot read the host certificate store. This exact
    # Godot startup diagnostic is external to the project; keep all other errors fatal.
    $runtimeIssues = Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR:|^ERROR:|^FAIL:' |
        Where-Object { $_.Line.Trim() -ne 'ERROR: Failed to read the root certificate store.' }
    if ($runtimeIssues) {
        throw "Godot reported an error. See $logPath"
    }
}

$smokeLog = Join-Path $validationPath 'runtime_smoke.log'
& $enginePath --headless --path $PSScriptRoot --quit-after 4 --log-file $smokeLog
Assert-CleanGodotRun $smokeLog $LASTEXITCODE

$testNames = @('optics_math_test', 'progression_state_test', 'stage_catalog_test', 'tutorial_flow_test', 'quality_pass_test', 'energy_flow_test', 'navigation_test', 'exploration_test', 'room_visibility_test', 'camera_motion_test', 'a01_lab_test', 'a02_docking_test', 'camera_ui_test', 'optical_control_test', 'optical_rules_v51_test', 'representative_puzzle_test', 'asset_lock_test', 'ta_demo_test', 'ta_navigation_test', 'ta_controls_checkpoint_test', 'touch_controls_test', 'console_interaction_test', 'beam_observer_test')
foreach ($testName in $testNames) {
    $testLog = Join-Path $validationPath "$testName.log"
    & $enginePath --headless --path $PSScriptRoot --script "res://tests/$testName.gd" --log-file $testLog
    Assert-CleanGodotRun $testLog $LASTEXITCODE
}

if ($VisualReview) {
    $observerLog = Join-Path $validationPath 'beam_observer_render.log'
    & $enginePath --path $PSScriptRoot --script res://tests/beam_observer_test.gd --log-file $observerLog -- --visual-review
    Assert-CleanGodotRun $observerLog $LASTEXITCODE
    New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot 'work/validation') | Out-Null
    $consoleLog = Join-Path $validationPath 'console_interaction_render.log'
    & $enginePath --path $PSScriptRoot --script res://tests/console_interaction_test.gd --log-file $consoleLog -- --visual-review
    Assert-CleanGodotRun $consoleLog $LASTEXITCODE
    $taReviewLog = Join-Path $validationPath 'ta_demo_render.log'
    & $enginePath --path $PSScriptRoot --script res://tests/ta_demo_test.gd --log-file $taReviewLog -- --visual-review
    Assert-CleanGodotRun $taReviewLog $LASTEXITCODE
    $reviewLog = Join-Path $validationPath 'visual_review.log'
    & $enginePath --path $PSScriptRoot --script res://tests/visual_review.gd --log-file $reviewLog
    Assert-CleanGodotRun $reviewLog $LASTEXITCODE
    $a01ReviewLog = Join-Path $validationPath 'a01_visual_review.log'
    & $enginePath --path $PSScriptRoot --script res://tests/a01_visual_review.gd --log-file $a01ReviewLog
    Assert-CleanGodotRun $a01ReviewLog $LASTEXITCODE
    $cameraReviewLog = Join-Path $validationPath 'camera_ui_render.log'
    & $enginePath --path $PSScriptRoot --script res://tests/camera_ui_test.gd --log-file $cameraReviewLog
    Assert-CleanGodotRun $cameraReviewLog $LASTEXITCODE
    $remoteReviewLog = Join-Path $validationPath 'optical_control_render.log'
    & $enginePath --path $PSScriptRoot --script res://tests/optical_control_test.gd --log-file $remoteReviewLog
    Assert-CleanGodotRun $remoteReviewLog $LASTEXITCODE
}
Write-Output "PASS: runtime startup and all $($testNames.Count) validation suites."
