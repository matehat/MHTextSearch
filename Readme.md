## Introduction

A fast embedded full-text indexing library, written in Objective-C, built on top of [Objective-LevelDB][2].

### Installation

By far, the easiest way to integrate this library in your project is by using [CocoaPods][1].

1. Have [Cocoapods][1] installed, if you don't already

2. In your Podfile, add the line (until it has been added to cocoapods main repo)

        pod 'Objective-LevelDB', :git => "https://github.com/matehat/MHTextSearch.git"

3. Run `pod install`

4. Add the `libc++.dylib` Framework to your project.

### Testing

If you want to run the tests, you will need XCode 5, as the test suite uses the new XCTest. 

Clone this repository and, once in it,

```bash
$ cd MHTextSearch\ iOS\ Tests
$ pod install
$ cd .. && open *.xcworkspace
```

Currently, all tests were setup to work with the iOS test suite.

### License

Distributed under the [MIT license](LICENSE)

[1]: http://cocoapods.org
[2]: https://github.com/matehat/Objective-LevelDB
