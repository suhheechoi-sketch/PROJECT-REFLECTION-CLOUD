# PROJECT: REFLECTION

## 통합 지시서 적용 — A-01 / A-02 개발

최신 기준: [첨부 통합 지시서](docs/INTEGRATED_DIRECTIVE_20261025.md) · [구현·대조·검증·남은 작업](docs/A02_DOCKING_REPORT.md).

- A-01: 콘솔 근처 E로 즉시 조작, 클릭 선택, 휠 15° / Shift+휠 1°, Esc 종료. V는 기존 보기 전용이며 조작 진입에 필요하지 않습니다.
- A-02: A-01 완료 후 A 남서 셀에서 일반 거울 2개를 콘솔로 설정 → L-07 거치대 E로 지속 조사 → 제어 수신기 활성 후 현장 레일 손잡이 E·휠로 거울 1개 이동. 거치대 F로 조사 중지/재개, E로 회수. R은 A-02 재시도, Shift+R은 전체 초기화입니다.
- 개발용 바로 실행: `godot --path . --script res://tests/play_a02.gd`. 일반 시작은 기존 T-01입니다.
- Linux 자동 검사: `GODOT=/path/to/godot ./VERIFY_REFLECTION.sh` (초기 에디터 가져오기는 `--import` 옵션). 이번 클라우드 검증은 설치된 4.6.3 headless에서 수행했습니다. 기준 4.7.2와 시각 검수는 미검증입니다.
- 전체 완성이 아닙니다. A-03, 복구 콘솔 E 흐름, 전체 진행 저장, 후반 구역은 남아 있습니다. 기존 B/C 접근을 보존하기 위해 A-01의 조기 A 회로 복구 콜백은 아직 유지됩니다.

## v4.0 품질 개선 1차 (이전 기록)

실행 엔진: **Godot 4.7.2.stable.official.ed1daf0bf**, Compatibility. 엔진을 변경하지 않았습니다.

- 침상이 있는 격리실에서 이동 → 신원 단말기 E → 북쪽 지급대에서 광원 획득 → 반사 학습으로 진행합니다.
- T/A/H에 산업 시설 외장·64px 표면·안내 표식, 장치별 프레임·눈금·상태 링을 추가했습니다.
- A-01은 두 번 반사·오른쪽 입사·1.2초 조사를 요구합니다. A 복구 후 B와 C는 원하는 순서로 탐색합니다.
- G-01은 굴절과 ×2 증폭을 수행하며 광량 상한은 300%입니다. 전체 B/C 스테이지 완성을 의미하지 않습니다.
- **R: 현재 구역 복원(완료 회로 보존), Shift+R: 전체 초기화, L: 시스템 로그.** 튜토리얼의 R은 전체 재시작입니다.

규격: [아트](ART_BIBLE.md) · [치수](SCALE_GUIDE.md) · [장치](DEVICE_CATALOG.md) · [에셋](ASSET_MANIFEST.md) · [레벨](LEVEL_DESIGN.md).

실행·검증·남은 범위: [v4.0 작업 보고](docs/V4_QUALITY_REPORT.md). 작업 전 Git 태그는 `v3-before-v4-quality`입니다.

Godot 4 기반의 PS1 로우폴리 산업 공포·광학 퍼즐 프로토타입입니다. 방과 장치는 현재 코드로 생성하는 회색상자이며, 진행할 전체 설계는 [시설·스테이지 설계](docs/LEVEL_DESIGN_AND_FACILITY_MAP.md)와 [v3 마스터 프롬프트](docs/MASTER_PROMPT_V3.md)를 참고하세요.

## 실행

1. 이 프로젝트 폴더에서 `PLAY_REFLECTION.bat`을 더블클릭하세요.
2. Godot 게임 창이 열리면 WASD로 움직여 튜토리얼을 시작하세요.

실행 파일은 `tools/godot-4.7.2/` 안에 포함되어 있습니다. Godot 에디터 설치나 프로젝트 가져오기는 필요하지 않습니다. 수동 실행은 PowerShell에서 아래처럼 할 수 있습니다.

```powershell
.\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe --path .
```

## 조작

- WASD: 이동
- 마우스: 바닥 조준
- 좌클릭 유지: 광선 발사
- E: 단말기 사용 또는 가까운 광학 장치 선택
- 마우스 휠: 선택한 장치를 15° 회전
- Tab: 구역과 해금 상태 보기
- H 또는 F1: 조작 도움말 다시 보기
- R: 현재 구역 복원 / Shift+R: 전체 초기화
- L: 시스템 로그
- Esc: 일시 정지

## 현재 플레이할 수 있는 내용

- T-01 이동·상호작용, T-02 수신기 조사, T-03 한 번 반사, T-04 두 거울 반사 튜토리얼
- 격리실, 튜토리얼 통로, 중앙 배광실 기본 공간과 A/B/C를 향한 물리 게이트
- 플레이어 이동·조준, 광선 반사·굴절·분산·분기, 색상/방향/최소 광량/지속 시간 수신기
- 진행 상태, 주요 문 해금 조건, 한국어 목표 UI, 장치 강조와 활성 수신기 표시

A-02 거치 퍼즐은 이번에 추가했습니다. A-03 이후 스테이지와 기록·폐쇄·최종 구역은 미완성입니다. 최신 지시서에 따라 DIRECTOR 보스전은 제외하며 추가 엔딩은 미확정입니다. 현재 상태는 [v4.0 작업 보고](docs/V4_QUALITY_REPORT.md), 이전 상태는 [v3 분석 기록](docs/IMPLEMENTATION_GAP_ANALYSIS.md)을 참고하세요.

## 자동 검증

프로젝트 폴더에서 아래 명령을 실행하면 포함된 Godot 검증을 실행합니다.

```powershell
& .\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/optics_math_test.gd
& .\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/progression_state_test.gd
& .\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/stage_catalog_test.gd
& .\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/tutorial_flow_test.gd
```
