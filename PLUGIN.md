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

### Plugins is on /data/ProjectRaco/Plugins

---

## 📂 Plugin Structure

Your plugin `.zip` file must follow this exact directory structure:

```text
Raco Plugin.zip/
├── raco.prop
├── service.sh
├── webroot / (If you want to add WebUI (added in Raco 5.0)
├── uninstall.sh
├── install.sh
├── post-fs-data.sh
└── Logo.png (Optional) - Max 512x512
```

## 📝 Configuration (raco.prop)

The `raco.prop` file is the heart of your plugin. You must define the following property for the plugin to be recognized by the system:

```
RacoPlugin=1
```

If this line is missing, the installation will fail.

## 🔗 Resources & Downloads

| Resource | Description | Link |
| :--- | :--- | :--- |
| **Plugin Example** | A reference implementation (PingImp) | [View Example](https://github.com/LoggingNewMemory/Project-Raco/blob/main/Raco%20Plugin%20Example/Raco%20PingImp.zip) |
| **Plugin Template** | Empty starter template | [Download Template](https://github.com/LoggingNewMemory/Project-Raco/blob/main/Raco%20Plugin%20Example/Raco%20Plugin%20Template.zip) |


