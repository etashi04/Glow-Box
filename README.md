# Glow Box 한국어 패치 작업

게임 **Glow Box**의 비공식 한국어 패치 작업 저장소입니다.

- 번역 데이터: `translations/`
- 패치·검증 스크립트: `scripts/`
- 원본 파일 해시: `metadata/original_sha256.csv`
- 다른 PC 작업 재개 방법: `작업_인계서.md`

게임 원본, 추출 데이터, 빌드 산출물 및 외부 도구는 저장소에 포함하지 않습니다. 완전한 작업 환경은 동일한 원드라이브 작업 폴더를 동기화해서 사용합니다.

## 배포본

배포 패키지는 `release/GlowBox_Korean_Patch_v1.0.0.zip`으로 생성한다.

- `GlowBox_Korean_Patch_v1.0.0.exe`: Steam 설치 폴더 자동 탐색, 원본 해시 확인, 백업·설치·복구를 제공하는 단일 실행 파일
- `README.txt`: 사용자용 설치 안내

배포 전에는 임시 Steam 원본 사본에서 EXE 설치 및 복구 후 SHA-256 왕복 일치를 확인한다.
