allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// --- FIX START: Inject Namespace for AGP 8.0+ ---
subprojects {
    // 1. Define the fix logic
    val configureNamespace = {
        if (extensions.findByName("android") != null) {
            try {
                val android = extensions.getByName("android")
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)

                // If the plugin didn't specify a namespace, we give it one (using its group name)
                if (getNamespace.invoke(android) == null) {
                    val packageName = group.toString()
                    setNamespace.invoke(android, packageName)
                }
            } catch (e: Exception) {
                // Ignore if method is missing or reflection fails
            }
        }
    }

    // 2. Apply it safely (immediately if ready, or wait if not)
    if (state.executed) {
        configureNamespace()
    } else {
        afterEvaluate {
            configureNamespace()
        }
    }
}
// --- FIX END ---