@echo off

set SAVECP=%CLASSPATH%
echo classpath at start is '%CLASSPATH%'

set JAVA_HOME=C:\utils\java\jdk1.3.1
set XERCES_JAR=C:\utils\java\xerces-1_4_1\xerces.jar
set XALAN_JAR=C:\utils\java\xalan-j_2_1_0\bin\xalan.jar

set CLASSPATH=%XERCES_JAR%;%XALAN_JAR%;
echo classpath is now '%CLASSPATH%'

rem echo Converting iHOS QDL to XAF Query Definition...

java org.apache.xalan.xslt.Process -IN Appointment.qdl -XSL ihos2xaf.xslt -OUT Appointment.xml
java org.apache.xalan.xslt.Process -IN Catalog.qdl -XSL ihos2xaf.xslt -OUT Catalog.xml
java org.apache.xalan.xslt.Process -IN ClaimWorkList.qdl -XSL ihos2xaf.xslt -OUT ClaimWorkList.xml
java org.apache.xalan.xslt.Process -IN Document.qdl -XSL ihos2xaf.xslt -OUT Document.xml
java org.apache.xalan.xslt.Process -IN FinancialTransaction.qdl -XSL ihos2xaf.xslt -OUT FinancialTransaction.xml
java org.apache.xalan.xslt.Process -IN FinancialTransactionIPA.qdl -XSL ihos2xaf.xslt -OUT FinancialTransactionIPA.xml
java org.apache.xalan.xslt.Process -IN Invoice.qdl -XSL ihos2xaf.xslt -OUT Invoice.xml
java org.apache.xalan.xslt.Process -IN InvoiceCreditBalance.qdl -XSL ihos2xaf.xslt -OUT InvoiceCreditBalance.xml
java org.apache.xalan.xslt.Process -IN InvoiceIPA.qdl -XSL ihos2xaf.xslt -OUT InvoiceIPA.xml
java org.apache.xalan.xslt.Process -IN InvoiceWorkList.qdl -XSL ihos2xaf.xslt -OUT InvoiceWorkList.xml
java org.apache.xalan.xslt.Process -IN LabOrder.qdl -XSL ihos2xaf.xslt -OUT LabOrder.xml
java org.apache.xalan.xslt.Process -IN Message.qdl -XSL ihos2xaf.xslt -OUT Message.xml
java org.apache.xalan.xslt.Process -IN Observation.qdl -XSL ihos2xaf.xslt -OUT Observation.xml
java org.apache.xalan.xslt.Process -IN Organization.qdl -XSL ihos2xaf.xslt -OUT Organization.xml
java org.apache.xalan.xslt.Process -IN PaymentPlan.qdl -XSL ihos2xaf.xslt -OUT PaymentPlan.xml
java org.apache.xalan.xslt.Process -IN Person.qdl -XSL ihos2xaf.xslt -OUT Person.xml
java org.apache.xalan.xslt.Process -IN ReferralPPMS.qdl -XSL ihos2xaf.xslt -OUT ReferralPPMS.xml
java org.apache.xalan.xslt.Process -IN Statement.qdl -XSL ihos2xaf.xslt -OUT Statement.xml

goto end

:end
set CLASSPATH=%SAVECP%
echo classpath reset to '%CLASSPATH%'
