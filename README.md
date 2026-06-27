# Aeraa

<table>
  <tr>
    <td>
      <p align="center">
      <img src="/assets/images/app_icon.png" alt="Project Screenshot" width="250">
      </p>
    </td>
    <td>
      <strong>A minimal, terminal-inspired, keyboard-driven to-do app for organizing your workflow. Built natively with Flutter. 💙</strong><br>
      Aeraa brings the speed and aesthetic of a command-line interface to a standalone desktop window. It is *not* a shell script or a web wrapper—it runs natively on your system, offering a fast, focused, and distraction-free environment to get things done. 💻🚀
    </td>
  </tr>
</table>

This cross-platform app is the successor to my [Task Terminal](https://github.com/msparsh/task-terminal) (JavaScript) and is built upon the fantastic foundation of the [Taskbook](https://github.com/klaudiosinani/taskbook) project. Massive thanks to the creator of the project! 🙏

## ✨ Features

### 📌 Core Functionality

* **📝 Tasks & Notes:** Add tasks or jot down notes in seconds.
* **🗂️ Boards:** Group related items together to keep your workspace clean.
* **👀 Views:** Toggle seamlessly between board or timeline layouts.
* **🔥 Priorities:** Track and highlight what matters most.
* **⏳ Deadlines:** Never miss a due date.
* **📦 Archive System:** Tuck away tasks and easily restore them later.
* **💾 Local Storage:** 100% private. Your data is saved locally directly to your machine.

### 🛠️ Advanced Organization & Customization

* **🌳 Subtasks:** Break down massive projects into bite-sized steps.
* **🏷️ Tags:** Categorize and filter items instantly.
* **⌨️ Aliases:** Map custom shortcuts (e.g., `alias hw list @homework`) for lightning-fast workflows.
* **⚙️ Customization:** Make it yours. Adjust window opacity, font size, default views, and history limits.



## 💻 Workflow Example

Aeraa uses simple commands to manage your day. Here is a quick example of a standard session:

```bash
# Add a task to the 'app' board
> add @app Design the UI layout 
OR
> task @app Design the UI layout
OR
> -t Design the UI layout @app


# Add a subtask 
> sub 47 Research UI layouts


# Add a priority task with a deadline in any order
> add  Fix routing bug p:3 due:19-06-2028 @app #urgent


# Add a note to your 'ideas' board
> note Try the new Flutter animation package @ideas
OR
> -n  @ideas Try the new Flutter animation package


# Mark task 1 as complete
> -c 1
```


## 📥 Installation

Ready to jump in? Head over to the Releases to download the latest executable. 🎉


## 🏗️ Build Instructions

Want to compile Aeraa yourself? Awesome! 🛠️ Windows build configurations are ready to go out of the box (other platforms remain unconfigured but can be done easily).

### 📋 Prerequisites

* **Flutter SDK:** Requires environment `sdk: ^3.12.2`

### 🚀 Running Locally

1. Open a terminal in the project directory. 📁
2. Clean the project and install dependencies:
```bash
flutter clean
flutter pub get
```


3. Run the application:
```bash
flutter run -d windows 
```



### 📦 Creating an Executable (Windows)

The project includes configurations for generating a Windows MSIX installer effortlessly. Just run:

```bash
dart run msix:create
```
