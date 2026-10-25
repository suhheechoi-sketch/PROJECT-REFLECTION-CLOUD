# PROJECT: REFLECTION 작업 규칙

- 엔진은 포함된 Godot 4.7.2 Standard / Compatibility다. 사용자의 명시적 엔진 변경 지시 없이 교체하지 않는다.
- 현재 규격은 루트 ART_BIBLE.md, SCALE_GUIDE.md, DEVICE_CATALOG.md, ASSET_MANIFEST.md, LEVEL_DESIGN.md를 먼저 읽는다. docs/의 v3 문서는 보존 기록이다.
- 1유닛=1m. 광학 표면·충돌·굴절 이탈면 계산은 같은 형상을 유지한다. 보이는 장식 프레임을 이유 없이 추가 광학 충돌체로 만들지 않는다.
- 확정 원본 assets/v4_0/와 data/asset_lock.json을 후속 작업에서 임의 수정해 교체하지 않는다. 새 버전은 새 디렉터리에 파생하고 변경 이유·호환성·검수 화면을 매니페스트에 남긴다. 사용자의 명시적 수정 지시가 우선한다.
- 광학·진행 변경 후 VERIFY_REFLECTION.ps1로 검증한다. 시각 변경은 -VisualReview로 실제 렌더링도 확인한다. Windows 정책이 막으면 시스템 설정을 바꾸지 않고 powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\VERIFY_REFLECTION.ps1로 실행할 수 있다.
- 후반 스테이지 기획을 런타임 구현과 혼동하지 않는다. 특히 기존 B/C의 활성 래치는 엄격한 동시 유지 조정기가 아니다.
- 작업 전 태그 v3-before-v4-quality를 보존한다. tools/ 엔진·MinGit과 .godot/ 캐시는 커밋하지 않는다.

- 최신 작업 우선순위는 `docs/INTEGRATED_DIRECTIVE_20261025.md`(사용자 첨부 통합 지시서)의 03장 → 확인 가능한 v6.2 규칙 → 현재 저장소 세부 구현 → v6.3 제안 순이다. 첨부본 외 독립 v6.2 원문은 현재 체크아웃에서 확인되지 않았다.
- DIRECTOR 보스전과 필수 고정 광원 퍼즐을 신규 구현하지 않는다. 기존 W-B02 시제품의 휴대 백색광 전환은 남은 작업이다.
- Linux 검증은 `VERIFY_REFLECTION.sh`로 동일 17개 테스트와 시작 검사를 실행할 수 있다. 실제 엔진 버전, 에디터/렌더링 제한은 보고서에 별도 기록한다.
