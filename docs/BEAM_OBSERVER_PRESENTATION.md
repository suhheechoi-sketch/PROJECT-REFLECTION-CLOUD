# 레이저 관측 · 장치/환경/UI 개선

## 범위와 출처

기준 main은 PR #6 병합 `85dd79c32650b03dfb33c66567478bdb9fa319e6`이다. [사용자 요청문](beam_observer_source/user_request.txt)을 작업 요청으로, [첨부 PDF](beam_observer_source/design_and_camera_guide.pdf)를 사용자가 지정한 디자인/기술 참고 자료로 구분했다. PDF의 콘셉트 이미지를 실행 캡처나 검증 결과로 취급하지 않았다. `AGENTS.md`, README, 루트 미술·치수·장치·레벨·에셋 규칙, docs의 기존 통합 지시·T/A 보정/검증 기록을 대조했다. 독립 v6.2 원문이 추가로 발견됐다는 뜻은 아니다.

Godot **4.7.2.stable.official.ed1daf0bf / Standard / Compatibility** 유지. 별도 브랜치에서 작업하며 main에 직접 병합하지 않는다. 기본 실행은 계속 `scenes/ta_demo.tscn`이다.

## 수정 파일

| 영역 | 파일 |
|---|---|
| 추적/수신 데이터 | `scripts/laser_system.gd`, `scripts/optical_device.gd`, `scripts/a02_lab.gd` |
| 실제 관측 카메라 | `scenes/beam_observer.tscn`, `scripts/beam_observer.gd` |
| PC/모바일 선택 | `scenes/input_preferences.tscn`, `scripts/input_preferences.gd` |
| T/A 통합·외장·완료 효과 | `scripts/ta_demo.gd`, `scripts/ta_console_station.gd`, `scripts/touch_controls.gd`, `scripts/puzzle_feedback.gd`, `assets/presentation_v1/industrial_details.gd` |
| 검증 | `tests/beam_observer_test.gd`, `tests/web_pack_check.gd`, `tests/web_smoke.py`, `tests/web_visual_review.py`, `VERIFY_REFLECTION.ps1` |
| 문서/자산 기록 | README, ASSET_MANIFEST, 이 보고서, 첨부 원본과 실제 화면/로그 |

## 구현

### 실제 광선 결과를 읽는 관측창

- `ReflectionLaser.observation_snapshot()`은 **기존 `_trace()`가 계산하고 실제 렌더러가 사용하는 같은 세그먼트**의 복사본이다. 관측 카메라에는 별도 레이캐스트가 없다.
- 데이터: from/to, channel/energy, source_id, branch_id, segment_index, terminal, reflection_count, path_length, did_hit, collision_type, collider_id, receiver_accepted, receiver_active.
- `receive_laser()`는 기존 조건을 그대로 검사하고 bool을 반환한다. 거부 조건/에너지/방향/반사 횟수/충전 시간/래치에는 변경이 없다. 이 반환값으로 **분기별** 수락 여부를 기록한다. 같은 수신기에 다른 유효 광선이 닿았다는 이유로 거부된 가지까지 CHARGING으로 표시하지 않는다.
- 스플리터는 `/T`, `/R`, 프리즘은 `/red`, `/green`, `/blue` 분기 ID를 전달한다. 부모 분기를 마지막 종점으로 오인하지 않고 실제 계산된 말단 분기를 선택한다. 기존 65m/8회 상호작용/24개 분기 제한, Snell/반사/50:50 규칙은 유지한다.
- 선택 우선순위: 플레이어 → 수신기 실제 접촉 → 실제 충돌 → 에너지 → 경로 길이 → 안정된 분기 ID. 같은 우선순위 대상은 0.35초 잠금으로 전환을 안정화한다. A02 거치 광선은 해당 방에 관여할 때만 후보로 사용한다.
- 화면 밖 판정은 메인 Camera3D의 투영/뒤쪽 판정과 20px 안전 여백을 사용한다. 진입 약 0.1초/화면 안 복귀 약 0.15초 지연으로 경계 깜빡임을 완화한다. 유효 경로가 없으면 즉시 숨긴다.
- 발사 중단 시 마지막 실제 프레임을 **0.8초** 보존하고 마지막 0.25초에 페이드한다. 콘솔·일시정지·설정/도움말/지도·데모 종료 중에는 즉시 숨긴다. 메인 카메라는 광선을 따라 이동하지 않는다.
- 최대 거리 종료는 `RANGE LIMIT / NO CONTACT`, 실제 수신 상태는 CHARGING/ACTIVE/REJECTED로 구분한다. 도달하지 않은 수신기를 목표로 삼거나 예상 정답 경로를 표시하지 않는다.

