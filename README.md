**General instructions to Load HealthSuite on Ubuntu-12.04LTS with Apache-2.2.22, Perl-5.14.2, ModPerl-2.0.5 and Oracle-11g**

###1. Application Environment
Use Apache,Perl and ModPerl that come with the distribution or install them using apt-get.

###2. Perl Environment 
Install the following perl modules, either using apt-get or cpan. To install a module perl named "AAA::Bbb".

Using apt-get: apt-get install  libaaa-bbb-perl
Using cpan: cpan -i AAA::Bbb

    DBD::Oracle 
    Apache::Session
    Apache::Session::NullLocker
    Data::Dumper
    Dumpvalue
    enum
    Exporter
    File::Copy
    File::Path
    File::Spec
    HTML::TokeParser
    LWP::Simple
    LWP::UserAgent
    Storable
    Text::Abbrev
    CGI
    CGI::Carp
    Class::Struct
    DBI
    Date::Calc
    Date::Manip
    Devel::Symdump
    Mail::Sendmail
    Number::Format
    Set::IntSpan
    Set::Scalar
    Text::Template
    XML::DOM
    XML::Generator
    XML::Parser
    Class::Generate
    Class::PseudoHash
    Data::Reporter
    File::PathConvert
    Text::Autoformat
    Text::CSV

The source for old version of pdflib which was used for this project can be obtained from 
URL http://download.devparadise.com/pdflib-2.01.zip. Follow the instruction in the source 
directory to compile and install this module.

###3. Oracle installation on Ubuntu-12.04 LTS.

Oracle 11g is NOT officially supported for Ubuntu-12.04, but since it is a variant of Linux distribution, the Oracle installer can be easily fooled to resemble the system as RedHat Linux and install it. Hence, the Ubuntu system need to be slightly altered to make Oracle install and work correctly.

_Note:_ Unless explicitly mentioned all these operations need to performed as privileged user (or using sudo).

Prerequisite:

 - Memory: > 1GB
 - swap: > 2GB
 - Shared Memory: > 512MB

These parameters can be verified using the following commands

    grep MemTotal /proc/meminfo
    grep SwapTotal /proc/meminfo
    df -kh /dev/shm/

Edit the `/etc/fstab` and add/modify the following line:

    tmpfs    /dev/shm     tmpfs   defaults,size=512M    0       0

Then remount and verify the size:

    mount -o remount /dev/shm
    df -kh /dev/shm/

Software dependencies:

Use the following command to install the software dependencies for Oracle 11g.

    aptitude -y install alien binutils build-essential cpp-4.4 debhelper g++-4.4 gawk gcc-4.4 gcc-4.4-base gettext html2text ia32-libs intltool-debian ksh lesstif2 lib32bz2-dev lib32z1-dev libaio-dev libaio1 libbeecrypt7 libc6 libc6-dev libc6-dev-i386 libdb4.8 libelf-dev libelf1 libltdl-dev libltdl7 libmotif4 libodbcinstq4-1 libodbcinstq4-1:i386 libqt4-core libqt4-gui libsqlite3-0 libstdc++5 libstdc++6 libstdc++6-4.4-dev lsb lsb-core lsb-cxx lsb-desktop lsb-graphics lsb-qt4 make odbcinst pax po-debconf rpm rpm-common sysstat unixodbc unixodbc-dev unzip

System groups and users:

Create oracle user and required system group as follows

    addgroup --system oinstall
    addgroup --system dba
    useradd -r -g oinstall -G dba -m -s /bin/bash -d /var/lib/oracle oracle
    passwd oracle

Configure kernel parameters:

Then edit your `/etc/sysctl.conf` and add the following lines

    fs.aio-max-nr = 1048576
    fs.file-max = 6815744
    kernel.shmall = 2097152
    kernel.shmmax = 536870912
    kernel.shmmni = 4096
    kernel.sem = 250 32000 100 128
    net.ipv4.ip_local_port_range = 9000 65500
    net.core.rmem_default = 262144
    net.core.rmem_max = 4194304
    net.core.wmem_default = 262144
    net.core.wmem_max = 1048586

Run the following command to reload these kernel parameters

    sysctl -p

Shell limits for oracle user
Add the following to `/etc/security/limits.conf` as below:

    oracle              soft    nproc   2047
    oracle              hard    nproc   16384
    oracle              soft    nofile  1024
    oracle              hard    nofile  65536
    oracle              soft    stack   10240

Check if the following line exits within `/etc/pam.d/login` and `/etc/pam.d/su` or add it on both the files if doesn't exists

    session required pam_limits.so
    Create required directories
    Create required directory and change permission:
    mkdir -p /u01/app/oracle
    mkdir -p /u02/oradata
    chown -R oracle:oinstall /u01 /u02
    chmod -R 775 /u01 /u02

Configuring the oracle user's environment:

Add following line to `/var/lib/oracle/.profile`.

    ulimit -u 16384 -n 65536
    umask 022
    export ORACLE_HOSTNAME=localhost.localdomain
    export ORACLE_BASE=/u01/app/oracle
    export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/dbhome_1
    export ORACLE_SID=ORCL
    export NLS_LANG=.WE8MSWIN1252 
    export ORACLE_UNQNAME=orcl.kovaiteam.com
    unset TNS_ADMIN
    if [ -d "$ORACLE_HOME/bin" ]; then
        PATH="$ORACLE_HOME/bin:$PATH"
    fi

Fake the Oracle installer:

