# Pages 최신 빌드 식별 및 캐시 격리 (2026-10-25)

## 조사 결론과 한계

- 조사 기준 main: `304b7b49bb63ab9be92ce2399ed8f9291e159c63` (PR #5 병합). main 직접 수정/병합 없음.
- `project.godot` 기본 실행은 `res://scenes/ta_demo.tscn`. Web 프리셋은 프로젝트 기본 씬을 사용한다. `scenes/main.tscn`은 보존용이며 이번 기본 실행이 아니다.
- [Web game #9](https://github.com/suhheechoi-sketch/PROJECT-REFLECTION-CLOUD/actions/runs/40180131052) checkout 로그의 전체 SHA가 위 main과 일치한다. export 로그에 `ta_demo.gdc`, `ta_geometry.gdc`, `ta_console_station.gdc`, `ta_console_view.gdc`, `ta_demo.tscn.remap`, `optical_console.tscn.remap` 저장이 확인된다. build/deploy 모두 성공. [관련 원본 로그 발췌](web_version_evidence/run9_provenance.log)
- #9 `github-pages` artifact ID `12594181280`, digest `sha256:effc4d4ee371272c4d97e905bbaba9ab0e951fde0946c429791037d8b1ea3c80`, head SHA는 위 main. `reflection-web` artifact ID `12593896530` 역시 같은 SHA.
- 따라서 **PR5가 main이나 빌드에서 누락됐다는 증거는 없다.** 동일 main 소스로 Godot와 Chromium을 실행했을 때 지정 T03 사각형은 제거되어 있다. ㄱ자 통로, 수신기 좌표, 광학 계산은 유지된다.
- 기존 배포는 항상 같은 `index.html`, `index.js`, `index.pck`, `index.wasm`을 사용했다. 빌드 식별 정보가 없어 오래된 문서/리소스 캐시 또는 재개된 탭과 새 배포를 구분할 수 없었다. 이는 확인된 배포 설계의 결함이다. **실제 사용자의 Safari 캐시가 원인이었는지는 확정하지 못했다.**
- 공개 Pages 호스트와 다운로드된 artifact 파일 URL은 이 환경의 네트워크 프록시가 HTTP 403으로 차단했다. 공개 HTML/PCK/WASM의 바이트/응답 헤더와 사용자 Safari 저장소는 대조하지 못했다. GitHub artifact 메타데이터와 빌드 로그 확인을 공개 사이트 실측으로 표시하지 않는다.
- Web 프리셋 PWA는 false이며 Service Worker를 생성하지 않는다. 저장소 자체에 캐시용 Service Worker가 없다. 기존 외부 등록 여부는 공개 사이트에서 미검증이다.

## 수정

- `scripts/web/prepare_build.py`: 실제 checkout의 `git rev-parse HEAD`를 `data/build_info.json`에 자동 기록. 파일은 생성물로 git에서 제외하고 Web PCK에는 포함한다. PR 빌드의 합성 merge SHA와 main 배포 SHA가 다를 수 있으며 각각 실제 checkout SHA를 표시한다.
- `scripts/ta_demo.gd`: 도움말 H/F1/도움에 `Build: <7자리 SHA> / Version: T/A DEMO v1.1` 표시. 퍼즐 배치/광학/진행 수정 없음.
- `scripts/web/package_release.py`: 모든 Godot HTML/JS/PCK/WASM/오디오 워크렛/이미지를 `builds/<전체 SHA>/`에 격리. 서로 다른 빌드의 리소스 URL이 겹치지 않는다. 파일별 SHA256을 `build.json`에 기록한다.
- `scripts/web/launcher.html`: 기존 Pages 루트 URL을 유지하며 최신 manifest를 `fetch(cache: 'no-store')` + 매번 다른 query로 읽고 같은 origin iframe에서 해당 빌드를 시작한다. 복귀/주기 검사에서 새 배포가 발견되면 “새 빌드 실행” 버튼을 표시하여 진행 중 퍼즐을 임의 재시작하지 않는다. 프로젝트 범위의 Service Worker 등록만 해제한다.
- `.github/workflows/web.yml`: 출력 디렉터리 청소 → SHA 생성 → 회귀 → export → 실제 PCK 검사 → 커밋 경로 패키징 → 파일 hash 검사 → 실제 브라우저/캐시 검사 → 기존 Pages artifact/deploy 순서. Compatibility/단일 스레드 유지.
- Pages에서는 임의 HTTP 캐시 헤더를 설정할 수 없다. HTML meta만으로 캐시 문제를 해결했다고 주장하지 않는다. manifest의 no-store 요청과 빌드별 URL이 실제 방어 수단이다.
- 이미 열려 있는 **이전 배포의 HTML에는 새 launcher가 존재하지 않는다.** 그 탭을 원격으로 교체할 수는 없다. 첫 전환은 새 루트 문서를 열어야 한다. PR 병합·배포 후 `https://suhheechoi-sketch.github.io/PROJECT-REFLECTION-CLOUD/?release=<배포SHA>`로 첫 전환을 식별할 수 있다. 이후에는 launcher가 최신 manifest를 확인한다. 사용자의 수동 새로고침만을 해결책으로 삼지 않았다.

## 실행 화면 비교

기존 사용자 스크린샷의 빨간 표시와 같은 위치를 대상으로 PR5 이전 `860906b`와 최신 소스의 동일 카메라 캡처를 비교했다. 이전 화면의 수신기 앞 세로 벽과 바깥 하단 가로 벽이 최신 화면에는 없고, 거울에서 수신기로 연결되는 ㄱ자 통로는 남아 있다. 현재 스크린샷의 통로 자체는 의도적으로 동일하다.

| 대상 | 실제 렌더링 증거 |
|---|---|
| PR5 이전 T03 (860906b) | [이전](web_version_evidence/t03_before_pr5.png) |
| 최신 T03 (native / Chromium) | [Godot](web_version_evidence/console_t03_vault_removed.png) · [웹](web_version_evidence/web_t03_vault_removed.png) |
| A01 실제 콘솔 설치 위치 | [Godot](web_version_evidence/console_a01_station.png) · [웹](web_version_evidence/web_a01_station.png) |
| 콘솔 진입 및 선택 | [Godot](web_version_evidence/console_a01_selected.png) · [웹](web_version_evidence/web_a01_selected.png) |
| 빈 공간 클릭 후 선택 해제 | [Godot](web_version_evidence/console_a01_deselected.png) · [웹](web_version_evidence/web_a01_deselected.png) |
| 회전 후 콘솔 시점 | [Godot](web_version_evidence/console_a01_pc.png) · [웹](web_version_evidence/web_a01_pc.png) |
| 도움말 빌드 표시 | [로컬 수정 미리보기](web_version_evidence/web_help_build_preview.png) |

증거의 첫 로컬 미리보기 빌드 표시는 작업 기반 checkout `304b7b4`다. 수정된 코드가 아직 커밋되지 않은 로컬 렌더 캡처이며 배포됐다는 뜻이 아니다. 커밋 후 `efd4b38` 소스를 다시 export하여 PCK SHA 일치와 Chromium 실제 도움말 표시도 확인했다. [커밋된 소스의 실제 화면](web_version_evidence/web_help_build_committed.png) · [PCK 확인](web_version_evidence/packed_committed_build.log) · [브라우저 확인](web_version_evidence/browser_committed_build.log). 이후 CI는 해당 실행에서 실제 checkout한 전체 SHA를 자동으로 기록한다. `build.json`, Actions checkout SHA, 게임 도움말의 7자 Build를 함께 대조한다.

## 검증

- Godot `4.7.2.stable.official.ed1daf0bf`, Standard / Compatibility.
- import/startup + 기존 22 회귀 스위트 통과. [결과](web_version_evidence/regression.log)
- native 실제 OpenGL 렌더 + 콘솔 48 검사 통과. [결과](web_version_evidence/native_console.log)
- production Web PCK를 native 엔진에서 직접 열어 기본 씬/PR5 리소스/SHA 확인. [결과](web_version_evidence/packed_build.log)
- Web release 생성, HTML/JS/PCK/WASM size 및 단일 스레드 메모리, manifest 파일별 SHA256 검사 통과.
- 실제 production WASM Chromium 실행, 멀티터치, 도움말 및 빌드 표시 확인. [결과](web_version_evidence/browser_boot.log)
- 캐시 가능한 HTML을 유지하고 다른 SHA manifest를 배포하는 자동 브라우저 검사 통과. manifest를 다시 읽고 새 commit 경로로 전환함. [결과](web_version_evidence/cache_update.log)
- 웹 시각 검증은 **별도 임시 프로젝트**에만 테스트 드라이버를 넣어 같은 `ta_demo.tscn`을 instantiate하여 수행했다. 위 화면들과 콘솔 48 검사가 통과했다. production에는 위치 이동/완료 치트나 테스트 드라이버를 포함하지 않는다. [결과](web_version_evidence/web_visual_checks.log)
- 게임 사용자 입력, 반사 조건, 정답, 장치 좌표 및 진행 코드 변경 없음. `tests/console_interaction_test.gd`에는 추가 화면 캡처만 추가했다.

## 재현 방법

```bash
python3 scripts/web/prepare_build.py
GODOT=/path/to/Godot_4.7.2 ./VERIFY_REFLECTION.sh --import
# 설치된 4.7.2 web templates 경로를 XDG_DATA_HOME에 지정
$GODOT --headless --path . --export-release Web work/web/index.html
$GODOT --headless --main-pack work/web/index.pck --script "$PWD/tests/web_pack_check.gd"
python3 tests/validate_web_export.py work/web
python3 scripts/web/package_release.py work/web
python3 tests/validate_web_export.py work/web
python3 tests/web_smoke.py
python3 tests/web_cache_test.py
# 선택: production과 분리된 웹 시각 검증 export + Chromium 캡처
python3 tests/web_visual_review.py
```

웹 시각 검사와 브라우저 검사는 Playwright/Chromium 설치가 필요하다. 시스템 Chromium 사용 시 `CHROMIUM_PATH=/usr/bin/chromium`. 생성물은 `work/`에만 저장한다.

## 남은 검증

새 PR은 main에 병합하지 않는다. 기존 #9의 배포 성공과 이번 PR 배포는 별개다. 공개 Pages 새 Build 실측, 실제 iPad Safari, 전체 수동 완주, 기기 오디오 청취는 미검증이다. 기존 native 렌더 환경의 VSync 경고는 하드웨어 제약이며 스크립트 오류와 구분한다. 실제 iPad에서는 도움말 SHA, T03 벽, A01 선택/회전/해제/종료, 오디오 및 세이브 지속을 확인해야 한다.