### 진짜 보조 카메라와 정보 노출 제한

`scenes/beam_observer.tscn` / `scripts/beam_observer.gd`: PanelContainer → TextureRect + **320×180 SubViewport + Camera3D**, gameplay와 동일 World3D. 마지막 구간 시작점과 종점의 0.35/0.65 가중 중심과 직교 구도로 실제 종점/직전 경로를 함께 담는다.

동일 월드의 일반 광학 장치/광선은 main 전용 렌더 레이어에 둔다. 관측용 레이어에는 **실제로 접촉한 말단 장치와 직전 접점 장치의 메시/재질을 공유하는 시각 인스턴스**, 마지막 실제 세그먼트, 실제 종점 표시만 둔다. 콜라이더·광학 장치·진행 상태를 복제하지 않는다. 이로써 관측 카메라 구도에 우연히 들어온 이웃 방의 미접촉 수신기를 보여주지 않는다. 메인 뷰와 A02 콘솔의 cull mask에도 관측 전용 인스턴스가 새지 않도록 처리했다.

관측창은 넓은 화면에서 미니맵 왼쪽의 우측 상단 빈 영역에 배치한다. 좁은 논리 화면에서는 미니맵 영역을 임시 대체하고 종료 시 복원한다. 클릭/터치는 월드 선택/발사로 전달하지 않는다.

### 비용 제한과 2D 대체

- 월드/메시/재질을 공유하며 두 번째 게임 월드나 물리 공간을 만들지 않는다.
- 320×180, MSAA 없음, positional shadow atlas 없음, 렌더 요청 목표 **12Hz** (`UPDATE_ONCE`). 숨김·발사 중단 유지 구간에는 렌더 요청 중단.
- 미접촉 광학 장치를 관측 패스에서 제외한다. 환경 장식/눈금은 MultiMesh로 묶고 새 장식의 그림자는 끈다.
- 설정의 **저사양 관측**은 실제 종점 XYZ, 마지막 구간 길이, 채널/에너지/반사 횟수/상태를 표시하는 2D 데이터 패널이다. 2D 선택 시 보조 카메라 렌더링을 중단한다. 이 모드에 가짜 카메라 영상을 넣지 않았다.
- 12Hz는 설정된 요청 빈도다. **실제 iPad FPS·발열·메모리·배터리 목표 달성을 측정한 결과가 아니다.** 전체 게임 FPS와 관측창 FPS를 혼동하지 않는다.

### 장치·환경·UI

- 새 시각 자산 `assets/presentation_v1/industrial_details.gd`: L07 금속 하우징/발광 렌즈/상태등, 거울 축/눈금/반사면 표식, 수신 렌즈/방향 화살표/상태색, 레일 캐리지/클램프 상태등. 휴대/거치 L07의 **기존 동일 소유권·광원 원점** 유지.
- 콘솔: 기존 금속/CRT 외장에 배선·스위치·스캔 라인 추가. A01/A02/A03 콘솔 좌표와 조작은 유지.
- T/A 외곽 배관, 안전 띠, A의 제한된 산화/마모 장식. A 바닥 명도를 조금 올려 장치가 어둠에 묻히지 않게 했다. 추가 장식에 물리/광학 콜라이더는 없다.
- Noto Sans KR 가변 폰트의 실제 기본 축이 Thin(100)이었다. 지원되는 OpenType **정수 wght 태그**로 550을 지정했다. 본문/안내 약 10% 확대, HUD 줄바꿈/짙은 배경/윤곽과 터치 28px 글씨 적용. 겹치는 상시 장치 ID는 숨기고 근접/선택 정보에서 이름을 제공한다.
- 기본 T/A 탐색의 V 전체 보기를 제거했다. **T 근접 직접 조작, A 콘솔 자동 카메라, 선택/회전/빈 공간 해제/Esc 복귀는 유지**한다. 기본 실행에서 사용하지 않는 보존용 `main.tscn`의 과거 회귀 도구까지 재작성하지 않았다.

### 실제 완료 이벤트의 피드백

