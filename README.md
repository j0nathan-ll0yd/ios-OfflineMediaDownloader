# Offline Media Downloader

This is the companion iOS App that hooks in to [the backend for downloading media (e.g. YouTube videos)](https://github.com/j0nathan-ll0yd/aws-cloudformation-file-download-app).

## Getting Started

1. [Install](https://github.com/j0nathan-ll0yd/aws-cloudformation-media-downloader#installation) the backend source code on your local machine.
2. [Deploy](https://github.com/j0nathan-ll0yd/aws-cloudformation-media-downloader#deployment) the application to your AWS account.
3. [Set the environment variables](https://github.com/j0nathan-ll0yd/ios-OfflineMediaDownloader#setting-env-variables) in Xcode from your deployment.
    * **MEDIA_DOWNLOADER_API_KEY** = The iOSAppKey from the API Gateway
    * **MEDIA_DOWNLOADER_BASE_PATH** = The invoke URL of the API Gateway
    
That's it! You should now be able to launch and use the App.

> **NOTE**: If you don't see any files yet, it's likely because you haven't downloaded a file to your S3 bucket. You can do this easily by running the `test-remote-hook` command under the [Live Testing](https://github.com/j0nathan-ll0yd/aws-cloudformation-media-downloader#live-testing) instructions.

## Project Tenants

* Minimal external dependencies.
* Leverage new technologies introduced with iOS 13: [SwiftUI](https://developer.apple.com/xcode/swiftui/) & [Combine](https://developer.apple.com/documentation/combine).

## Project Features

* Uses the [MVVM architecture](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93viewmodel).
* Supports registering for and receiving push notifications.
* Supports background downloads.
* Uses [CoreData](https://developer.apple.com/documentation/coredata) for persistence and offline support.

# Installation

* Xcode Version 11.4
* MacOS Version 10.15.3 Catalina

## Setting ENV Variables

If you need additional help setting the environment variables. I have included screenshots from the AWS console for your reference.

### MEDIA_DOWNLOADER_API_KEY

Navigate to the Amazon API Gateway from your deployment and select **API Keys** on the left. Select the **iOSAppKey**. Select **Show** to reveal the key.

![API Gateway, API Keys](https://lifegames-github-assets.s3.amazonaws.com/ios-OfflineMediaDownloader/getting-started-finding-api-key.png)

### MEDIA_DOWNLOADER_BASE_PATH

Navigate to the Amazon API Gateway from your deployment and select **Dashboard** on the left. The invocation URL will appear on the top of the page.

![API Gateway, Invoke URL](https://lifegames-github-assets.s3.amazonaws.com/ios-OfflineMediaDownloader/getting-started-finding-base-path.png)

### Environment variables in Xcode

1. Add a new Configuration Setting file to the project named **Development.xcconfig**.

![Xcode, Development.xcconfig](https://lifegames-github-assets.s3.amazonaws.com/ios-OfflineMediaDownloader/getting-started-setting-env-variables-new-file.png)

2. Add your environment variables to the file.

![Xcode, Environment Variables](https://lifegames-github-assets.s3.amazonaws.com/ios-OfflineMediaDownloader/getting-started-setting-env-variables-new-file-content.png)

> **NOTE**: You may have noticed some strangeness with the `MEDIA_DOWNLOADER_BASE_PATH` formatting. This is due to the way characters are escaped in xcconfig files. In order to have the `//` in `https://`, we need to split it with an empty variable substitution via `$()`. 
