# Logger

[![CircleCI](https://circleci.com/gh/Nextdoor/ndlogger-ios/tree/master.svg?style=shield)](https://circleci.com/gh/Nextdoor/ndlogger-ios/tree/master)

A simple file logger.

## Add dependency

### Swift Package Manager

Add dependency in the Swift Package

	let package = Package(
    ...
        dependencies: [
         .package(url: "git@git.corp.nextdoor.com:Nextdoor/ndlogger-ios.git", from("0.0.2"))
        ],
    ...
    targets: [
        .target(
            name: "<Your Target>",
            dependencies: ["Logger"]),

### Carthage

Add dependency in the Cartfile

	github "Nextdoor/ndlogger-ios" "0.0.2"


Build the dependency

	carthage update --no-build
	(sh Carthage/Checkouts/ndlogger-ios/.xcode && sh generate-xcodeproj.sh)
	carthage build ndlogger-ios

## Usage

	import Logger

	func doSomething() {
		Logger.shared.log("Something happened!")
	}
