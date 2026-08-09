allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// FIXED: Uses safe java reflection to update SDK target to 36
// without causing strict class compile-time errors in the root project script
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            try {
                androidExt?.javaClass?.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)?.invoke(androidExt, 36)
            } catch (e: Exception) {
                // Fallback block if reflection is interrupted
            }
        }
    }
}