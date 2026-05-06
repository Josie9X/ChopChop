# Demo Guide

ChopChop provides two review entry points: a Web Demo for quick online access and a Native iOS App for reviewing the full native implementation.

## A. Web Demo

The Web Demo is best for reviewers who want to quickly experience the core product flow online.

Demo URL:

[Replace with Vercel Demo URL]

This is the competition URL submission entry. It is designed as a browser-accessible prototype so reviewers can try the main ChopChop workflow without installing developer tools.

The Web Demo shows the core loop:

1. Enter a course task.
2. Send it for task recognition.
3. Confirm the task type, DDL, and completed stages.
4. Generate Robust Mode and Firefighting Mode.
5. Choose a plan.
6. Track execution in My Tasks.

## B. Native iOS App

The Native iOS App is best for technical review of the complete native prototype.

To run it:

1. Clone the GitHub repository.
2. Open `ChopChop.xcodeproj`.
3. Select an iPhone simulator.
4. Click **Run** in Xcode.

## Why Two Demo Entries

The preliminary competition requires a Demo URL, while a native iOS App cannot run directly through a browser URL. For that reason, ChopChop includes an additional Web-accessible demo layer to give reviewers zero-install access through Vercel.

At the same time, the full Xcode project is provided so reviewers can inspect and run the real native App implementation. The Web Demo and the iOS App use different presentation formats, but they demonstrate the same core product flow: turning a vague deadline-driven academic task into a clear, executable plan.
