# PROJECT: REFLECTION — v4.0 품질 개선 1차 작업 보고

작성일: 2026-10-23 (한국 시간).

## 결과

기존 Godot 프로젝트에서 T 도입·튜토리얼, A 입구 로비·A-01, H 중앙 배광실과 장치 외장을 개선했다. **Godot 4.7.2.stable.official.ed1daf0bf / Compatibility 엔진을 유지**했으며 다른 엔진으로 전환하지 않았다. 실제 OpenGL 렌더링 실행과 화면 저장에 성공했고, 가져오기·스크립트 오류 검사와 8개 자동 검증이 통과했다. 일반 게임 모드도 실행했다.

## 작업 전 분석·보존

- 실제 작업 경로: `C:\Users\user\Downloads\--main\--main`.
- 버전은 포함된 실행 파일의 `--version`으로 확인했다.
- 기존은 `main.tscn` 하나와 절차형 `main.gd` 중심. 플레이어는 CharacterBody3D, WASD 4.2m/s, 마우스의 수평 평면 교점으로 조준한다.
- 카메라는 직교 쿼터뷰이며 이전 size는 20.5였다. 레이저는 물리 레이캐스트, 실제 충돌 법선 반사, 굴절 매질 이탈면 계산, 프리즘 RGB 분산, 스플리터 가지 추적 방식이다.
- 기존 최대 거리 25m·표면 상호작용 8회·가지 처리 24개, 장치 회전 후 PhysicsServer3D 변환 동기화를 보존했다.
- 기존 반사·굴절·분산·분기·차단막, 수신기의 색·방향·광량·조사 시간과 회로 해금 규칙을 유지했다. 변경한 제약은 튜토리얼의 발사기 획득, 반사 검사 우회 방지, A-01 정답 경로다.
- Git이 설치되지 않아 공식 MinGit을 `tools/mingit/`에 두고 저장소를 만들었다. 작업 전 커밋 **42ca91a**, 태그 **v3-before-v4-quality**를 만들고 나서 게임 파일을 수정했다.
- 엔진·개발 도구·캐시는 Git 제외, 코드·문서·확정 절차형 자산·검수 PNG는 버전 관리한다. `tools/.gdignore`로 개발 도구가 Godot 자산으로 잘못 인식되지 않도록 했다.

## 구현 내용

| 항목 | 변경 내용 |
|---|---|
| 도입 | 짧은 밝아짐 연출, 침상·07 번호·관찰 카메라·REC, 신원 인증 로그, 외부 통신 제한 안내 |
| 광원 획득 | 신원 단말기 이후 별도 지급대에서 E로 획득. 획득 전 발사·외형·T02 수신기 차단 |
| 튜토리얼 | 기존 T01~04 흐름 보존. T03은 1회, T04는 2회 이상 실제 반사 필요. 직접 조사 우회 차단 |
| 허브 발견 | T04 직후 강제 공개 대신 실제 허브 경계 첫 진입 시 2.2초 시야 확장, 계속 이동 가능 |
| 공간 | T 알코브·분리벽·서버랙·검사문 프레임, A 로비 안내·서비스 가장자리·광학 레인, H 중앙 회전체·회로 링·유도선 |
| 시설 전력 | 회로 복구 시 해당 허브 링 적색→청록, 회전체 가동, 국소광 증가 |
| 카메라 | T 13.5, 일반 15.5, 허브 공개 18. 서쪽 외곽의 빈 공간을 덜 보이도록 범위 제한 |
| 광학 장치 | 거울 금속 프레임·회전축·15° 눈금, 증폭 코어·출력 표시, 정확한 삼각 프리즘, Y자 스플리터, 기계식 차단판, 수신기 링·종류 표식 |
| 근접 정보 | 튜토리얼 포함 이름·용도·선택 조작·파장·최소 광량·유지 시간·반사 횟수·방향 조건 표시 |
| A-01 | 두 거울 45° 정답 경로, 배플, 실제 반사 2회·+X 입사·1.2초 조사, B·C 동시 해금 |
| 증폭 | G-01 진입 시 ×2, 최대 300%. 일반 medium 기본값은 ×1로 기존 동작 보존 |
| 초기화 | R은 튜토리얼 재시작 또는 현재 A/B/C 구역 복원. 완료 회로 보존. Shift+R 전체 초기화 |
| 기록 | L 시스템 로그, 최근 10개 기록을 스크롤 확인 |
| 표면 | 결정적 64px 패널·마모 텍스처, nearest 필터, 정적 디더링·채널 양자화·약한 비네트. HUD는 후처리 제외 |
| 에셋 보호 | v4_0 원본 분리, 4개 원본의 SHA-256 잠금·검증. 후속 교체는 새 세대 디렉터리와 매니페스트 갱신으로 관리 |

외곽 바닥은 **48×60m 그대로**이며 방의 크기를 무작정 늘리지 않았다. 기존 면적을 구획하고 주변 설비·안내·카메라 비율을 개선했다. H는 전력 변화가 읽히는 시각적 허브로 만들었고 B/C의 공간·입장 조건을 보존했다.

## 디자인 기준·문서

