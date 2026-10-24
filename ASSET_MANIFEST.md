# PROJECT: REFLECTION — ASSET MANIFEST v5.1

확정 세대: `RF-v4.0-quality-1` / 작성일 2026-10-23.

| 자산 ID | 원본 경로 | 버전 | 범위 | 출처·라이선스 |
|---|---|---|---|---|
| RF-DEV | assets/v4_0/device_visuals.gd | 4.0.0 | 거울 프레임, 눈금, 증폭 코어, 프리즘 레일, 분기 프레임, 차단막, 상태 링 | 이번 작업에서 작성한 프로젝트 내부 절차형 자산 |
| RF-FAC | assets/v4_0/facility_visuals.gd | 4.0.0 | T 격리실·검사실, A 로비, H 배광실, 침상·랙·포털·타일·표식·허브 회전체 | 동일 |
| RF-SURFACE | assets/v4_0/surface_finish.gd | 4.0.0 | seed=407 결정적 64px 패널·마모 텍스처 | 동일 |
| RF-FILM | assets/v4_0/film_grain.gdshader | 4.0.0 | 정적 디더링·채널 양자화·비네트 | 동일 |
| RF-PLAYER | scripts/player_controller.gd | 기존→4.0 | 기존 피험자 외형·이동 보존, 발사기 획득 표시 추가 | 기존 프로젝트 + 이번 수정 |
| RF-OPTICAL | scripts/optical_device.gd / laser_system.gd | 기존→4.0 | 기존 광학 계산 보존, 반사 횟수·증폭·정보 추가 | 기존 프로젝트 + 이번 수정 |

외부 게임에서 가져온 맵·모델·텍스처·음원은 없다. 별도 이미지 생성·다운로드 에셋 없이 Godot primitive mesh, SurfaceTool, ImageTexture, 셰이더로 작성한다. Godot 실행 파일과 공식 MinGit은 개발 도구로 `tools/` 아래 두며 게임 아트 자산에 포함하지 않는다.

## 보존·교체 정책

1. `data/asset_lock.json`이 확정 세대의 파일별 SHA-256을 기록한다. `tests/asset_lock_test.gd`로 검증한다.
2. 이후 작업에서 `assets/v4_0/`를 임의 덮어쓰지 않는다. 변경이 필요하면 `assets/v4_1/`처럼 새 세대로 복제하고 해당 버전만 수정한다.
3. 매니페스트에 교체 사유·치수 차이·광학 충돌 호환성·검수 화면을 기록한 뒤 참조 경로를 변경한다. 사용자 변경 지시가 있으면 그 범위에서 진행한다.
4. 이전 세대와 작업 전 Git 태그를 유지한다. Git 태그 `v3-before-v4-quality`는 작업 전 복구 지점이다.

## 검수 자료

`tests/visual_review.gd`는 Compatibility 렌더러에서 격리실·A-01·전력 복구 허브·B-01 기본/경사형 증폭·B-02 RGB 분산·C-01 분기·미니맵 화면을 `tools/validation/v5_1_review/`에 저장한다. 이 캡처는 재현 가능한 검수 자료이며 플레이 저장 파일이 아니다. 자동 기능 검증은 `VERIFY_REFLECTION.ps1`에서 수행한다.

## v5.1 파생 에셋

| ID | 파일 | 버전 | 변경 내용 | 호환성·검수 |
|---|---|---|---|---|
| RF-FAC | `assets/v5_1/facility_visuals.gd` | 5.1.0 | v4 시설 모듈을 상속해 목표 구역 크기의 바닥 표식, A 로비와 H 포털, 구역 안내 표식을 추가 | 상속된 v4 원본은 잠금 유지. Godot 4.7.2에서 씬 생성·지도 충돌층 검수 |
| RF-DEV | `assets/v5_1/device_visuals.gd` | 5.1.0 | v4 절차형 장치 자산을 상속하고 경사형 증폭기의 프레임·투명 코어·전력 표식을 추가 | v4 원본을 유지하며 파생 파일의 SHA-256을 잠금. 실제 경사 광로 캡처와 수신기 테스트 |

`data/asset_lock.json`의 생성 세대는 RF-v5.1-optics-map이며 RF-FAC와 RF-DEV v5.1 해시를 포함한다. 광학 계산·탐색은 프로젝트 코드와 Git으로 버전 관리하고, 외형 변경은 이 manifest와 잠금 파일을 함께 갱신한다. v5.1 기능 테스트 로그와 검수 캡처는 무시 처리된 `tools/validation/` 아래에 둔다.