As mentioned before , Ubuntu is not listed as Oracle officially support platform and so we need to "fake" it. Create symbolic links as follows:

    mkdir /usr/lib64
    ln -s /etc /etc/rc.d
    ln -s /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib64/
    ln -s /usr/bin/awk /bin/awk
    ln -s /usr/bin/basename /bin/basename
    ln -s /usr/bin/rpm /bin/rpm
    ln -s /usr/lib/x86_64-linux-gnu/libc_nonshared.a /usr/lib64/
    ln -s /usr/lib/x86_64-linux-gnu/libpthread_nonshared.a /usr/lib64/
    ln -s /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /lib64/
    ln -s /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib64/

Also mask the system to look like RedHat:

    echo 'Red Hat Linux release 5' > /etc/redhat-release

Last step before installation start

    cd /var/lib/oracle

Download oracle 11g from the following URL. It requires at least a free oracle web login account.

    https://edelivery.oracle.com/EPD/Download/process_download/V17530-01_1of2.zip
    https://edelivery.oracle.com/EPD/Download/process_download/V17530-01_2of2.zip

Extract the files and change permission

    unzip -q V17530-01_1of2.zip
    unzip -q V17530-01_2of2.zip
    chown -R oracle:oinstall /var/lib/oracle/

Reboot the system if possible to make sure all the parameters are setup correctly

login with user account "oracle" and setup the below  parameters

    export the DISPLAY variable to the X-Server. This will be something like
    export DISPLAY=[your X-Server(or PC)]:0.0

run X-Server on your PC/Mac/Linux:

Give access for the oracle (host) installer client to connect to your X-Server.
In linux and Mac it will be: 

    xhost + _your X-server IP_

On the server start the installer:

    cd /var/lib/oracle/database
    ./runInstaller

On X-server host the installer interface will start. Follow the standard screen instructions.

- Save the response file for future reference or installation.
- During "Perform Prerequisite checks", go through the package requirement list and make sure all the packages are installed. These warning can be ignored as this is not officially supported OS and the package version might be slightly different.
- During installation, oracle tries to build certain packages and some compile/Linker error might occur in the makefiles `ins_emagent.mk` and `inst_srvm.mk`. In that case, just execute these commands to rectify it.

The commands are

    export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
    sed -i 's/^\(\s*\$(MK_EMAGENT_NMECTL)\)\s*$/\1 -lnnz11/g' $ORACLE_HOME/sysman/lib/ins_emagent.mk
    sed -i 's/^\(\$LD \$LD_RUNTIME\) \(\$LD_OPT\)/\1 -Wl,--no-as-needed \2/g' $ORACLE_HOME/bin/genorasdksh
    sed -i 's/^\(\s*\)\(\$(OCRLIBS_DEFAULT)\)/\1 -Wl,--no-as-needed \2/g' $ORACLE_HOME/srvm/lib/ins_srvm.mk
    sed -i 's/^\(TNSLSNR_LINKLINE.*\$(TNSLSNR_OFILES)\) \(\$(LINKTTLIBS)\)/\1 -Wl,--no-as-needed \2/g' $ORACLE_HOME/network/lib/env_network.mk
    sed -i 's/^\(ORACLE_LINKLINE.*\$(ORACLE_LINKER)\) \(\$(PL_FLAGS)\)/\1 -Wl,--no-as-needed \2/g' $ORACLE_HOME/rdbms/lib/env_rdbms.mk
___
----------------- End of Oracle installation ------------

Starting Oracle database service:

Login as oracle user on the system, set all appropriate environment variable and start the database

    sqlplus sys as sysdba

On SQL Prompt
    startup;
    exit;

Start DB Listener service:
    lsnrctl start 

###4. HealthSuite installation:

Copy the Healthsuite source to a directory say `/var/physia`. (which is PHYSIA_ROOT)

Configure the database credentials on the file: `PHYSIA_ROOT/HealthSuite/Lib/perl/App/Configuration.pm`

Create schema and initialize the database:

    cd PHYSIA_ROOT/
    perl ./HealthSuite/Database/GenerateSchema.pl

This will create a directory `PHYSIA_ROOT/HealthSuite/Database/schema-physia` with all SQL script required to populate the schema and some sample data. Now run these commands to setup the database.

    cd PHYSIA_ROOT/HealthSuite/Database/schema-physia
    ./setupdb.sh

###5. Apache and Mod_Perl configuration

On Ubuntu system modify/copy the http configuration file from `PHYSIA_ROOT/HealthSuite/Conf/apache2/default` to `/var/apache2/sites-available/default` and modperl startup file `PHYSIA_ROOT/HealthSuite/Conf/apache2/startup.pl` to  `/var/apache2/startconf/startup.pl`

Configure these two files to match the current environment.

Start Apache:

    sudo service apache2 start

###6. Access the user interface
Point the browser to the URL: `http://ServerIP|Hostname/`

The interface credentials are stored on the database table "person_login". Add related entries on the tables "Person", "Org" and "Person_Org_Category". And then add the creditials to "person_login". A sample SQL statement would be

    insert into person(person_id, cr_stamp, cr_org_internal_id,  name_first, name_last) values ('logu', '07-DEC-11', 15, 'logu', 'nathan');
    insert into ORG (ORG_INTERNAL_ID, CR_STAMP, VERSION_ID, ORG_ID, NAME_PRIMARY) values (15,'07-DEC-11',10,'visolve','vinc');
    insert into person_login(cr_stamp, cr_user_id, org_internal_id, version_id, person_id, password) values ('07-DEC-11','logu', 15, 10, 'LOGU','l123');
    insert into person_org_category (person_id, org_internal_id, category, cr_stamp, version_id) values ('LOGU', 15, 'Superuser', '07-DEC-11', 0);
    update org set owner_org_id=15 where org_id='VISOLVE';
___

___End__
