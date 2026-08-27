@rem
@rem Copyright 2015 the original author or authors.
@rem
@rem Licensed under the Apache License, Version 2.0 (the "License");
@rem you may not use this file except in compliance with the License.
@rem
@if "%DEBUG%"=="" @echo off
@if "%DEFAULT_JVM_OPTS%"=="" set DEFAULT_JVM_OPTS="-Xmx64m" "-Xms64m"

set DIRNAME=%~dp0
if "%DIRNAME%"=="" set DIRNAME=.

if not defined JAVA_HOME if exist "%DIRNAME%.jdk17\jdk\bin\java.exe" set "JAVA_HOME=%DIRNAME%.jdk17\jdk"
if not defined GRADLE_USER_HOME if defined USERPROFILE set "GRADLE_USER_HOME=%USERPROFILE%\.gradle"

set "JAVA_EXE=java.exe"
if defined JAVA_HOME set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"

if not exist "%DIRNAME%gradle\wrapper\gradle-wrapper.jar" (
    echo Missing Gradle Wrapper JAR: %DIRNAME%gradle\wrapper\gradle-wrapper.jar
    exit /b 1
)

"%JAVA_EXE%" -jar "%DIRNAME%gradle\wrapper\gradle-wrapper.jar" %*
