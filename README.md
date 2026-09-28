# Plyst

복사한 내용을 모아 정리하고, 필요한 항목을 검색하거나 순서대로 붙여넣을 수 있도록 만드는 iOS 앱입니다.

## 개발 환경

| 항목 | 버전 |
| --- | --- |
| Xcode | 27.0 |
| iOS Deployment Target | 17.0 |
| Swift | 5.0 |
| SwiftLint | 0.63.3 |

## 개발 환경 구성

SwiftLint를 설치합니다.

```bash
brew install swiftlint
```

Xcode에서 [Plyst.xcodeproj](Plyst/Plyst.xcodeproj)을 열고 `Plyst` Shared Scheme을 선택합니다.

## 검증

로컬과 CI는 같은 명령을 사용합니다.

| 명령 | 확인 내용 |
| --- | --- |
| `make lint` | 프로덕션 코드와 테스트 코드의 SwiftLint 검사 |
| `make build` | `Plyst` 애플리케이션 빌드 |
| `make test-build` | 테스트를 실행하지 않는 `PlystTests` 컴파일 |
| `make verify` | SwiftLint, 애플리케이션 빌드, 테스트 타깃 컴파일 |

모든 빌드 명령은 `generic/platform=iOS Simulator`를 대상으로 하며 앱이나 Simulator를 실행하지 않습니다. 산출물은 `/tmp/plyst-derived-data`에 생성됩니다.

## 프로젝트 구조

```text
Plyst/
├── Plyst.xcodeproj/
├── Plyst/
│	├── App/
│	│	├── AppDelegate.swift
│	│	└── SceneDelegate.swift
│	├── Model/
│	│	├── Clip.swift
│	│	├── ClipContent.swift
│	│	└── ClipImageMetadata.swift
│	├── Service/
│	│	└── Clip/
│	│		├── ClipRepository.swift
│	│		├── ClipRepositoryEvent.swift
│	│		├── ClipRepositoryError.swift
│	│		├── ClipUpdate.swift
│	│		└── ClipSortOrder.swift
│	├── Feature/
│	│	└── Root/
│	│		├── AppReactor.swift
│	│		└── ViewController.swift
│	├── Shared/
│	│	└── State/
│	│		├── Reactorable.swift
│	│		├── ReactorEffect.swift
│	│		└── ReactorViewController.swift
│	└── Base.lproj/LaunchScreen.storyboard
└── PlystTests/
```

앱 화면은 Storyboard 없이 UIKit 코드로 구성합니다. `LaunchScreen.storyboard`는 시스템 시작 화면에만 사용합니다. Xcode 프로젝트와 Shared Scheme은 Git에서 추적하고 `xcuserdata`와 빌드 산출물은 제외합니다.

## 작업 지침

AI 작업은 [AGENTS.md](AGENTS.md)에서 연결하는 Plyst Notion 정책을 따릅니다. Pull Request에서는 SwiftLint와 애플리케이션 빌드, 테스트 타깃 컴파일을 확인합니다.
