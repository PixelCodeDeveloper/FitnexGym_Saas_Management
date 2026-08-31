allprojects {
    repositories {
        google()
        mavenCentral()
    }
    plugins.withId("com.android.application") {
        (extensions.getByName("android") as com.android.build.gradle.BaseExtension).buildToolsVersion = "36.0.0"
    }
    plugins.withId("com.android.library") {
        (extensions.getByName("android") as com.android.build.gradle.BaseExtension).buildToolsVersion = "36.0.0"
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