`scripts/puzzle_feedback.gd`: 실제 수신기 활성화 → 렌즈/링 발광과 기존 전자음 → 케이블 펄스 → 잠금 LED → 얇은 문 외장/잠금장치 이동과 생성 PCM 기계음. A02 제어 수신기는 레일 손잡이로 연결하고, 부분 순서형 수신기는 국소 피드백만 준다. 잘못된 A03 순서는 활성 상태가 즉시 취소되어 성공 연출을 내지 않는다.

문 충돌 해제/진행 시점은 원래 `sync_demo()`가 그대로 소유한다. 연출을 기다리도록 게이트 조건을 늦추지 않았다. 문 외장은 **충돌 없는 얇은 시각 인스턴스**만 움직인다. 재시도는 남은 펄스/외장 연출을 정리한다. 신규 DIRECTOR 대사·추격·점프스케어·스토리 이벤트는 추가하지 않았다.

### PC / MOBILE

`scenes/input_preferences.tscn` / `scripts/input_preferences.gd`: 첫 실행 시 COMPUTER / MOBILE 선택. COMPUTER는 터치 UI를 완전히 숨기고 기존 WASD·마우스·E·휠·Esc를 사용한다. MOBILE은 기존 독립 다중 터치 유지. 선택/전환 때 모든 누른 터치를 해제한다. 모바일 조작기는 설정 GUI의 터치를 가로채지 않고, 표준 Button으로 전달한다. 터치→마우스 에뮬레이션 설정은 변경하지 않았다.

설정은 진행 저장과 별도 `user://reflection_input_preferences.cfg`에 저장한다. **조작 / SETTINGS 또는 F2**로 다시 선택하며, 선택 화면에서 **C / M**도 지원한다. 저사양 2D 관측 선택도 저장한다. 테스트 인스턴스의 기존 `checkpoint_enabled=false`는 진행/설정을 디스크에 쓰지 않는 검수 모드로 유지한다.

## 실제 화면

다음은 Godot 또는 내보낸 WASM을 실행해 찍은 화면이다. 테스트 드라이버가 위치·각도를 설정하며 전체 수동 플레이 완주 캡처는 아니다. 분기용 fixture는 검증 전용이며 T/A 실제 맵에 스플리터/프리즘을 새로 배치하지 않았다.

| 비교/기능 | 캡처 |
|---|---|
| 이전 A01 시점·가는 글씨 (main 85dd79c) | [변경 전](beam_observer_evidence/before_a01.png) |
| 새 장치/환경·중간 굵기·콘솔 선택 | [변경 후](beam_observer_evidence/after_a01.png) |
| 실제 T03 반사 종점 관측 | [Godot](beam_observer_evidence/native_reflected.png) · [Chromium](beam_observer_evidence/web_reflected.png) |
| 실제 수신기 활성/완료 | [Godot](beam_observer_evidence/native_receiver_active.png) · [Chromium](beam_observer_evidence/web_receiver_active.png) |
| 모바일 UI와 관측창 | [native 게임 영역](beam_observer_evidence/native_mobile.png) · [웹 4:3 창](beam_observer_evidence/web_mobile_4_3.png) |
| 데이터 전용 폴백 | [2D 상태](beam_observer_evidence/web_data_fallback.png) |
| 생산 웹 COMPUTER (터치 숨김) | [실제 PC 모드](beam_observer_evidence/production_computer_mode.png) |
| 생산 웹 첫 실행 선택 | [실제 시작 화면](beam_observer_evidence/production_input_choice.png) |
| 입력 선택/설정 | [입력 선택](beam_observer_evidence/web_input_choice.png) |
| T03 사각형 제거 유지 | [현재 T03](beam_observer_evidence/t03_structure.png) |

native `ViewportTexture` 캡처는 4:3 OS 창에서도 기존 프로젝트의 16:9 게임 영역을 추출한다. Chromium 4:3 캡처는 브라우저 창 전체(1440×1080)를 저장했다. 이를 실제 iPad 캡처라고 표시하지 않는다.

## 검증 결과와 한계

최종 결과는 아래 로그를 함께 확인한다.

