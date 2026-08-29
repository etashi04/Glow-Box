# Glow Box 비공식 한국어 패치

게임 **Glow Box**의 비공식 한국어 패치 저장소입니다.

- 번역 데이터: `translations/`
- 패치·검증 스크립트: `scripts/`
- 원본 파일 해시: `metadata/original_sha256.csv`
- 설치기 소스와 빌드 도구: `distribution/`
- 버전별 지원 정보: `versions/`

게임 원본, 추출 데이터, 빌드 산출물 및 외부 도구는 저장소에 포함하지 않습니다.

## 배포본

현재 패치 버전은 `VERSION`에서 관리합니다. 사용자에게는 빌드 후 생성되는 `GlowBox_Korean_Patch_v버전.zip` 하나만 배포하면 됩니다.

- `GlowBox_Korean_Patch_v1.0.0.exe`: Steam 설치 폴더 자동 탐색, 원본 해시 확인, 백업·설치·복구를 제공하는 단일 실행 파일
- `README.txt`: 사용자용 설치 안내

사용자는 ZIP을 푼 뒤 EXE를 실행하여 한국어 패치를 설치하거나 원본을 복구할 수 있습니다.

## 새 버전 배포

1. `VERSION`을 새 버전으로 변경합니다.
2. `versions/새버전/manifest.json`을 만들고 지원 게임 빌드, 원본·패치 번들 해시 및 패치 번들 경로를 기록합니다.
3. `CHANGELOG.md`에 변경 사항을 추가합니다.
4. 루트에서 `./build_release.ps1`을 실행합니다.

스크립트는 EXE 컴파일, 번들 내장, 임시 게임 사본 설치·복구 검증, ZIP 압축, `SHA256SUMS.txt` 생성을 한 번에 수행합니다. 버전 또는 해시 검증에 실패하면 배포를 중단합니다.