| 파일 | 내용 |
|---|---|
| [ART_BIBLE.md](../ART_BIBLE.md) | PS1 산업 공포 팔레트, 로우폴리 면 수, 텍스처·조명·후처리·에셋 교체 정책 |
| [SCALE_GUIDE.md](../SCALE_GUIDE.md) | 1유닛=1m, 플레이어·문·장치·복도·실험실 치수와 카메라 비율 |
| [DEVICE_CATALOG.md](../DEVICE_CATALOG.md) | 장치 실루엣, 광학 규칙, 현재 수신 조건·초기화 정책 |
| [ASSET_MANIFEST.md](../ASSET_MANIFEST.md) | 자산 ID·버전·원본·출처, SHA 잠금·후속 보존 규칙 |
| [LEVEL_DESIGN.md](../LEVEL_DESIGN.md) | 현재 맵·도입·A-01 정답, A03/B03/C03 고급 퍼즐 설계와 우회·교착 검증 계획 |

고급 퍼즐은 광로·색·광량·순서·시간·회로 상호작용을 조합한다. 설계의 에너지 수지는 정리했지만 실제 고급 스테이지 배치·실광선 해결성 검증은 아직 하지 않았다.

## 변경 파일

| 구분 | 파일 |
|---|---|
| 게임 | `scripts/main.gd`, `scripts/player_controller.gd`, `scripts/optical_device.gd`, `scripts/laser_system.gd` |
| 절차형 시각 원본 | `assets/v4_0/device_visuals.gd`, `facility_visuals.gd`, `surface_finish.gd`, `film_grain.gdshader` 및 Godot UID |
| 데이터 | `data/stages.json`의 A01·광원 획득 메타데이터, `data/asset_lock.json` |
| 기존 검증 보완 | `tests/tutorial_flow_test.gd`, `tests/progression_state_test.gd` |
| 새 검증 | `tests/quality_pass_test.gd`, `energy_flow_test.gd`, `navigation_test.gd`, `asset_lock_test.gd`, `visual_review.gd` 및 UID |
| 실행·관리 | `AGENTS.md` 후속 작업 규칙, `VERIFY_REFLECTION.ps1`, `.gitattributes`, `.gitignore`, `tools/.gdignore`, `artifacts/.gdignore` |
| 문서 | 루트 규격 문서 5개, `README.md`, 본 보고서, 이전 두 설계·상태 문서의 v4 안내 |
| 검수 화면 | `artifacts/v4_0/01_isolation.png`, `02_a01.png`, `03_hub_powered.png`, `04_spectrum_devices.png` |

## 검증 결과

실행 환경: Windows / Intel Iris Xe / OpenGL 3.3 / Godot Compatibility. 정상 렌더링 캡처 4장을 저장하고 확인했다. 최종 가져오기 및 검증 로그에서 `SCRIPT ERROR`, `ERROR`, `FAIL`이 발견되지 않았다.

| 검증 | 결과·범위 |
|---|---|
| optics_math_test | 통과: 반사, 스넬 법칙, 파장별 분산, 전반사 |
| progression_state_test | 통과: 단계 순서·구역 해금·기록 조건, A→B→C 및 A→C→B 진행 |
| stage_catalog_test | 통과: 19단계 카탈로그와 참조 |
| tutorial_flow_test | 통과: 원격 획득 거부, 광원 지급, 실제 E·휠, T02~04 실제 광선, 직사 우회 거부, 물리문 개방 |
| quality_pass_test | 통과: A01 직접 조사 거부·짧은 조사 실패·두 반사 성공, B/C 물리문, 허브 전력, 로컬/전체 복원 |
| energy_flow_test | 통과: 실제 두 매질 진입 100%→200%→300%, 상한, 고출력 수신기, 기본 매질 에너지 보존 |
| navigation_test | 통과: CharacterBody3D 실제 충돌 이동으로 격리실→지급대→T 출구→A 로비→H→B/C 출입문 |
| asset_lock_test | 통과: 확정 원본 4개 SHA-256 일치 |
| visual_review | 통과: 실제 렌더러에서 4개 검수 상태의 화면 저장, 셰이더·실행 오류 없음 |

재현 명령(프로젝트 폴더 PowerShell):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\VERIFY_REFLECTION.ps1 -VisualReview
```

Windows 실행 정책을 영구 변경하지 않는다. 로그는 `tools/validation/`에 남긴다. 검수 캡처는 재현용 배치 상태이며 사용자의 세이브·수동 완주 기록은 아니다. 동선 검증은 실제 충돌체 이동이지만 키보드·마우스 조작감 전체를 사람이 플레이해 확인한 것은 아니다.

## 아직 구현하지 않은 기능·한계

- A02·A03, 완성된 B01~03·C01~03, D/E/F 내부 콘텐츠와 B-C 지름길.
- 고급 회로의 엄격한 동시 유지·순서 조정기. 현재 B는 RGB 성공을 누적하고 C도 두 수신기의 활성 래치로 성공한다.
- DIRECTOR의 거울·증폭기·차단막·방화문 직접 조작, 최종 보스전. 요청대로 이번 범위에서 구현하지 않았다.
- 두 엔딩, 디스크 저장·불러오기, 효과음·음악, 캐릭터 이동 애니메이션·완성형 환경 모델.
- 모든 B/C 실광선 경로와 전체 게임 밸런스 검증. 이번에는 T·A01 정답과 출입 동선에 집중했다.

기존의 절차형 기반을 보존한 1차 품질 개선 빌드이며 전체 게임이 완성된 상태는 아니다. 게임은 `PLAY_REFLECTION.bat`으로 다시 실행한다.
