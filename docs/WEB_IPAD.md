# T/A DEMO v1.0 — 웹 / iPad Safari

Godot **4.7.2 Standard**, Compatibility (WebGL 2), Web 템플릿의 **thread_support=false**로 내보낸다. SharedArrayBuffer·COOP/COEP 헤더에 의존하지 않으므로 GitHub Pages 정적 호스팅에 적합하다. WebGL 2와 WebAssembly를 지원하는 최신 iPadOS Safari를 권장한다. 실제 iPad 기기 성능·Safari 검수는 별도이며 Chromium 에뮬레이션을 Safari 검증으로 간주하지 않는다.

## 플레이

Safari에서 배포 URL을 열고 가로 방향으로 사용한다. 로딩 후 필요한 경우 화면을 한 번 터치해 오디오 재생을 허용한다.

- 왼쪽 화살표: 이동 (두 버튼을 동시에 누르면 대각 이동).
- 게임 화면 터치/드래그: 조준. 오른쪽 **발사**를 누르는 동안 조사. 이동·조준·발사를 서로 다른 손가락으로 병행할 수 있다.
- **조작**: 가까운 단말기/장치 E, 콘솔 진입, 거치대 장착·회수.
- 콘솔에서 거울 터치로 선택, **−/+**로 15° 회전, **1°**를 켜면 정밀 회전, **종료**로 콘솔 이탈.
- 레일 손잡이를 조작한 후 **−/+**로 레일 0.25m 이동. A-02 거치대 근처 **출력**으로 F 조사 ON/OFF.
- **지도 / 기록 / 도움**은 같은 버튼을 다시 눌러 닫는다. **재시도**는 현재 퍼즐 R. **종료**는 일반 플레이에서 일시 정지/재개.
- 기존 WASD·마우스·E·휠·Shift+휠 및 기타 PC 키는 유지한다.

완료 단계 체크포인트는 기존 user:// 저장을 사용한다. Safari 사이트 데이터 삭제·비공개 모드·저장 공간 제한으로 저장이 사라질 수 있다. 터치 손가락 해제·앱 포커스 상실·뷰포트 변경 시 유지 입력을 해제한다. 광학 계산, T/A 배치·수신기·진행 조건, 잠금된 원본 자산은 변경하지 않는다.

## 자동 빌드와 Pages 활성화

`.github/workflows/web.yml`: PR에서는 가져오기, 전체 GDScript 회귀 검사, 웹 release 내보내기, Chromium 브라우저 부팅/멀티터치 smoke 검사, `reflection-web` 산출물 업로드를 수행한다. main push 또는 main 수동 실행에서는 같은 검사를 통과한 산출물을 Pages에 배포한다. 배포 권한은 deploy job에만 부여한다. 외부 비밀 키는 필요 없다.

이 PR 자체는 main 병합을 수행하지 않는다. Pages 활성화가 아직 필요하다면 저장소 소유자가 다음과 같이 설정한다.

1. 저장소 **Settings → Pages → Build and deployment → Source → GitHub Actions** 선택.
2. **Settings → Actions → General**에서 GitHub Actions와 사용하는 액션 실행을 허용한다. 조직 정책이 있다면 소유자가 해당 정책도 확인한다.
3. PR을 main에 병합한다. 또는 이미 병합했다면 **Actions → Web game → Run workflow → main → Run workflow** 실행.
4. 필요하면 **Settings → Environments → github-pages**의 배포 승인/브랜치 정책을 확인하고 main 배포를 허용한다.
5. Actions의 `build`와 `deploy`가 모두 성공한 뒤 `deploy`의 **github-pages environment URL**을 Safari에서 연다. 예상 주소는 `https://suhheechoi-sketch.github.io/PROJECT-REFLECTION-CLOUD/`이나, 실제 성공 URL을 기준으로 한다.

현재 저장소는 **비공개**다. 비공개 저장소의 Pages 지원은 계정 플랜에 따라 제한될 수 있다. Settings → Pages에서 업그레이드 요구가 표시되면 비공개 Pages를 지원하는 플랜이 필요하다. 저장소 공개 전환은 별도 사용자 결정이며 이 작업에서 수행하지 않는다. 일반 Pages 사이트는 저장소 비공개 여부와 별개로 공개될 수 있으므로 Pages 설정에 표시되는 접근 범위를 확인한다.

Pages가 아직 활성화되지 않아 deploy가 실패해도 build job의 **reflection-web** ZIP을 다운로드할 수 있다. 압축 해제 후 파일을 직접 여는 대신 HTTP 서버로 제공한다.

## 로컬 재현

공식 4.7.2 엔진과 같은 버전 export templates를 설치한다. CI는 공식 릴리스 SHA512 합계를 검증한다. 로컬에서는 `GODOT`에 엔진 절대 경로를 지정한다.

```bash
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 bash VERIFY_REFLECTION.sh --import
# VERIFY_REFLECTION.sh와 같은 데이터 디렉터리에 템플릿 설치:
# work/godot-data/godot/export_templates/4.7.2.stable/web*.zip
export XDG_DATA_HOME="$PWD/work/godot-data"
mkdir -p work/web
/path/to/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --export-release Web work/web/index.html
python3 -m http.server 8000 --directory work/web
```

다른 터미널에서 `python3 tests/web_smoke.py`로 Chromium 검증을 재현한다 (`pip install playwright==1.62.0`, `playwright install chromium` 필요). 이미 설치된 Chromium을 사용하려면 `CHROMIUM_PATH=/usr/bin/chromium`을 지정한다.

## 실기기 확인 항목

Safari에서 T-01 단말기 → 발사기 획득 → T-02 직사격 → T-03/04 반사 → 종료 단말기 → A-01 콘솔 → A-02 거치/레일 → A-03 순서/레일 → 복구 단말기/엔딩을 순서대로 확인한다. 회전 ±/정밀, 세 손가락 이동+조준+발사, 가로 회전, 백그라운드 복귀, 음성/산업음, 한국어, 페이지 재방문 체크포인트를 확인한다. 실기기에서 처리 속도가 부족하다면 모델/퍼즐 조건을 바꾸기 전에 렌더링 부하를 측정한다.

## 이번 작업의 검증 기록 (2026-10-25)

- 기반: origin/main `3165a3a`.
- 엔진: `4.7.2.stable.official.ed1daf0bf`.
- 변경 전: 시작 검사 및 기존 20개 회귀 스위트 통과.
- 변경 후: 기존 회귀 검사와 신규 touch_controls_test (동시 이동/발사, 손가락별 해제, 포커스 입력 초기화, E 단말기/발사기 획득, 콘솔 이탈 시 발사 억제, 도움말 토글) 실행.
- 공식 4.7.2 템플릿 SHA512 확인 후 Web release export 생성. `index.wasm`, `index.pck`, HTML/JS와 오디오 worklet을 포함한다.
- Pages 관리 API는 작업 환경에서 `Forbidden`으로 차단됨. Pages 활성화·실제 URL 응답 확인은 완료되지 않았으며, main 병합 후 배포 workflow 성공 확인이 필요하다.
- 실물 iPad Safari의 전체 T/A 플레이·성능·오디오 검증은 미실시.
- 변경 후 전체 검사 결과: 시작 검사와 21개 GDScript 회귀 스위트(합계 22개 검사) 통과. 웹 브라우저에서 WASM 부팅과 멀티터치 smoke 통과. 화면 검수에서 발견한 한국어 HUD 글리프 누락은 T/A HUD 테마 및 Label3D에 포함 폰트를 지정하여 수정했다.
