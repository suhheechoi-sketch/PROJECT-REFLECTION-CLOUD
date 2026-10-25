# PROJECT: REFLECTION — T/A DEMO v1.0

2026-10-25 Web game #5 수정: [원인·웹 빌드·검증 결과](docs/WEB_BUILD_FIX_20261025.md). 물리 프레임 대기 오류를 수정했고, iPad용 터치 **새 게임** 버튼을 추가했습니다. PR 빌드 성공과 실제 Pages 배포/기기 검증은 보고서에서 구분합니다.

신규 기본 시작 씬은 `scenes/ta_demo.tscn`입니다. T-01~T-04 → A 로비 → A-01 → A-02 → A-03 → A 회로 복구 단말기 E → 데모 종료를 연결했습니다. 광선은 기존 `laser_system.gd`의 실제 충돌·반사 계산을 사용합니다.

**검증 상태:** Godot **4.7.2.stable.official.ed1daf0bf**에서 자동 검사와 X11/OpenGL 렌더링 검사를 수행했습니다. 수동 키보드·마우스 전체 완주, Windows 실행, 실제 오디오 청취 및 시연 영상 촬영은 미검증입니다. 자동 테스트 성공을 수동 플레이 완료로 표시하지 않습니다.

- [구현·테스트·미완료 보고](docs/TA_DEMO_REPORT.md)
- [최종 좌표·각도·충돌 보정](docs/TA_DEMO_VALIDATED_GEOMETRY.md)
- [실행 및 2~3분 촬영 경로 / 정답](docs/TA_DEMO_CAPTURE_ROUTE.md)
- [업로드 설계도 원본](docs/ta_demo_evidence/source_blueprint.pdf) · [원본 제안 JSON](data/ta_demo/proposed_layout.json) · [적용 JSON](data/ta_demo/layout.json)

## 실행

Godot **4.7.2 Standard / Compatibility**로 `project.godot`을 열고 F6이 아닌 **F5(프로젝트 실행)**를 누르십시오. 또는:

```bash
godot --path .
```

Linux에 포함 엔진이 있다면 `./PLAY_REFLECTION.sh`로 실행할 수 있습니다. 별도 설치 엔진은 `GODOT=/path/to/godot-4.7.2 ./PLAY_REFLECTION.sh`로 지정합니다. Windows의 기존 `PLAY_REFLECTION.bat`도 새 기본 씬을 시작합니다. 엔진 바이너리는 Git/소스 ZIP에 포함되지 않습니다. 기존 로컬 `tools/godot-4.7.2/`를 보존하거나 Godot 4.7.2를 별도로 준비하십시오.

완료 단계는 `user://reflection_ta_demo_v1.json`에 저장됩니다. 재시작 시 다음 미완료 퍼즐 입구에서 L-07을 휴대 상태로 복구합니다. 미완료 퍼즐의 거울 각도·부분 조사 시간은 다시 설정합니다. 종료 후 재실행하면 종료 화면이 유지되며 Shift+R로 새로 시작합니다.

## 조작

| 입력 | 동작 |
|---|---|
| WASD / 마우스 / 좌클릭 유지 | 이동 / 조준 / L-07 발사 |
| E | 단말기, 가까운 거울 선택·해제, 콘솔 진입 |
| 휠 / Shift+휠 | 일반 거울 15° / 1° 회전 |
| A-01/A-02 콘솔 E → 클릭 | 원격 거울 선택; 휠 회전; Esc 종료 |
| A-02 거치대 E / F | 동일 L-07 장착·회수 / 지속 조사 정지·재개 |
| 레일 손잡이 E → 휠 | 현장에서 0.25m 이동; A-02는 제어 R 선행 |
| R / Shift+R | 현재 미완료 퍼즐 재시도 / 전체 초기화 |
| H·F1 / L / M / Tab / Esc | 도움말 / 기록 / 미니맵 / 탐색 지도 / 일시 정지 |

T-04 수신기만으로 A 문이 열리지 않습니다. **검사 종료 단말기 E**가 필요합니다. A-03의 **R-O1 → R-O2 → R-N**은 READY만 만들며, **A 복구실 단말기 E**가 RESTORED와 데모 종료를 실행합니다. 선택 R-U는 필수가 아닙니다.

## 자동 검사

```bash
GODOT=./tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 ./VERIFY_REFLECTION.sh --import
# 실제 디스플레이가 있는 환경에서 렌더링 증거 PNG 생성:
godot --path . --script res://tests/ta_demo_test.gd -- --visual-review
```

Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\VERIFY_REFLECTION.ps1 -VisualReview`. Windows 실행 자체는 이번 Linux 검증에 포함되지 않습니다.

## 기존 시설 보존

`scenes/main.tscn`, `scripts/a01_lab.gd`, 기존 B~F/H 코드 및 잠긴 `assets/v4_0/`는 보존했습니다. 기존 전체 시설은 `godot --path . res://scenes/main.tscn`으로 별도 실행할 수 있습니다. 해당 씬의 이전 진행 규칙은 T/A 데모의 READY/E/RESTORED 규칙과 별개입니다. 기존 A-02는 배치 설정을 추가해 새 맵에서도 같은 탈착·소유권·레일 로직을 사용합니다.

기준 문서: [AGENTS](AGENTS.md), [통합 확정 규칙](docs/INTEGRATED_DIRECTIVE_20261025.md), [아트](ART_BIBLE.md), [치수](SCALE_GUIDE.md), [장치](DEVICE_CATALOG.md). 독립된 v6.2 원본은 저장소에서 확인되지 않았으며, 통합 지시서에 인용된 확정 규칙을 적용했습니다. 이전 작업 기록은 [A-02 보고](docs/A02_DOCKING_REPORT.md), [v4 보고](docs/V4_QUALITY_REPORT.md)를 참고하십시오.

## iPad Safari / Web

터치 조작, Godot 4.7.2 웹 빌드, GitHub Actions/Pages 활성화와 검증 범위는 [웹 배포 안내](docs/WEB_IPAD.md)를 참조하세요. PR 빌드 결과는 Actions의 `reflection-web` 산출물이며, 실제 Pages 배포 성공 여부는 별도로 확인해야 합니다.
