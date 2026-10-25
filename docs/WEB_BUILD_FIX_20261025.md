# Web game #5 긴급 수정 — 2026-10-25

기준 main: `16fd402be0a7230f001a6f20fb036d99b1bb886b`.
실패 실행: https://github.com/suhheechoi-sketch/PROJECT-REFLECTION-CLOUD/actions/runs/40164614687 / build job `121083001095`.

## 근본 원인과 재현

실패한 검사는 `tests/tutorial_flow_test.gd`이며 `scenes/main.tscn`의 보존된 전체 시설 튜토리얼을 검사한다. 현재 기본 T/A 데모는 `scenes/ta_demo.tscn`이고 별도 T/A 검사도 그대로 유지한다.

거울 회전 뒤 `await process_frame`만 사용해 렌더 프레임과 물리 프레임의 동기화를 혼동했다. CI처럼 두 프레임의 비율이 달라지면 스크립트의 회전값은 45°지만 물리 레이캐스트는 이전 0° 충돌체를 본다. 이 때문에 T03 조사 실패 → T04 미해금 → 튜토리얼/출입문 11개 실패가 연쇄 발생했다.

동일한 공식 Godot **4.7.2.stable.official.ed1daf0bf**에서 원본 테스트를 `--fixed-fps 240`으로 실행하면 Actions와 같은 11개 실패가 재현된다. 진단 레이는 T03에서 새 면의 x≈−13.064 대신 옛 면 x=−12.630에 충돌한 뒤 서쪽으로 반사했다. 따라서 원인은 반사 공식·수신기 조건·게임 진행 규칙이 아닌 **테스트의 물리 상태 동기화 설정**이다.

수정은 물리 프레임 두 번을 기다리는 `_settle_physics()`다. `physics_frame` 신호가 물리 콜백 전에 발생하므로 한 프레임의 완료 및 deferred gate/shape 갱신까지 기다린다. 수신기 활성화·진행 해금·방향 조건·직사격 거부 등 기존 assertion을 모두 유지한다. 테스트 삭제, 비활성화, 강제 수신기 활성화, 진행 우회는 하지 않았다.

## 변경 사항

- `tests/tutorial_flow_test.gd`: 렌더 대기를 물리 동기화로 교체. T03/T04 실제 회전 입력·반사·문 충돌 해제 검증 유지.
- `.github/workflows/web.yml`: 기존 전체 회귀 검사 뒤 240fps 타이밍 회귀 검사 추가. export 로그의 오류 검사와 HTML/JS/PCK/WASM 무결성 검사 추가. 타임아웃 지정 및 작업 디렉터리 Godot 스캔 제외. Pages의 main 전용 배포 조건은 유지.
- `tests/validate_web_export.py`: 실제 산출물 크기/WASM 헤더·메모리 플래그, HTML의 single-thread 설정, 공유 메모리 부재 검사. JS에는 기능 탐지용 SharedArrayBuffer 문자열이 포함될 수 있어 문자열만으로 실패시키지 않는다.
- `export_presets.cfg`, `project.godot`: Compatibility와 `variant/thread_support=false` 유지. 모바일 ETC2/ASTC 가져오기와 모바일 텍스처 출력을 함께 켜서 모바일 export 사전조건을 충족. PWA cross-origin-isolation 헤더 보조 기능도 명시적으로 끔. Pages 서버에 COOP/COEP나 SharedArrayBuffer를 요구하지 않는다.
- `scripts/touch_controls.gd`, `tests/touch_controls_test.gd`: 종료 후 iPad에서 Shift+R 없이 다시 시작할 수 있도록 **새 게임** 터치 버튼 추가. 기존 이동/조준/발사/콘솔/거치/레일 터치 경로 유지, 새 게임의 종료 탈출·진행/장비 초기화 검사 추가.

T01~T04 및 A01~A03 광학 코드/씬/진행 조건은 바꾸지 않았다. 신규 데모의 T04 종료 단말기 E, A03 READY → 복구 E → RESTORED 및 체크포인트도 유지한다.

## 로컬 검증 결과

| 검사 | 결과 |
|---|---|
| Godot 4.7.2 import / startup | PASS |
| 기존 전체 회귀 (21 suite) | PASS |
| 원본 테스트 + fixed 240fps | 11 실패 재현 |
| 수정 테스트 + fixed 240fps | PASS |
| 수정 테스트 + 최대 10fps | PASS |
| T/A 통합, A02 거치/레일, A03 순서, 회로/종료, 체크포인트 | 전체 회귀에 포함, PASS |
| 터치 수명/멀티터치/새 게임 | PASS |
| 공식 4.7.2 release web export | PASS |
| HTML/JS/PCK/WASM 무결성, single-thread 비공유 메모리 | PASS |
| Chromium 실제 WASM 부팅 + CDP 멀티터치 + 도움말 터치 | PASS |

`GODOT=./tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 ./VERIFY_REFLECTION.sh --import`

`godot --headless --path . --fixed-fps 240 --script res://tests/tutorial_flow_test.gd`

`godot --headless --path . --export-release Web work/web/index.html`

`python tests/validate_web_export.py work/web`

`CHROMIUM_PATH=/usr/bin/chromium python tests/web_smoke.py`

공식 native 엔진은 기존 포함 엔진과 SHA512가 일치했다. 공식 export templates TPZ도 SHA512-SUMS.txt와 대조했다. 증거는 `web_fix_evidence/`의 로그 및 Chromium 화면에 있다. 웹 산출물은 약 38MiB WASM + 6.7MiB PCK이며 Git에 바이너리로 커밋하지 않는다. CI의 `reflection-web` 아티팩트로 제공된다.

## 배포 및 실제 기기 확인 범위

배포 대상 URL: https://suhheechoi-sketch.github.io/PROJECT-REFLECTION-CLOUD/

workflow는 main의 성공한 build에서만 Pages 아티팩트 업로드와 deploy를 수행한다. 별도 수정 브랜치/PR의 성공은 빌드·브라우저 검사까지를 의미하며 **Pages 배포 성공과 다르다**. 이전 사용자 지시에 따라 main을 직접 병합하지 않는다. PR 병합 후 main의 Web game 실행이 deploy까지 성공해야 위 URL을 배포 완료로 표시할 수 있다.

이 환경의 네트워크 정책은 github.io 접속을 허용하지 않아 URL 직접 HTTP 확인은 차단되었다. 이는 사이트가 실패했다는 증거가 아니다. 실제 iPad Safari, Safari WebKit, iPad GPU/WebGL2·텍스처·프레임 속도, 터치 피킹/레일 전체 완주, 실제 오디오, 가로/세로 회전·주소창 변화·백그라운드 복귀, Safari 저장소의 체크포인트 유지, 시연 녹화는 미검증이다. iPad에서 가로 모드로 열고 첫 터치로 오디오를 시작한 뒤 튜토리얼부터 종료 및 새 게임까지 확인한다.
