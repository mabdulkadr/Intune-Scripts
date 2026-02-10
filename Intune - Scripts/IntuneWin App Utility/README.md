
# 📦 IntuneWin App Utility

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)
![GUI](https://img.shields.io/badge/GUI-WPF-purple.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

Modern GUI tool to create **Intune Win32 packages (.intunewin)** from **EXE/MSI** installers using Microsoft's **IntuneWinAppUtil.exe** with a clean UI and enhanced user experience.
---

# 🖥️ Interface Preview
![Screenshot](Screenshot.png)


---

# 🚀 Features

## Core Packaging
- Convert EXE/MSI → `.intunewin`
- Uses official Microsoft **IntuneWinAppUtil**
- Async packaging (no UI freeze)
- Real-time Message Center logs
- Accurate output file name + size display

## Smart User Experience
- Auto-detect installer inside Source folder
- If multiple installers exist:
  - selects first automatically
  - shows green SUCCESS message
- Displays:
  - Source file name only (no full path)
  - Output package name
  - Output package size
- Prevents running multiple packaging jobs simultaneously

## Validation Engine
- Source folder must exist
- Installer must be inside source folder
- Supports only `.exe` or `.msi`
- Output folder auto-created if missing
- Detects missing `IntuneWinAppUtil.exe`

## Logging System
Log file stored automatically:

```
C:\IntuneWinUtility\
```

---

# 📁 Default Working Structure

Automatically created on first run:

```

C:\IntuneWinUtility
├── Source
├── Output
└── IntuneWinUtility-YYYYMMDD.log

```

---

# ▶️ How to Use (EXE Version)

## Run directly
Just double-click:

```

IntuneWin App Utility.exe

```

No PowerShell window required.

## Steps
1. Select **Source Folder**
2. Tool auto-detects EXE/MSI
3. Choose output mode:
   - Same as source
   - Custom output folder
4. Click **Create Package**

---

# 🧠 Auto Detection Behavior

When selecting Source Folder:
- Tool searches for `.exe` or `.msi`
- If found:
  - auto-selects installer
  - shows green SUCCESS message
- If multiple:
  - selects first automatically
  - logs count of detected installers

---

# 📦 Output Result

After packaging:
- Shows output file name
- Shows output file size
- Shows success message
- Opens output folder (optional)

Example output:
```

AppName.intunewin (45.3 MB)

````

---

# 📜 License
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

# 📜  Disclaimer
These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.

