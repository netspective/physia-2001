#!/bin/sh
export FRAMEWORK_ROOT=/home/sjaveed/xaf/Framework
export APP_ROOT=/home/sjaveed/xaf/web-aspire
export APP_CLASSES=$APP_ROOT/Site/WEB-INF/classes

export BUILD_FILE=$FRAMEWORK_ROOT/tools/app-build.xml

export JAVA_HOME=/usr/local/jdk
export ANT_HOME=/usr/local/ant
export XERCES_JAR=/usr/local/xerces/xerces.jar
export XALAN_JAR=/usr/local/xalan/bin/xalan.jar
export OROMATCHER_JAR=/usr/local/oro/jakarta-oro-2.0.4.jar
export LOG4J_JAR=/usr/local/log4j/dist/lib/log4j.jar
export SERVLETAPI_JAR=/home/sjaveed/xaf/resin-1.2.8/lib/jsdk22.jar
export JDBC2X_JAR=/home/sjaveed/xaf/resin-1.2.8/lib/jdbc2_0-stdext.jar
export JAVACP=$JAVA_HOME/lib/tools.jar:/usr/local/jdbc/classes12.zip
export FRAMEWORK_JAR=$FRAMEWORK_ROOT/lib/xaf-1_2_8.jar

#if exist "$JAVA_HOME/lib/tools.jar" export JAVACP=%JAVA_HOME%/lib/tools.jar
#if exist "%JAVA_HOME%/lib/classes.zip" export JAVACP=%CLASSPATH%;%JAVA_HOME%/lib/classes.zip

export USE_CLASS_PATH=$APP_CLASSES:$XERCES_JAR:$FRAMEWORK_JAR:$OROMATCHER_JAR:$LOG4J_JAR:$SERVLETAPI_JAR:$JDBC2X_JAR:$XALAN_JAR:$JAVACP
echo Classpath: $USE_CLASS_PATH

java -Dant.home=$ANT_HOME -classpath $USE_CLASS_PATH:$ANT_HOME/lib/ant.jar org.apache.tools.ant.Main -Dbasedir=$APP_ROOT -buildfile $BUILD_FILE $@
