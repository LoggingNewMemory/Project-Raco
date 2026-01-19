# 🧩 Project Raco Plugin Documentation

This guide outlines how to create, structure, and deploy plugins for Project Raco.

<details>
  <summary><strong>Click to view Plugin Architecture</strong></summary>
  <br>
  <img width="1463" height="956" alt="Design of Plugin drawio" src="https://github.com/user-attachments/assets/9a88994c-94dc-4f6f-a895-6e7bcd91a813" />  
</details>

## ⚙️ How It Works
Unlike standard Magisk Modules, Raco plugins have unique execution behaviors. A plugin can operate in two modes:
1. **Manual Execution**
2. **Start on Boot**

> [!WARNING]
> **Syntax Requirement:** All scripts (`install.sh`, `service.sh`, `uninstall.sh`) must be written in standard **Shell Language**.  
> Do **not** use Magisk Module-specific syntax or functions, as they will cause the plugin to fail.

---

## 📂 Plugin Structure

Your plugin `.zip` file must follow this exact directory structure:

```text
Raco Plugin.zip/
├── raco.prop
├── service.sh
├── uninstall.sh
├── install.sh
└── Logo.png (Optional)
```
