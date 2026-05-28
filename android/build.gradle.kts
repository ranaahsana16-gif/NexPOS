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

subprojects {
    val configureNamespace = {
        if (hasProperty("android")) {
            val android = extensions.findByName("android")
            if (android != null) {
                try {
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val currentNamespace = getNamespace.invoke(android) as? String
                    if (currentNamespace.isNullOrEmpty()) {
                        val fallbackNamespace = group.toString()
                        if (fallbackNamespace.isNotEmpty()) {
                            setNamespace.invoke(android, fallbackNamespace)
                            logger.quiet("Dynamically set namespace to '$fallbackNamespace' for plugin :$name")
                        }
                    }
                } catch (e: Exception) {
                    // Ignore reflection errors if the methods don't exist
                }
            }
        }
    }

    if (state.executed) {
        configureNamespace()
    } else {
        afterEvaluate {
            configureNamespace()
        }
    }
}