- [전체 회귀](beam_observer_evidence/regression.log): import/startup + **23개 스위트** (기존 22개 + 신규 관측 검사). T01–T04, A01–A03, A02 거치/레일, 반사/분광/분기/방향/동시 수신, 순서/문/체크포인트와 잠금 자산 검사 포함.
- [관측 native 렌더](beam_observer_evidence/native_observer.log), [관측 웹 렌더](beam_observer_evidence/web_observer.log): **62개 검사 통과**. 실제 렌더링과 관측 기능 검사. 메인 카메라 불변, 실제 반사 종점/분기/분광/각 소스별 수락 상태, 수신 우선순위, 미접촉 장치 배제, 범위 종료/빈 경로/발사 중단/오버레이, UI 겹침, PC 이동·발사, 모드/설정 저장·복원 검사.
- [콘솔 native](beam_observer_evidence/console.log): 기존 **48개** 검사 통과. T03의 6개 벽/개구부만 제거한 기존 구조 해시 유지. **ㄱ자 구조와 모든 나머지 구조의 충돌 해시가 이전과 일치**한다.
- [웹 무결성](beam_observer_evidence/web_integrity.log), [브라우저 부팅](beam_observer_evidence/web_boot.log): 단일 스레드 Compatibility export, 실제 WASM 시작, COMPUTER → F2 → MOBILE 선택, 다중 터치, 도움말 Build 표시.
- 생산 PCK의 기본 씬/새 스크립트/실제 checkout SHA를 `tests/web_pack_check.gd`로 확인한다. Pages의 커밋별 경로와 기존 캐시 검증을 유지한다. PR 브라우저 시각 검수는 격리된 임시 프로젝트이며 **production export에 테스트 fixture/위치 이동 드라이버를 포함하지 않는다.**

초기 로컬 캡처의 Build 표시는 기준 checkout 85dd79c이며 미커밋 수정 상태에서 촬영했다. CI와 커밋 후 export는 각각 실제 checkout SHA를 자동 기록한다. 화면의 SHA와 Actions checkout/manifest를 대조해야 한다.

미검증/남은 사항:

1. 실제 iPad Safari의 FPS·발열·메모리, 터치 체감, 기기 오디오 청취, 전체 수동 완주/시연 영상 촬영.
2. 작은 휴대폰 세로 화면의 별도 UX 최적화. 이번 검수는 데스크톱 및 iPad에 해당하는 landscape/4:3 비율을 대상으로 했다.
3. native 렌더 종료 시 2개 ObjectDB 인스턴스 경고가 간헐적으로 남는다. VSync 불가 경고도 llvmpipe 환경에서 발생한다. 파싱/게임 스크립트 오류와 구분한다. 생성 WAV가 무음이 아닌 것은 검사했지만 실제 스피커 청취를 인증하지 않는다.
4. main 직접 병합/공개 배포는 하지 않는다. PR의 빌드 성공을 Pages 배포 성공으로 표시하지 않는다. 공개 Pages/iPad 접근 제한도 기존 보고서와 동일하다.

## 실행/재현

Godot 4.7.2로 F5 또는 `PLAY_REFLECTION.sh`. 처음 COMPUTER/MOBILE 선택 → T 직접 조작/발사 → 종점이 시야 밖으로 가면 관측창. A 콘솔에서는 기존 전체 퍼즐 시점으로 조작한다. 설정(F2)에서 모드/2D 전환. T03 관측 재현은 거울 -45°, 플레이어 (30.66, 0.03, 15.38)에서 (31, 1.15, 5)로 발사한 실제 반사 경로를 사용했다. 기본 탐색 카메라 size 18을 유지한 상태에서 종점이 안전 영역 밖으로 나간다. 테스트 캡처를 위해 메인 카메라를 레이저에 따라 이동시키지 않았다.

```bash
GODOT=/absolute/path/to/Godot_4.7.2 ./VERIFY_REFLECTION.sh --import
$GODOT --path . --script res://tests/beam_observer_test.gd -- --visual-review
python3 scripts/web/prepare_build.py
# 4.7.2 web templates의 XDG_DATA_HOME 지정 후 export
$GODOT --headless --path . --export-release Web work/web/index.html
$GODOT --headless --main-pack work/web/index.pck --script "$PWD/tests/web_pack_check.gd" -- "$(git rev-parse HEAD)"
python3 scripts/web/package_release.py work/web
python3 tests/validate_web_export.py work/web
python3 tests/web_smoke.py
python3 tests/web_cache_test.py
REVIEW_SUITE=beam_observer_test python3 tests/web_visual_review.py
```

웹 검수에는 Python Playwright/Chromium이 필요하며 시스템 브라우저는 `CHROMIUM_PATH=/usr/bin/chromium`. 생성물/로그/임시 프로젝트는 `work/`에만 저장한다. Windows 검증 스크립트에도 관측 스위트와 VisualReview 호출을 추가했지만 **Windows 자체 실행은 이번 Linux 환경에서 검증하지 않았다.**
